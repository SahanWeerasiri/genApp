#!/usr/bin/env python3
"""
Script to initialize Gen objects across all workers.
This script calls the initialization endpoints to ensure all workers have their Gen objects ready.
"""

import requests
import time
import os
import sys

# Configuration
BASE_URL = "http://localhost:5000"
WORKERS = int(os.getenv('WORKERS', 1))  # Number of workers
MAX_RETRIES = 30  # Maximum number of status checks
RETRY_INTERVAL = 2  # Seconds between status checks

def check_gen_status():
    """Check the Gen object status"""
    try:
        response = requests.get(f"{BASE_URL}/api/gen-status", timeout=10)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"❌ Failed to check status: {response.status_code}")
            return None
    except requests.exceptions.RequestException as e:
        print(f"❌ Error checking status: {e}")
        return None

def initialize_gen():
    """Initialize Gen object"""
    try:
        response = requests.post(f"{BASE_URL}/api/initialize-gen", timeout=10)
        if response.status_code in [200, 202]:
            return response.json()
        else:
            print(f"❌ Failed to initialize: {response.status_code}")
            return None
    except requests.exceptions.RequestException as e:
        print(f"❌ Error initializing: {e}")
        return None

def wait_for_initialization():
    """Wait for Gen object to be initialized"""
    print("🔄 Waiting for Gen object initialization...")
    
    for attempt in range(MAX_RETRIES):
        status_result = check_gen_status()
        
        if status_result:
            status = status_result.get('status')
            worker_pid = status_result.get('worker_pid')
            message = status_result.get('message')
            
            print(f"📊 Worker {worker_pid}: {status} - {message}")
            
            if status == "initialized":
                print(f"✅ Worker {worker_pid}: Gen object initialized successfully!")
                return True
            elif status == "pending":
                print(f"⏳ Worker {worker_pid}: Initialization in progress...")
            elif status == "none":
                print(f"❌ Worker {worker_pid}: Not initialized, starting initialization...")
                init_result = initialize_gen()
                if init_result:
                    print(f"🚀 Worker {worker_pid}: Initialization started")
        
        if attempt < MAX_RETRIES - 1:
            print(f"⏱️  Waiting {RETRY_INTERVAL} seconds... (Attempt {attempt + 1}/{MAX_RETRIES})")
            time.sleep(RETRY_INTERVAL)
    
    print(f"❌ Timeout: Gen object not initialized after {MAX_RETRIES * RETRY_INTERVAL} seconds")
    return False

def initialize_all_workers():
    """Initialize Gen objects for all workers by making multiple requests"""
    print(f"🚀 Initializing Gen objects for {WORKERS} workers...")
    print(f"🌐 Server URL: {BASE_URL}")
    print("-" * 50)
    
    initialized_workers = set()
    
    # Make multiple requests to hit different workers
    for round_num in range(3):  # Multiple rounds to ensure we hit all workers
        print(f"\n🔄 Round {round_num + 1}: Making requests to hit different workers...")
        
        for request_num in range(WORKERS * 2):  # More requests than workers to ensure coverage
            print(f"📡 Request {request_num + 1}: ", end="")
            
            # Check status first
            status_result = check_gen_status()
            if status_result:
                worker_pid = status_result.get('worker_pid')
                status = status_result.get('status')
                
                if worker_pid not in initialized_workers:
                    if status == "none":
                        # Initialize this worker
                        init_result = initialize_gen()
                        if init_result:
                            print(f"🚀 Started initialization for worker {worker_pid}")
                        else:
                            print(f"❌ Failed to start initialization for worker {worker_pid}")
                    elif status == "pending":
                        print(f"⏳ Worker {worker_pid} already initializing")
                    elif status == "initialized":
                        print(f"✅ Worker {worker_pid} already initialized")
                        initialized_workers.add(worker_pid)
                else:
                    print(f"✅ Worker {worker_pid} already tracked")
            
            time.sleep(0.5)  # Small delay between requests
    
    print(f"\n📊 Found {len(initialized_workers)} unique workers")
    print("-" * 50)
    
    # Wait for all initializations to complete
    print("\n⏳ Waiting for all initializations to complete...")
    max_wait_time = 120  # 2 minutes total
    start_time = time.time()
    
    while time.time() - start_time < max_wait_time:
        all_initialized = True
        
        # Check status of multiple workers by making several requests
        for _ in range(WORKERS * 2):
            status_result = check_gen_status()
            if status_result:
                status = status_result.get('status')
                worker_pid = status_result.get('worker_pid')
                
                if status != "initialized":
                    all_initialized = False
                    print(f"⏳ Worker {worker_pid}: Still {status}")
                else:
                    print(f"✅ Worker {worker_pid}: Ready")
            
            time.sleep(0.2)
        
        if all_initialized:
            print("\n🎉 All workers have been initialized successfully!")
            return True
        
        print(f"⏱️  Continuing to wait... ({int(time.time() - start_time)}s elapsed)")
        time.sleep(2)
    
    print(f"\n⚠️  Initialization completed with timeout after {max_wait_time} seconds")
    return False

def main():
    """Main function"""
    print("🤖 Gen Object Worker Initializer")
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
    
    # Initialize all workers
    success = initialize_all_workers()
    
    if success:
        print("\n🎉 Initialization completed successfully!")
        print("💡 Your Gen objects are now ready for image generation.")
    else:
        print("\n⚠️  Initialization completed with some issues.")
        print("💡 Some workers might still be initializing. Check server logs.")
    
    print("\n🔍 Final status check:")
    for _ in range(WORKERS):
        status_result = check_gen_status()
        if status_result:
            worker_pid = status_result.get('worker_pid')
            status = status_result.get('status')
            message = status_result.get('message')
            print(f"   Worker {worker_pid}: {status} - {message}")
        time.sleep(0.1)

if __name__ == "__main__":
    main()