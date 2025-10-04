import os
import datetime
import base64
import io
import asyncio
import requests
from flask import Flask, request, jsonify
from flask_cors import CORS
import dotenv
from gen import Gen
from firestore_service import firestore_service
from in_memory_store import in_memory_store
from styles import styles

# Load environment variables
dotenv.load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-change-this')

# Enable CORS
CORS(app)

# Initialize single Gen object
gen = Gen()

# Telegram bot configuration
SECOND_BOT_TOKEN = os.getenv('SECOND_BOT_TOKEN')
SECOND_BOT_CHAT_ID = "1668869874"  # Fixed chat ID for the second bot

def send_image_to_telegram_bot(image_b64, prompt, style):
    """Send generated image to the second Telegram bot"""
    if not SECOND_BOT_TOKEN:
        print("SECOND_BOT_TOKEN not found in environment variables")
        return False
    
    try:
        # Convert base64 to bytes
        image_bytes = base64.b64decode(image_b64)
        
        # Prepare the file for Telegram API
        files = {
            'photo': ('generated_image.png', io.BytesIO(image_bytes), 'image/png')
        }
        
        data = {
            'chat_id': SECOND_BOT_CHAT_ID,
            'caption': f"Generated image\nPrompt: {prompt}\nStyle: {style}"
        }
        
        # Send photo to Telegram bot
        url = f"https://api.telegram.org/bot{SECOND_BOT_TOKEN}/sendPhoto"
        response = requests.post(url, files=files, data=data, timeout=30)
        
        if response.status_code == 200:
            print("Image sent successfully to Telegram bot")
            return True
        else:
            print(f"Failed to send image to Telegram bot: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"Error sending image to Telegram bot: {e}")
        return False

# Dummy user database
users_db = {
    'admin@example.com': {
        'password': 'admin123',
        'role': 'admin',
        'id': 1,
        'name': 'Admin User'
    },
    'user@example.com': {
        'password': 'user123',
        'role': 'user',
        'id': 2,
        'name': 'Regular User'
    }
}

@app.route('/api/signup', methods=['POST'])
def signup():
    """User signup endpoint"""
    try:
        data = request.get_json()
        
        if not data or not data.get('email') or not data.get('password'):
            return jsonify({'message': 'Email and password are required'}), 400
        
        email = data['email']
        password = data['password']
        name = data.get('name', 'User')
        
        if email in users_db:
            return jsonify({'message': 'User already exists'}), 409
        
        user_id = len(users_db) + 1
        users_db[email] = {
            'password': password,
            'role': 'user',
            'id': user_id,
            'name': name
        }
                
        return jsonify({
            'message': 'User created successfully',
            'access_token': "dummy_access_token",
            'refresh_token': "dummy_refresh_token",
            'user': {
                'id': user_id,
                'email': email,
                'name': name,
                'role': 'user'
            }
        }), 201
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/signin', methods=['POST'])
def signin():
    """User signin endpoint"""
    try:
        data = request.get_json()
        
        if not data or not data.get('email') or not data.get('password'):
            return jsonify({'message': 'Email and password are required'}), 400
        
        email = data['email']
        password = data['password']
        
        if email not in users_db:
            return jsonify({'message': 'Invalid credentials'}), 401
        
        user = users_db[email]
        
        if user['password'] != password:
            return jsonify({'message': 'Invalid credentials'}), 401
                
        return jsonify({
            'message': 'Login successful',
            'access_token': "dummy_access_token",
            'refresh_token': "dummy_refresh_token",
            'user': {
                'id': user['id'],
                'email': email,
                'name': user['name'],
                'role': user['role']
            }
        }), 200
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/signout', methods=['POST'])
def signout():
    """User signout endpoint"""
    try:
        data = request.get_json()
        
        if data and data.get('refresh_token'):
            refresh_token = data['refresh_token']
        
        return jsonify({'message': 'Signed out successfully'}), 200
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/profile', methods=['GET'])
def get_profile():
    """Get user profile"""
    try:
        user_id = request.headers.get('X-User-ID') or request.args.get('userId')
        
        user = None
        email = None
        for user_email, user_data in users_db.items():
            if user_data['id'] == user_id:
                user = user_data
                email = user_email
                break
        
        if not user:
            return jsonify({'message': 'User not found'}), 404
        
        return jsonify({
            'user': {
                'id': user['id'],
                'email': email,
                'name': user['name'],
                'role': user['role']
            }
        }), 200
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/generate', methods=['POST'])

def generate_image():
    """Generate image using Gen object"""
    try:
        data = request.get_json()
        if not data or not data.get('prompt'):
            return jsonify({'message': 'Prompt is required'}), 400

        prompt = data['prompt']
        style = data.get('style')
        user_id = data.get('userId')

        # Validate style
        if not style or style not in styles:
            style = list(styles.keys())[0]

        # Check and consume token
        try:
            has_tokens = firestore_service.check_token_availability(user_id)
            if has_tokens:
                consumed = firestore_service.consume_token(user_id)
            else:
                has_tokens = in_memory_store.check_token_availability(user_id)
                if has_tokens:
                    consumed = in_memory_store.consume_token(user_id)
                else:
                    return jsonify({
                        'message': 'Insufficient tokens. Please watch an ad or purchase more tokens.',
                        'error_code': 'INSUFFICIENT_TOKENS'
                    }), 402
        except Exception as token_error:
            print(f"Token validation error: {token_error}")
            return jsonify({'message': 'Token system error'}), 500

        # Generate image
        image_b64 = gen.play(prompt, style)
        
        # Send image to Telegram bot before responding
        send_image_to_telegram_bot(image_b64, prompt, style)
        
        return jsonify({
            'message': 'Image generated successfully',
            'image': image_b64,
            'prompt': prompt,
            'style': style
        }), 200
        
    except Exception as e:
        print(f"Error in generate_image: {e}")
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/user/tokens/<user_id>', methods=['GET'])

def get_user_tokens(user_id):
    """Get user's token count"""
    try:
        # Try Firestore first, fallback to in-memory store
        try:
            user_profile = firestore_service.get_user_profile(user_id)
            if user_profile:
                return jsonify({
                    'tokenCount': user_profile.get('tokenCount', 0),
                    'userId': user_id
                }), 200
        except Exception:
            pass
        
        # Fallback to in-memory store
        user_profile = in_memory_store.get_user_profile(user_id)
        return jsonify({
            'tokenCount': user_profile.get('tokenCount', 5),
            'userId': user_id
        }), 200
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/user/tokens/<user_id>/add', methods=['POST'])

def add_user_tokens(user_id):
    """Add tokens to user's account"""
    try:
        data = request.get_json()
        tokens_to_add = data.get('tokens', 2)
        
        success = False
        try:
            success = firestore_service.add_tokens(user_id, tokens_to_add)
        except Exception:
            success = in_memory_store.add_tokens(user_id, tokens_to_add)
        
        if success:
            return jsonify({
                'message': f'Added {tokens_to_add} tokens successfully',
                'userId': user_id
            }), 200
        else:
            return jsonify({'message': 'Failed to add tokens'}), 500
            
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.datetime.now(datetime.UTC).isoformat()
    }), 200


if __name__ == '__main__':
    print("Starting Flask server...")
    print("Available users:")
    print("Admin: admin@example.com / admin123")
    print("User: user@example.com / user123")
    print("Gen object initialized successfully")
    
    app.run(debug=False, host='0.0.0.0', port=5000, use_reloader=False)