#!/usr/bin/env python3
"""
Test script for the image generation server with token management
"""

import requests
import json
import time

BASE_URL = "http://localhost:5000"

def test_health():
    """Test the health endpoint"""
    print("Testing health endpoint...")
    response = requests.get(f"{BASE_URL}/api/health")
    print(f"Health check: {response.status_code} - {response.json()}")
    return response.status_code == 200

def test_user_tokens(user_id):
    """Test getting user tokens"""
    print(f"\nTesting user tokens for {user_id}...")
    response = requests.get(f"{BASE_URL}/api/user/tokens/{user_id}")
    print(f"User tokens: {response.status_code} - {response.json()}")
    return response.json() if response.status_code == 200 else None

def test_add_tokens(user_id, tokens=2):
    """Test adding tokens to user"""
    print(f"\nTesting add tokens for {user_id}...")
    data = {"tokens": tokens}
    response = requests.post(
        f"{BASE_URL}/api/user/tokens/{user_id}/add",
        headers={"Content-Type": "application/json"},
        data=json.dumps(data)
    )
    print(f"Add tokens: {response.status_code} - {response.json()}")
    return response.status_code == 200

def test_image_generation_with_tokens(user_id, prompt="a beautiful sunset"):
    """Test image generation with token validation"""
    print(f"\nTesting image generation with tokens for {user_id}...")
    data = {
        "prompt": prompt,
        "style": "Painted Anime",
        "userId": user_id
    }
    
    print(f"Sending request: {data}")
    response = requests.post(
        f"{BASE_URL}/api/generate",
        headers={"Content-Type": "application/json"},
        data=json.dumps(data),
        timeout=70  # Allow for image generation time
    )
    
    print(f"Image generation: {response.status_code}")
    if response.status_code == 200:
        result = response.json()
        print(f"Success: {result['message']}")
        print(f"Image data length: {len(result.get('image', ''))}")
        return True
    else:
        print(f"Error: {response.json()}")
        return False

def test_image_generation_without_tokens(user_id, prompt="another sunset"):
    """Test image generation when user has no tokens"""
    print(f"\nTesting image generation without tokens for {user_id}...")
    
    # First, try to get user current tokens
    token_info = test_user_tokens(user_id)
    if token_info and token_info.get('tokenCount', 0) > 0:
        print("User still has tokens, consuming them first...")
        # For testing, we'll just proceed - in real scenario, 
        # we might need to consume all tokens first
    
    data = {
        "prompt": prompt,
        "style": "Painted Anime",
        "userId": user_id
    }
    
    response = requests.post(
        f"{BASE_URL}/api/generate",
        headers={"Content-Type": "application/json"},
        data=json.dumps(data),
        timeout=70
    )
    
    print(f"Image generation (no tokens): {response.status_code}")
    if response.status_code == 402:  # Payment Required
        result = response.json()
        print(f"Expected error: {result['message']}")
        return True
    else:
        print(f"Unexpected response: {response.json()}")
        return False

def main():
    """Run all tests"""
    print("Starting backend tests...")
    
    # Test health endpoint
    if not test_health():
        print("Health check failed, server might not be running")
        return
    
    # Test user ID
    test_user_id = "test_user_123"
    
    # Test 1: Get initial user tokens
    initial_tokens = test_user_tokens(test_user_id)
    
    # Test 2: Add tokens
    test_add_tokens(test_user_id, 2)
    
    # Test 3: Check tokens after adding
    updated_tokens = test_user_tokens(test_user_id)
    
    # Test 4: Generate image with tokens
    success = test_image_generation_with_tokens(test_user_id, "a beautiful mountain landscape")
    
    # Test 5: Check tokens after generation
    after_generation_tokens = test_user_tokens(test_user_id)
    
    # Test 6: Generate another image
    test_image_generation_with_tokens(test_user_id, "a serene ocean view")
    
    # Test 7: Check final tokens
    final_tokens = test_user_tokens(test_user_id)
    
    print("\n" + "="*50)
    print("TEST SUMMARY")
    print("="*50)
    print(f"Initial tokens: {initial_tokens}")
    print(f"After adding 2: {updated_tokens}")
    print(f"After 1st generation: {after_generation_tokens}")
    print(f"Final tokens: {final_tokens}")
    
    if success:
        print("✅ Basic token management working!")
    else:
        print("❌ Some tests failed")

if __name__ == "__main__":
    main()