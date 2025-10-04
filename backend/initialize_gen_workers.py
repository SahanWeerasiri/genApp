#!/usr/bin/env python3
"""
Script to initialize a Gen object on one random worker.
This script makes a single request to potentially initialize one worker's Gen object.
Run this script multiple times to initialize different workers.
"""

import requests
import time
import os
import sys

# Configuration
BASE_URL = "http://localhost:5000"

def check_and_initialize():
    """Check status and initialize if needed with a single request"""
    try:
        # First check the current status
        print("🔍 Checking Gen object status...")
        response = requests.get(f"{BASE_URL}/api/gen-status", timeout=10)
        
        if response.status_code == 200:
            status_data = response.json()
            worker_pid = status_data.get('worker_pid')
            status = status_data.get('status')
            message = status_data.get('message')
            
            print(f"📊 Worker {worker_pid}: {status} - {message}")
            
            if status == "initialized":
                print(f"✅ Worker {worker_pid}: Already initialized!")
                return True
            elif status == "pending":
                print(f"⏳ Worker {worker_pid}: Initialization already in progress")
                return True
            elif status == "none":
                print(f"🚀 Worker {worker_pid}: Starting initialization...")
                
                # Initialize this worker
                init_response = requests.post(f"{BASE_URL}/api/initialize-gen", timeout=10)
                
                if init_response.status_code in [200, 202]:
                    init_data = init_response.json()
                    print(f"✅ Worker {worker_pid}: {init_data.get('message')}")
                    return True
                else:
                    print(f"❌ Failed to initialize worker {worker_pid}: {init_response.status_code}")
                    return False
        else:
            print(f"❌ Failed to check status: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Error communicating with server: {e}")
        return False

def main():
    """Main function"""
    print("🤖 Gen Object Single Worker Initializer")
    print("=" * 50)
    
    # Check if server is running
    try:
        response = requests.get(f"{BASE_URL}/api/health", timeout=5)
        if response.status_code != 200:
            print(f"❌ Server not responding properly: {response.status_code}")
            sys.exit(1)
        print("✅ Server is running")
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot connect to server at {BASE_URL}: {e}")
        print("💡 Make sure the Flask server is running first!")
        sys.exit(1)
    
    print(f"🌐 Server URL: {BASE_URL}")
    print("-" * 50)
    
    # Make a single request to check and potentially initialize
    success = check_and_initialize()
    
    if success:
        print("\n🎉 Operation completed successfully!")
        print("💡 To initialize more workers, run this script again.")
    else:
        print("\n⚠️  Operation failed.")
        print("💡 Check server logs for more details.")

if __name__ == "__main__":
    main()