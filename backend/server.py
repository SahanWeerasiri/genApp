import os
import jwt
import datetime
from functools import wraps
from flask import Flask, request, jsonify, make_response
from flask_cors import CORS
import dotenv
from gen import Gen
import queue
import threading

# Load environment variables
dotenv.load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-change-this')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = datetime.timedelta(minutes=15)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = datetime.timedelta(days=30)
app.config['generators'] = {}

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

# Job queue for prompt jobs
job_queue = queue.Queue()

# Pool size for Gen objects
GEN_POOL_SIZE = 1  # You can adjust this number
# Pre-initialize Gen() objects
gen_pool = [Gen() for _ in range(GEN_POOL_SIZE)]
# Track which Gen objects are available
pool_locks = [threading.Lock() for _ in range(GEN_POOL_SIZE)]


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
# @token_required
def generate_image():
    """Generate image using Gen pool and job queue."""
    try:
        data = request.get_json()
        if not data or not data.get('prompt'):
            return jsonify({'message': 'Prompt is required'}), 400

        prompt = data['prompt']
        style = data.get('style')

        # Validate style
        if not style or style not in styles:
            style = list(styles.keys())[0]  # Use first style as default

        # Prepare synchronization primitives
        result_container = {}
        done_event = threading.Event()

        def job_callback(image_b64):
            result_container['image'] = image_b64
            done_event.set()

        # Submit job to queue
        job_queue.put({
            'prompt': prompt,
            'style': style,
            'callback': job_callback
        })

        # Wait for job to complete (timeout after 60 seconds)
        finished = done_event.wait(timeout=60)
        if not finished or 'image' not in result_container:
            return jsonify({'message': 'Image generation timed out'}), 500

        image_b64 = result_container['image']
        return jsonify({
            'message': 'Image generated successfully',
            'image': image_b64,
            'prompt': prompt,
            'style': style
        }), 200
    except Exception as e:
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


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.datetime.now(datetime.UTC).isoformat()
    }), 200


@app.errorhandler(404)
def not_found(error):
    return jsonify({'message': 'Endpoint not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({'message': 'Internal server error'}), 500


def gen_worker(worker_id):
    while True:
        job = job_queue.get()  # Wait for a job
        if job is None:
            break  # Shutdown signal
        # Find an available Gen object
        for i, lock in enumerate(pool_locks):
            if lock.acquire(blocking=False):
                try:
                    gen = gen_pool[i]
                    # Assume job is a dict with 'prompt' and 'callback' keys
                    prompt = job['prompt']
                    style = job.get('style', None)
                    # Generate image using play
                    image = gen.play(prompt, style)
                    # Call the callback with the result
                    if 'callback' in job:
                        job['callback'](image)
                finally:
                    lock.release()
                break
        else:
            # No Gen available, requeue the job
            job_queue.put(job)
        job_queue.task_done()

# Start worker threads
NUM_WORKERS = GEN_POOL_SIZE
for worker_id in range(NUM_WORKERS):
    threading.Thread(target=gen_worker, args=(worker_id,), daemon=True).start()

if __name__ == '__main__':
    print("Starting Flask server...")
    print("Dummy users available:")
    print("Admin: admin@example.com / admin123")
    print("User: user@example.com / user123")
    
    # default generators count = 2
    # for i in range(2):
    #     app.config['generators'][i] = Gen()
    #     print(f"Starting generator {i}...")
    app.run(debug=False, host='0.0.0.0', port=5000, use_reloader=False)
