import logging
from typing import Dict, Optional

logger = logging.getLogger(__name__)

class InMemoryTokenStore:
    """Simple in-memory token storage for development/testing"""
    
    def __init__(self):
        self.users: Dict[str, Dict] = {}
        logger.info("In-memory token store initialized")
    
    def check_token_availability(self, user_id: str) -> bool:
        """Check if user has tokens available"""
        if user_id not in self.users:
            # Create default user profile
            self.users[user_id] = {
                'uid': user_id,
                'tokenCount': 5,
                'email': '',
                'name': '',
                'photoUrl': ''
            }
        
        token_count = self.users[user_id].get('tokenCount', 0)
        logger.info(f"In-memory check: User {user_id} has {token_count} tokens")
        return token_count > 0
    
    def consume_token(self, user_id: str) -> bool:
        """Consume one token from user's account"""
        if user_id not in self.users:
            logger.error(f"User {user_id} not found when consuming token")
            return False
        
        current_tokens = self.users[user_id].get('tokenCount', 0)
        if current_tokens <= 0:
            logger.error(f"User {user_id} has no tokens to consume")
            return False
        
        self.users[user_id]['tokenCount'] = current_tokens - 1
        logger.info(f"Token consumed for user {user_id}. Remaining: {current_tokens - 1}")
        return True
    
    def get_user_profile(self, user_id: str) -> Optional[Dict]:
        """Get user profile"""
        if user_id not in self.users:
            # Create default user profile
            self.users[user_id] = {
                'uid': user_id,
                'tokenCount': 5,
                'email': '',
                'name': '',
                'photoUrl': ''
            }
        
        return self.users[user_id]
    
    def add_tokens(self, user_id: str, tokens_to_add: int) -> bool:
        """Add tokens to user's account"""
        if user_id not in self.users:
            self.users[user_id] = {
                'uid': user_id,
                'tokenCount': 0,
                'email': '',
                'name': '',
                'photoUrl': ''
            }
        
        current_tokens = self.users[user_id].get('tokenCount', 0)
        self.users[user_id]['tokenCount'] = current_tokens + tokens_to_add
        logger.info(f"Added {tokens_to_add} tokens to user {user_id}. New total: {current_tokens + tokens_to_add}")
        return True

# Global instance
in_memory_store = InMemoryTokenStore()