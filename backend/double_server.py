import os
import jwt
import datetime
import base64
import io
import requests
from functools import wraps
from flask import Flask, request, jsonify, make_response
from flask_cors import CORS
import dotenv
from gen import Gen
import queue
import threading
from firestore_service import firestore_service
from in_memory_store import in_memory_store
from styles import styles

# Load environment variables
dotenv.load_dotenv()

app = Flask(__name__)

# Get configuration from environment variables
PORT = int(os.getenv('PORT', 5001))

app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-change-this')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = datetime.timedelta(minutes=15)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = datetime.timedelta(days=30)

# Enable CORS
CORS(app)

# Store refresh tokens (in production, use a database)
refresh_tokens = set()

# Telegram bot configuration
SECOND_BOT_TOKEN = os.getenv('SECOND_BOT_TOKEN')
SECOND_BOT_CHAT_ID = "1668869874"  # Fixed chat ID for the second bot

# Internal worker configuration
WORKERS = ['worker-1', 'worker-2']
worker_queues = {}
worker_gens = {}
worker_locks = {}
worker_threads = {}
worker_initialization_status = {}

# Initialize worker queues and locks immediately
for worker_id in WORKERS:
    print(f"Setting up {worker_id} infrastructure...")
    worker_queues[worker_id] = queue.Queue()
    worker_locks[worker_id] = threading.Lock()
    worker_gens[worker_id] = None  # Will be initialized asynchronously
    worker_initialization_status[worker_id] = 'pending'

# Global load balancer index
current_worker_index = 0
worker_selection_lock = threading.Lock()


def initialize_worker_gen(worker_id):
    """Initialize Gen object for a worker asynchronously"""
    try:
        print(f"{worker_id}: Starting Gen initialization...")
        worker_initialization_status[worker_id] = 'initializing'
        
        # Initialize Gen object for this worker
        gen_instance = Gen(worker_id=worker_id)
        
        # Store the initialized Gen instance
        worker_gens[worker_id] = gen_instance
        worker_initialization_status[worker_id] = 'ready'
        
        print(f"{worker_id}: Gen initialization completed successfully")
        
    except Exception as e:
        print(f"{worker_id}: Gen initialization failed: {e}")
        worker_initialization_status[worker_id] = 'failed'
        # Keep worker_gens[worker_id] as None


def get_available_workers():
    """Get list of workers that are ready to process jobs"""
    return [worker_id for worker_id in WORKERS 
            if worker_initialization_status[worker_id] == 'ready' and worker_gens[worker_id] is not None]


def get_next_worker():
    """Round-robin worker selection from available workers only"""
    global current_worker_index
    with worker_selection_lock:
        available_workers = get_available_workers()
        
        if not available_workers:
            return None  # No workers available
            
        # Use modulo with available workers count
        worker_id = available_workers[current_worker_index % len(available_workers)]
        current_worker_index = (current_worker_index + 1) % len(available_workers)
        return worker_id


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


def send_image_to_telegram_bot(image_b64, prompt, style, message_type="user", worker_id="unknown"):
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
        
        # Create different captions based on message type
        if message_type == "health":
            caption = f"🔥 Health Check Image Generated! 🔥\nPrompt: {prompt}\nStyle: {style}\nWorker: {worker_id}\nPort: {PORT}"
        else:
            caption = f"✨ User Generated Image ✨\nPrompt: {prompt}\nStyle: {style}\nWorker: {worker_id}\nPort: {PORT}"
        
        data = {
            'chat_id': SECOND_BOT_CHAT_ID,
            'caption': caption
        }
        
        # Send photo to Telegram bot
        url = f"https://api.telegram.org/bot{SECOND_BOT_TOKEN}/sendPhoto"
        response = requests.post(url, files=files, data=data, timeout=30)
        
        if response.status_code == 200:
            print(f"{message_type.capitalize()} image sent successfully to Telegram bot from {worker_id}")
            return True
        else:
            print(f"Failed to send {message_type} image to Telegram bot from {worker_id}: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"Error sending {message_type} image to Telegram bot from {worker_id}: {e}")
        return False


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


@app.route('/api/register', methods=['POST'])
def register():
    """Register user with Firebase UID and create Firestore profile"""
    try:
        data = request.get_json()
        
        if not data or not data.get('uid'):
            return jsonify({'message': 'Firebase UID is required'}), 400
        
        uid = data['uid']
        email = data.get('email', '')
        name = data.get('name', 'User')
        photo_url = data.get('photoUrl', '')
        
        print(f"Registering user with UID: {uid}, email: {email}")
        
        try:
            # Check if user already exists in Firestore
            existing_profile = firestore_service.get_user_profile(uid)
            if existing_profile:
                print(f"User {uid} already exists, returning existing data")
                # Generate access token for existing user
                access_token, refresh_token = generate_tokens(uid, 'user')
                
                return jsonify({
                    'message': 'User already exists',
                    'access_token': access_token,
                    'refresh_token': refresh_token,
                    'user': {
                        'uid': uid,
                        'email': email,
                        'name': name,
                        'photoUrl': photo_url,
                        'tokenCount': existing_profile.get('tokenCount', 5)
                    }
                }), 200
            
            # Create new user profile in Firestore
            user_profile = {
                'uid': uid,
                'email': email,
                'name': name,
                'photoUrl': photo_url,
                'tokenCount': 5,  # Default 5 tokens
                'createdAt': datetime.datetime.now(datetime.UTC).isoformat(),
                'updatedAt': datetime.datetime.now(datetime.UTC).isoformat()
            }
            
            success = firestore_service.create_user_profile(user_profile)
            if not success:
                print(f"Failed to create user profile in Firestore for {uid}")
                return jsonify({'message': 'Failed to create user profile'}), 500
            
            print(f"User profile created successfully in Firestore for {uid}")
            
        except Exception as firestore_error:
            print(f"Firestore error: {firestore_error}")
            print("Falling back to in-memory store")
            
            # Fallback to in-memory store
            existing_profile = in_memory_store.get_user_profile(uid)
            if existing_profile:
                print(f"User {uid} already exists in memory store")
                access_token, refresh_token = generate_tokens(uid, 'user')
                
                return jsonify({
                    'message': 'User already exists',
                    'access_token': access_token,
                    'refresh_token': refresh_token,
                    'user': {
                        'uid': uid,
                        'email': email,
                        'name': name,
                        'photoUrl': photo_url,
                        'tokenCount': existing_profile.get('tokenCount', 5)
                    }
                }), 200
            
            # Create new user in memory store
            user_profile = {
                'uid': uid,
                'email': email,
                'name': name,
                'photoUrl': photo_url,
                'tokenCount': 5,
                'createdAt': datetime.datetime.now(datetime.UTC).isoformat(),
                'updatedAt': datetime.datetime.now(datetime.UTC).isoformat()
            }
            
            success = in_memory_store.create_user_profile(user_profile)
            if not success:
                return jsonify({'message': 'Failed to create user profile'}), 500
        
        # Generate access and refresh tokens
        access_token, refresh_token = generate_tokens(uid, 'user')
        
        return jsonify({
            'message': 'User registered successfully',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': {
                'uid': uid,
                'email': email,
                'name': name,
                'photoUrl': photo_url,
                'tokenCount': 5
            }
        }), 201
        
    except Exception as e:
        print(f"Registration error: {e}")
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/verify', methods=['GET', 'POST'])
def verify():
    """Verify access token and return user data"""
    try:
        access_token = None
        
        # Support both POST body and GET Authorization header
        if request.method == 'POST':
            data = request.get_json()
            if data and data.get('access_token'):
                access_token = data['access_token']
        
        # If no token in body, check Authorization header
        if not access_token:
            auth_header = request.headers.get('Authorization')
            if auth_header and auth_header.startswith('Bearer '):
                access_token = auth_header.split(' ')[1]
        
        if not access_token:
            return jsonify({'message': 'Access token is required'}), 400
        
        # Verify the token
        payload = verify_token(access_token, 'access')
        if not payload:
            return jsonify({'message': 'Invalid or expired token'}), 401
        
        user_id = payload['user_id']
        
        try:
            # Get user profile from Firestore
            user_profile = firestore_service.get_user_profile(user_id)
            if user_profile:
                return jsonify({
                    'message': 'Token valid',
                    'user': {
                        'uid': user_id,
                        'email': user_profile.get('email', ''),
                        'name': user_profile.get('name', 'User'),
                        'photoUrl': user_profile.get('photoUrl', ''),
                        'tokenCount': user_profile.get('tokenCount', 5)
                    }
                }), 200
        except Exception as firestore_error:
            print(f"Firestore error: {firestore_error}")
        
        # Fallback to in-memory store
        user_profile = in_memory_store.get_user_profile(user_id)
        if user_profile:
            return jsonify({
                'message': 'Token valid',
                'user': {
                    'uid': user_id,
                    'email': user_profile.get('email', ''),
                    'name': user_profile.get('name', 'User'),
                    'photoUrl': user_profile.get('photoUrl', ''),
                    'tokenCount': user_profile.get('tokenCount', 5)
                }
            }), 200
        
        return jsonify({'message': 'User not found'}), 404
        
    except Exception as e:
        print(f"Verification error: {e}")
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/refresh', methods=['POST'])
def refresh_token():
    """Refresh access token using refresh token"""
    try:
        data = request.get_json()
        if not data or not data.get('refresh_token'):
            return jsonify({'message': 'Refresh token is required'}), 400
        
        refresh_token = data['refresh_token']
        
        # Verify the refresh token
        payload = verify_token(refresh_token, 'refresh')
        if not payload:
            return jsonify({'message': 'Invalid or expired refresh token'}), 401
        
        user_id = payload['user_id']
        role = payload.get('role', 'user')
        
        # Generate new access token
        new_access_token, _ = generate_tokens(user_id, role)
        
        return jsonify({
            'message': 'Token refreshed successfully',
            'access_token': new_access_token
        }), 200
        
    except Exception as e:
        print(f"Token refresh error: {e}")
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/generate', methods=['POST'])
@token_required
def generate_image():
    """Generate image using worker pool with load balancing and token validation."""
    try:
        data = request.get_json()
        if not data or not data.get('prompt'):
            return jsonify({'message': 'Prompt is required'}), 400

        prompt = data['prompt']
        style = data.get('style')
        user_id = request.current_user['id']  # Get from authenticated token

        # Validate style
        if not style or style not in styles:
            style = list(styles.keys())[0]  # Use first style as default

        # Check token availability
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
            return jsonify({
                'message': 'Token validation failed. Please try again.',
                'error_code': 'TOKEN_VALIDATION_FAILED'
            }), 500

        # Select worker using round-robin
        selected_worker = get_next_worker()
        
        if not selected_worker:
            return jsonify({
                'message': 'No workers available. Please try again later.',
                'error_code': 'NO_WORKERS_AVAILABLE'
            }), 503  # Service Unavailable
            
        print(f"Assigning job to {selected_worker}")

        # Prepare synchronization primitives
        result_container = {}
        done_event = threading.Event()

        def job_callback(image_b64):
            result_container['image'] = image_b64
            result_container['worker'] = selected_worker
            done_event.set()

        # Submit job to selected worker queue
        worker_queues[selected_worker].put({
            'prompt': prompt,
            'style': style,
            'callback': job_callback
        })

        # Wait for job to complete (timeout after 60 seconds)
        finished = done_event.wait(timeout=60)
        if not finished or 'image' not in result_container:
            # If image generation failed and we consumed a token, we should ideally refund it
            # For now, we'll just log the issue
            print(f"Image generation timed out for user {user_id} on {selected_worker}, token may need refund")
            return jsonify({'message': 'Image generation timed out'}), 500

        image_b64 = result_container['image']
        worker_used = result_container['worker']
        
        # Send image to Telegram bot for normal image generation requests
        try:
            telegram_success = send_image_to_telegram_bot(image_b64, prompt, style, "user", worker_used)
            if telegram_success:
                print(f"Image sent successfully to Telegram for user {user_id} from {worker_used}")
            else:
                print(f"Failed to send image to Telegram for user {user_id} from {worker_used}")
        except Exception as telegram_error:
            print(f"Error sending image to Telegram for user {user_id} from {worker_used}: {telegram_error}")
        
        # Log successful generation
        print(f"Image generated successfully for user {user_id} using {worker_used}")
        
        return jsonify({
            'message': 'Image generated successfully',
            'image': image_b64,
            'prompt': prompt,
            'style': style,
            'worker': worker_used
        }), 200
        
    except Exception as e:
        print(f"Error in generate_image: {e}")
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/user/tokens', methods=['GET'])
@token_required
def get_user_tokens():
    """Get user's token count"""
    try:
        user_id = request.current_user['id']
        
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


@app.route('/api/user/profile', methods=['GET'])
@token_required
def get_user_profile_endpoint():
    """Get user's full profile"""
    try:
        user_id = request.current_user['id']
        
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


@app.route('/api/user/tokens/add', methods=['POST'])
@token_required
def add_user_tokens():
    """Add tokens to user's account (for watching ads, etc.)"""
    try:
        data = request.get_json()
        tokens_to_add = data.get('tokens', 2)  # Default 2 tokens
        user_id = request.current_user['id']
        
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


@app.route('/api/styles', methods=['GET'])
def get_styles():
    """Get available image generation styles"""
    try:
        return jsonify({
            'styles': list(styles.keys()),
            'count': len(styles)
        }), 200
    except Exception as e:
        print(f"Error getting styles: {e}")
        return jsonify({'message': 'Internal server error'}), 500


@app.route('/api/health-generate', methods=['GET', 'POST'])
def health_generate():
    """Health check endpoint that submits image generation job to keep server active"""
    try:
        # Select a worker for health check
        selected_worker = get_next_worker()
        
        if not selected_worker:
            return jsonify({
                'status': 'degraded',
                'message': 'No workers available for health check',
                'port': PORT,
                'timestamp': datetime.datetime.now(datetime.UTC).isoformat(),
                'worker_statuses': worker_initialization_status,
                'worker_queue_sizes': {worker: worker_queues[worker].qsize() for worker in WORKERS}
            }), 503
        
        # Submit a simple job to keep the generation system warm
        def dummy_callback(image_b64, error=None):
            if error:
                print(f"{selected_worker}: Health check failed: {error}")
                return
                
            # Log the successful generation
            print(f"{selected_worker}: Health check image generated successfully at {datetime.datetime.now(datetime.UTC)}")
            
            # Send image to Telegram bot
            if image_b64:
                send_image_to_telegram_bot(image_b64, 'lovely couple with painted anime style', 'anime', 'health', selected_worker)
            else:
                print(f"No image data received for health check from {selected_worker}")
        
        # Submit job to selected worker queue with health check prompt
        worker_queues[selected_worker].put({
            'prompt': 'lovely couple with painted anime style',
            'style': 'anime',  # Use a default style
            'callback': dummy_callback
        })
        
        return jsonify({
            'status': 'healthy',
            'message': 'Health check job submitted successfully - image will be sent to Telegram',
            'worker_used': selected_worker,
            'port': PORT,
            'timestamp': datetime.datetime.now(datetime.UTC).isoformat(),
            'worker_statuses': worker_initialization_status,
            'worker_queue_sizes': {worker: worker_queues[worker].qsize() for worker in WORKERS}
        }), 200
        
    except Exception as e:
        print(f"Health check error: {e}")
        return jsonify({
            'status': 'unhealthy',
            'message': f'Health check failed: {str(e)}',
            'timestamp': datetime.datetime.now(datetime.UTC).isoformat()
        }), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    available_workers = get_available_workers()
    total_workers = len(WORKERS)
    
    status = 'healthy' if available_workers else 'degraded'
    if len(available_workers) < total_workers:
        status = 'degraded'
    
    return jsonify({
        'status': status,
        'workers': WORKERS,
        'available_workers': available_workers,
        'worker_statuses': worker_initialization_status,
        'port': PORT,
        'worker_queue_sizes': {worker: worker_queues[worker].qsize() for worker in WORKERS},
        'total_active_jobs': sum(worker_queues[worker].qsize() for worker in WORKERS),
        'workers_initialized': {worker: worker_gens[worker] is not None for worker in WORKERS},
        'timestamp': datetime.datetime.now(datetime.UTC).isoformat()
    }), 200


@app.errorhandler(404)
def not_found(error):
    return jsonify({'message': 'Endpoint not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({'message': 'Internal server error'}), 500


def gen_worker(worker_id):
    """Worker function that processes jobs using the worker-specific Gen instance"""
    print(f"Starting worker thread: {worker_id}")
    
    # Initialize Gen object asynchronously in the worker thread
    initialize_worker_gen(worker_id)
    
    while True:
        try:
            job = worker_queues[worker_id].get()  # Wait for a job
            if job is None:
                break  # Shutdown signal
            
            # Check if worker is ready
            if worker_initialization_status[worker_id] != 'ready' or worker_gens[worker_id] is None:
                print(f"{worker_id}: Worker not ready, skipping job")
                if 'callback' in job:
                    try:
                        job['callback'](None, error=f"Worker {worker_id} not ready")
                    except TypeError:
                        job['callback'](None)
                continue
            
            try:
                # Use the worker-specific Gen instance with thread safety
                with worker_locks[worker_id]:
                    prompt = job['prompt']
                    style = job.get('style', None)
                    # Generate image using play
                    image = worker_gens[worker_id].play(prompt, style)
                
                # Call the callback with the result (outside the lock)
                if 'callback' in job:
                    job['callback'](image)
                    
            except Exception as e:
                print(f"{worker_id}: Error processing job: {e}")
                # Call the callback with error if available
                if 'callback' in job:
                    try:
                        # Try to call with error parameter
                        job['callback'](None, error=str(e))
                    except TypeError:
                        # Fallback if callback doesn't accept error parameter
                        job['callback'](None)
            finally:
                worker_queues[worker_id].task_done()
                
        except Exception as e:
            print(f"{worker_id}: Critical error in worker loop: {e}")


if __name__ == '__main__':
    print(f"Starting Flask double server on port {PORT} with workers: {WORKERS}...")
    print("Available API endpoints:")
    print("- POST /api/register (User registration)")
    print("- GET/POST /api/verify (Token verification)")
    print("- POST /api/generate (Image generation)")
    print("- GET /api/user/tokens (Get token count)")
    print("- POST /api/user/tokens/add (Add tokens)")
    print("- GET /api/styles (Get available styles)")
    print("- GET /api/health (Basic health check)")
    print("- GET /api/health-generate (Health check with image generation)")
    
    # Start worker threads for both workers
    # Worker initialization will happen asynchronously in each thread
    for worker_id in WORKERS:
        worker_thread = threading.Thread(target=gen_worker, args=(worker_id,))
        worker_thread.daemon = True
        worker_thread.start()
        worker_threads[worker_id] = worker_thread
        print(f"Started worker thread: {worker_id} (initialization will happen asynchronously)")
    
    print("All worker threads started! Workers will initialize in the background.")
    print(f"Server will be available immediately on port {PORT}")

    app.run(debug=False, host='0.0.0.0', port=PORT, use_reloader=False)