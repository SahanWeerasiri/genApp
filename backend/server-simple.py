import os
import jwt
import datetime
from functools import wraps
from flask import Flask, request, jsonify, make_response
from flask_cors import CORS
import dotenv
from gen import Gen
from firestore_service import firestore_service
from in_memory_store import in_memory_store

# Load environment variables
dotenv.load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-change-this')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = datetime.timedelta(minutes=15)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = datetime.timedelta(days=30)

# Enable CORS
CORS(app)

# Dummy user database (replace with actual database later)
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

# Store refresh tokens (in production, use a database)
refresh_tokens = set()

# Single Gen instance per worker process
gen_instance = None


def get_gen_instance():
    """Get or create the Gen instance for this worker process"""
    global gen_instance
    if gen_instance is None:
        print("Initializing Gen instance for this worker...")
        gen_instance = Gen()
        print("Gen instance initialized successfully")
    return gen_instance


def generate_tokens(user_id, role):
    """Generate access and refresh tokens for a user"""
    # Access token - short lived
    access_token_payload = {
        'user_id': user_id,
        'role': role,
        'exp': datetime.datetime.now(datetime.UTC) + app.config['JWT_ACCESS_TOKEN_EXPIRES'],
        'iat': datetime.datetime.now(datetime.UTC),
        'type': 'access'
    }
    
    # Refresh token - long lived
    refresh_token_payload = {
        'user_id': user_id,
        'exp': datetime.datetime.now(datetime.UTC) + app.config['JWT_REFRESH_TOKEN_EXPIRES'],
        'iat': datetime.datetime.now(datetime.UTC),
        'type': 'refresh'
    }
    
    access_token = jwt.encode(access_token_payload, app.config['SECRET_KEY'], algorithm='HS256')
    refresh_token = jwt.encode(refresh_token_payload, app.config['SECRET_KEY'], algorithm='HS256')
    
    # Store refresh token
    refresh_tokens.add(refresh_token)
    
    return access_token, refresh_token


def verify_token(token, token_type='access'):
    """Verify JWT token"""
    try:
        payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
        
        # Check token type
        if payload.get('type') != token_type:
            return None
            
        # For refresh tokens, check if it's in our store
        if token_type == 'refresh' and token not in refresh_tokens:
            return None
            
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def token_required(f):
    """Middleware to require valid access token"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        auth_header = request.headers.get('Authorization')
        
        if auth_header:
            try:
                token = auth_header.split(' ')[1]  # Bearer <token>
            except IndexError:
                return jsonify({'message': 'Invalid token format'}), 401
        
        if not token:
            return jsonify({'message': 'Token is missing'}), 401
        
        payload = verify_token(token, 'access')
        if not payload:
            return jsonify({'message': 'Token is invalid or expired'}), 401
        
        # Add user info to request context
        request.current_user = {
            'id': payload['user_id'],
            'role': payload['role']
        }
        
        return f(*args, **kwargs)
    return decorated


def admin_required(f):
    """Middleware to require admin role"""
    @wraps(f)
    def decorated(*args, **kwargs):
        if not hasattr(request, 'current_user'):
            return jsonify({'message': 'Authentication required'}), 401
        
        if request.current_user['role'] != 'admin':
            return jsonify({'message': 'Admin access required'}), 403
        
        return f(*args, **kwargs)
    return decorated


@app.route('/api/signup', methods=['POST'])
def signup():
    """Dummy signup endpoint"""
    try:
        data = request.get_json()
        
        if not data or not data.get('email') or not data.get('password'):
            return jsonify({'message': 'Email and password are required'}), 400
        
        email = data['email']
        password = data['password']
        name = data.get('name', 'User')
        role = data.get('role', 'user')  # Default to user role
        
        # Check if user already exists
        if email in users_db:
            return jsonify({'message': 'User already exists'}), 409
        
        # Create new user (dummy implementation)
        user_id = len(users_db) + 1
        users_db[email] = {
            'password': password,  # In production, hash this password
            'role': role,
            'id': user_id,
            'name': name
        }
        
        # Generate tokens
        access_token, refresh_token = generate_tokens(user_id, role)
        
        return jsonify({
            'message': 'User created successfully',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': {
                'id': user_id,
                'email': email,
                'name': name,
                'role': role
            }
        }), 201
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/signin', methods=['POST'])
def signin():
    """Dummy signin endpoint"""
    try:
        data = request.get_json()
        
        if not data or not data.get('email') or not data.get('password'):
            return jsonify({'message': 'Email and password are required'}), 400
        
        email = data['email']
        password = data['password']
        
        # Check if user exists
        if email not in users_db:
            return jsonify({'message': 'Invalid credentials'}), 401
        
        user = users_db[email]
        
        # Verify password (dummy check - in production, use proper password hashing)
        if user['password'] != password:
            return jsonify({'message': 'Invalid credentials'}), 401
        
        # Generate tokens
        access_token, refresh_token = generate_tokens(user['id'], user['role'])
        
        return jsonify({
            'message': 'Login successful',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': {
                'id': user['id'],
                'email': email,
                'name': user['name'],
                'role': user['role']
            }
        }), 200
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/refresh', methods=['POST'])
def refresh_token():
    """Refresh access token using refresh token"""
    try:
        data = request.get_json()
        
        if not data or not data.get('refresh_token'):
            return jsonify({'message': 'Refresh token is required'}), 400
        
        refresh_token = data['refresh_token']
        
        # Verify refresh token
        payload = verify_token(refresh_token, 'refresh')
        if not payload:
            return jsonify({'message': 'Invalid or expired refresh token'}), 401
        
        # Find user
        user_id = payload['user_id']
        user = None
        for email, user_data in users_db.items():
            if user_data['id'] == user_id:
                user = user_data
                break
        
        if not user:
            return jsonify({'message': 'User not found'}), 404
        
        # Generate new access token
        access_token_payload = {
            'user_id': user_id,
            'role': user['role'],
            'exp': datetime.datetime.now(datetime.UTC) + app.config['JWT_ACCESS_TOKEN_EXPIRES'],
            'iat': datetime.datetime.now(datetime.UTC),
            'type': 'access'
        }
        
        new_access_token = jwt.encode(access_token_payload, app.config['SECRET_KEY'], algorithm='HS256')
        
        return jsonify({
            'access_token': new_access_token,
            'message': 'Token refreshed successfully'
        }), 200
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/logout', methods=['POST'])
@token_required
def logout():
    """Logout user and invalidate refresh token"""
    try:
        data = request.get_json()
        
        if data and data.get('refresh_token'):
            refresh_token = data['refresh_token']
            # Remove refresh token from store
            refresh_tokens.discard(refresh_token)
        
        return jsonify({'message': 'Logged out successfully'}), 200
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/profile', methods=['GET'])
@token_required
def get_profile():
    """Get user profile (requires authentication)"""
    try:
        user_id = request.current_user['id']
        
        # Find user
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


from styles import styles  # Make sure this is imported


@app.route('/api/generate', methods=['POST'])
def generate_image():
    global gen_instance
    gen = gen_instance
    """Generate image using simple direct approach with token validation."""
    try:
        data = request.get_json()
        if not data or not data.get('prompt'):
            return jsonify({'message': 'Prompt is required'}), 400

        prompt = data['prompt']
        style = data.get('style')
        user_id = data.get('userId')

        # Validate style
        if not style or style not in styles:
            style = list(styles.keys())[0]  # Use first style as default

        # Check token availability if user_id is provided
        if user_id:
            try:
                # Try Firestore first, fallback to in-memory store
                has_tokens = False
                consumed = False
                
                try:
                    has_tokens = firestore_service.check_token_availability(user_id)
                    if has_tokens:
                        consumed = firestore_service.consume_token(user_id)
                except Exception as firestore_error:
                    print(f"Firestore error: {firestore_error}")
                    print("Falling back to in-memory token store")
                    has_tokens = in_memory_store.check_token_availability(user_id)
                    if has_tokens:
                        consumed = in_memory_store.consume_token(user_id)
                
                if not has_tokens:
                    return jsonify({
                        'message': 'Insufficient tokens. Please watch an ad or purchase more tokens.',
                        'error_code': 'INSUFFICIENT_TOKENS'
                    }), 402  # Payment Required
                
                if not consumed:
                    return jsonify({
                        'message': 'Failed to consume token. Please try again.',
                        'error_code': 'TOKEN_CONSUMPTION_FAILED'
                    }), 500
                    
            except Exception as token_error:
                print(f"Token validation error for user {user_id}: {token_error}")
                # Continue without token validation if both systems fail
                print("Proceeding without token validation (both systems failed)")

        # Get Gen instance and generate image directly
        try:
            # gen = get_gen_instance()
            image_b64 = gen.play(prompt, style)
            
            if not image_b64:
                # If image generation failed and we consumed a token, we should ideally refund it
                if user_id:
                    print(f"Image generation failed for user {user_id}, token may need refund")
                return jsonify({'message': 'Image generation failed'}), 500
            
            # Log successful generation
            if user_id:
                print(f"Image generated successfully for user {user_id}")
            
            return jsonify({
                'message': 'Image generated successfully',
                'image': image_b64,
                'prompt': prompt,
                'style': style
            }), 200
            
        except Exception as gen_error:
            print(f"Generation error: {gen_error}")
            # If image generation failed and we consumed a token, we should ideally refund it
            if user_id:
                print(f"Image generation error for user {user_id}, token may need refund")
            return jsonify({'message': 'Image generation error'}), 500
        
    except Exception as e:
        print(f"Error in generate_image: {e}")
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/admin/users', methods=['GET'])
@token_required
@admin_required
def get_all_users():
    """Get all users (admin only)"""
    try:
        users_list = []
        for email, user_data in users_db.items():
            users_list.append({
                'id': user_data['id'],
                'email': email,
                'name': user_data['name'],
                'role': user_data['role']
            })
        
        return jsonify({
            'users': users_list,
            'total': len(users_list)
        }), 200
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/admin/dashboard', methods=['GET'])
@token_required
@admin_required
def admin_dashboard():
    """Admin dashboard endpoint"""
    try:
        return jsonify({
            'message': 'Welcome to admin dashboard',
            'stats': {
                'total_users': len(users_db),
                'active_sessions': len(refresh_tokens)
            }
        }), 200
        
    except Exception as e:
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/user/dashboard', methods=['GET'])
@token_required
def user_dashboard():
    """User dashboard endpoint"""
    try:
        return jsonify({
            'message': f'Welcome to user dashboard, {request.current_user["role"]}!',
            'user_id': request.current_user['id']
        }), 200
        
    except Exception as e:
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
                    'userId': user_id,
                    'source': 'firestore'
                }), 200
        except Exception as firestore_error:
            print(f"Firestore error: {firestore_error}")
        
        # Fallback to in-memory store
        user_profile = in_memory_store.get_user_profile(user_id)
        return jsonify({
            'tokenCount': user_profile.get('tokenCount', 5),
            'userId': user_id,
            'source': 'memory'
        }), 200
        
    except Exception as e:
        print(f"Error getting user tokens: {e}")
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/user/profile/<user_id>', methods=['GET'])
def get_user_profile_endpoint(user_id):
    """Get user's full profile"""
    try:
        # Try Firestore first, fallback to in-memory store
        try:
            user_profile = firestore_service.get_user_profile(user_id)
            if user_profile:
                return jsonify({
                    'profile': user_profile,
                    'userId': user_id,
                    'source': 'firestore'
                }), 200
        except Exception as firestore_error:
            print(f"Firestore error: {firestore_error}")
        
        # Fallback to in-memory store
        user_profile = in_memory_store.get_user_profile(user_id)
        return jsonify({
            'profile': user_profile,
            'userId': user_id,
            'source': 'memory'
        }), 200
        
    except Exception as e:
        print(f"Error getting user profile: {e}")
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/user/tokens/<user_id>/add', methods=['POST'])
def add_user_tokens(user_id):
    """Add tokens to user's account (for watching ads, etc.)"""
    try:
        data = request.get_json()
        tokens_to_add = data.get('tokens', 2)  # Default 2 tokens
        
        print(f"Adding {tokens_to_add} tokens to user {user_id}")
        
        # Try Firestore first, fallback to in-memory store
        success = False
        try:
            # Use Firestore service to add tokens
            success = firestore_service.add_tokens(user_id, tokens_to_add)
            print(f"Firestore add_tokens result: {success}")
        except Exception as firestore_error:
            print(f"Firestore error: {firestore_error}")
            success = False
        
        # If Firestore fails, use in-memory store as fallback
        if not success:
            print("Firestore failed, using in-memory store fallback")
            success = in_memory_store.add_tokens(user_id, tokens_to_add)
        
        if success:
            # Get updated token count from Firestore or in-memory store
            try:
                user_profile = firestore_service.get_user_profile(user_id)
                if user_profile:
                    token_count = user_profile.get('tokenCount', 0)
                    print(f"Updated token count from Firestore: {token_count}")
                else:
                    # Fallback to in-memory store
                    user_profile = in_memory_store.get_user_profile(user_id)
                    token_count = user_profile.get('tokenCount', 0)
                    print(f"Updated token count from in-memory store: {token_count}")
            except Exception as e:
                print(f"Error getting updated token count: {e}")
                token_count = 0
            
            return jsonify({
                'message': f'Added {tokens_to_add} tokens successfully',
                'tokenCount': token_count,
                'userId': user_id
            }), 200
        else:
            print("Both Firestore and in-memory store failed")
            return jsonify({'message': 'Failed to add tokens'}), 500
            
    except Exception as e:
        print(f"Error adding tokens: {e}")
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.datetime.now(datetime.UTC).isoformat(),
        'gen_initialized': gen_instance is not None
    }), 200


@app.route('/api/warmup', methods=['POST'])
def warmup():
    """Warmup endpoint to initialize Gen instance"""
    try:
        gen = get_gen_instance()
        return jsonify({
            'message': 'Gen instance initialized successfully',
            'status': 'ready'
        }), 200
    except Exception as e:
        return jsonify({
            'message': f'Failed to initialize Gen instance: {str(e)}',
            'status': 'error'
        }), 500


@app.errorhandler(404)
def not_found(error):
    return jsonify({'message': 'Endpoint not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({'message': 'Internal server error'}), 500


if __name__ == '__main__':
    print("Starting Flask server (simple version)...")
    print("Dummy users available:")
    print("Admin: admin@example.com / admin123")
    print("User: user@example.com / user123")
    print("Gen instance will be initialized on first request or warmup call")
    
    gen_instance = get_gen_instance()
    
    print("Gen instance initialized successfully")

    app.run(debug=False, host='0.0.0.0', port=5000, use_reloader=False)