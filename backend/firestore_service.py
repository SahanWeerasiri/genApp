import os
import json
import logging
import requests
from typing import Optional, Dict, Any
from urllib.parse import quote
from dotenv import load_dotenv

load_dotenv()  # Load environment variables from .env file

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class FirestoreService:
    def __init__(self):
        # Get Firebase project ID from environment or use default
        self.project_id = os.getenv('FIREBASE_PROJECT_ID', 'your-project-id')
        self.base_url = f"https://firestore.googleapis.com/v1/projects/{self.project_id}/databases/(default)/documents"
        
        # You can get this from Firebase Console -> Project Settings -> Web API Key
        self.api_key = os.getenv('FIREBASE_API_KEY', 'your-api-key')
        
        logger.info(f"Firestore service initialized for project: {self.project_id}")
    
    def _make_request(self, method: str, url: str, data: Optional[Dict] = None, headers: Optional[Dict] = None) -> Optional[Dict]:
        """Make HTTP request to Firestore REST API"""
        try:
            default_headers = {
                'Content-Type': 'application/json',
            }
            if headers:
                default_headers.update(headers)
            
            if method.upper() == 'GET':
                response = requests.get(url, headers=default_headers)
            elif method.upper() == 'POST':
                response = requests.post(url, json=data, headers=default_headers)
            elif method.upper() == 'PATCH':
                response = requests.patch(url, json=data, headers=default_headers)
            else:
                logger.error(f"Unsupported HTTP method: {method}")
                return None
            
            if response.status_code in [200, 201]:
                return response.json()
            elif response.status_code == 404:
                logger.info("Document not found")
                return None
            else:
                logger.error(f"Request failed with status {response.status_code}: {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"Error making request: {e}")
            return None
    
    def _convert_firestore_doc(self, firestore_doc: Dict) -> Dict[str, Any]:
        """Convert Firestore document format to simple dict"""
        if not firestore_doc or 'fields' not in firestore_doc:
            return {}
        
        result = {}
        for key, value_obj in firestore_doc['fields'].items():
            if 'stringValue' in value_obj:
                result[key] = value_obj['stringValue']
            elif 'integerValue' in value_obj:
                result[key] = int(value_obj['integerValue'])
            elif 'doubleValue' in value_obj:
                result[key] = float(value_obj['doubleValue'])
            elif 'booleanValue' in value_obj:
                result[key] = value_obj['booleanValue']
            elif 'timestampValue' in value_obj:
                result[key] = value_obj['timestampValue']
            else:
                result[key] = str(value_obj)
        
        return result
    
    def _convert_to_firestore_fields(self, data: Dict[str, Any]) -> Dict:
        """Convert simple dict to Firestore document format"""
        fields = {}
        for key, value in data.items():
            if isinstance(value, str):
                fields[key] = {'stringValue': value}
            elif isinstance(value, int):
                fields[key] = {'integerValue': str(value)}
            elif isinstance(value, float):
                fields[key] = {'doubleValue': value}
            elif isinstance(value, bool):
                fields[key] = {'booleanValue': value}
            else:
                fields[key] = {'stringValue': str(value)}
        
        return {'fields': fields}
    
    def check_token_availability(self, user_id: str) -> bool:
        """Check if user has tokens available"""
        try:
            user_doc = self.get_user_profile(user_id)
            if user_doc:
                token_count = user_doc.get('tokenCount', 0)
                logger.info(f"User {user_id} has {token_count} tokens")
                return token_count > 0
            else:
                logger.warning(f"User {user_id} not found in Firestore")
                return False
                
        except Exception as e:
            logger.error(f"Error checking token availability for user {user_id}: {e}")
            return False
    
    def consume_token(self, user_id: str) -> bool:
        """Consume one token from user's account"""
        try:
            # Get current user profile
            user_profile = self.get_user_profile(user_id)
            if not user_profile:
                logger.error(f"User {user_id} not found when consuming token")
                return False
            
            current_tokens = user_profile.get('tokenCount', 0)
            if current_tokens <= 0:
                logger.error(f"User {user_id} has no tokens to consume")
                return False
            
            # Update token count
            updated_data = {
                'tokenCount': current_tokens - 1,
                'updatedAt': '2024-01-01T00:00:00Z'  # You might want to use actual timestamp
            }
            
            success = self.update_user_profile(user_id, updated_data)
            if success:
                logger.info(f"Token consumed for user {user_id}. Remaining: {current_tokens - 1}")
            
            return success
            
        except Exception as e:
            logger.error(f"Error consuming token for user {user_id}: {e}")
            return False
    
    def add_tokens(self, user_id: str, tokens_to_add: int) -> bool:
        """Add tokens to user's account"""
        try:
            # Get current user profile
            user_profile = self.get_user_profile(user_id)
            if not user_profile:
                logger.error(f"User {user_id} not found when adding tokens")
                return False
            
            current_tokens = user_profile.get('tokenCount', 0)
            new_token_count = current_tokens + tokens_to_add
            
            # Update token count
            updated_data = {
                'tokenCount': new_token_count,
                'updatedAt': '2024-01-01T00:00:00Z'  # You might want to use actual timestamp
            }
            
            success = self.update_user_profile(user_id, updated_data)
            if success:
                logger.info(f"Added {tokens_to_add} tokens for user {user_id}. New total: {new_token_count}")
            
            return success
            
        except Exception as e:
            logger.error(f"Error adding tokens for user {user_id}: {e}")
            return False
    
    def get_user_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user profile from Firestore"""
        try:
            url = f"{self.base_url}/users/{user_id}?key={self.api_key}"
            response = self._make_request('GET', url)
            
            if response:
                user_data = self._convert_firestore_doc(response)
                logger.info(f"Retrieved profile for user {user_id}")
                return user_data
            else:
                logger.warning(f"User {user_id} not found in Firestore")
                return None
                
        except Exception as e:
            logger.error(f"Error getting user profile for {user_id}: {e}")
            return None
    
    def create_user_profile(self, user_id: str, email: str, name: str = "", photo_url: str = "") -> bool:
        """Create a new user profile"""
        try:
            # Check if user already exists
            if self.get_user_profile(user_id):
                logger.info(f"User {user_id} already exists")
                return True
            
            # Create new user profile
            user_data = {
                'uid': user_id,
                'email': email,
                'name': name,
                'photoUrl': photo_url,
                'tokenCount': 5,  # Initial token count
                'createdAt': '2024-01-01T00:00:00Z',
                'updatedAt': '2024-01-01T00:00:00Z'
            }
            
            firestore_data = self._convert_to_firestore_fields(user_data)
            url = f"{self.base_url}/users/{user_id}?key={self.api_key}"
            
            response = self._make_request('PATCH', url, firestore_data)
            
            if response:
                logger.info(f"Created user profile for {user_id}")
                return True
            else:
                logger.error(f"Failed to create user profile for {user_id}")
                return False
            
        except Exception as e:
            logger.error(f"Error creating user profile for {user_id}: {e}")
            return False
    
    def update_user_profile(self, user_id: str, update_data: Dict[str, Any]) -> bool:
        """Update user profile"""
        try:
            firestore_data = self._convert_to_firestore_fields(update_data)
            url = f"{self.base_url}/users/{user_id}?key={self.api_key}&updateMask.fieldPaths=" + "&updateMask.fieldPaths=".join(update_data.keys())
            
            response = self._make_request('PATCH', url, firestore_data)
            
            if response:
                logger.info(f"Updated user profile for {user_id}")
                return True
            else:
                logger.error(f"Failed to update user profile for {user_id}")
                return False
            
        except Exception as e:
            logger.error(f"Error updating user profile for {user_id}: {e}")
            return False

# Global instance
firestore_service = FirestoreService()