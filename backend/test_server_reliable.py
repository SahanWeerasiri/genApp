import requests
import json
import time
from datetime import datetime

# Server configuration
BASE_URL = "http://localhost:5000"
API_BASE = f"{BASE_URL}/api"

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    PURPLE = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    END = '\033[0m'

def log(message, color=Colors.WHITE):
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"{color}[{timestamp}] {message}{Colors.END}")

def make_request(method, endpoint, data=None, headers=None, auth_token=None):
    """Make HTTP request with better error handling"""
    url = f"{API_BASE}{endpoint}"
    
    if auth_token:
        if not headers:
            headers = {}
        headers['Authorization'] = f"Bearer {auth_token}"
    
    if headers is None:
        headers = {'Content-Type': 'application/json'}
    elif 'Content-Type' not in headers:
        headers['Content-Type'] = 'application/json'
    
    try:
        # Add longer timeout and handle requests more carefully
        if method.upper() == 'GET':
            response = requests.get(url, headers=headers, timeout=30)
        elif method.upper() == 'POST':
            response = requests.post(url, json=data, headers=headers, timeout=30)
        else:
            raise ValueError(f"Unsupported HTTP method: {method}")
        
        return response
    except requests.exceptions.Timeout:
        log(f"Timeout error for {method} {endpoint}", Colors.RED)
        return None
    except requests.exceptions.ConnectionError:
        log(f"Connection error for {method} {endpoint}", Colors.RED)
        return None
    except Exception as e:
        log(f"Request error for {method} {endpoint}: {str(e)}", Colors.RED)
        return None

def test_endpoint(test_name, method, endpoint, expected_status, data=None, auth_token=None, check_response=None):
    """Test a single endpoint"""
    log(f"Testing: {test_name}", Colors.BLUE)
    
    response = make_request(method, endpoint, data, auth_token=auth_token)
    
    if response is None:
        log(f"✗ {test_name} - Request failed", Colors.RED)
        return False, None
    
    success = response.status_code == expected_status
    
    # Additional response validation if provided
    if success and check_response:
        try:
            response_data = response.json()
            success = check_response(response_data)
        except:
            success = False
    
    if success:
        log(f"✓ {test_name} - Status: {response.status_code}", Colors.GREEN)
    else:
        log(f"✗ {test_name} - Status: {response.status_code} (Expected: {expected_status})", Colors.RED)
        try:
            log(f"  Response: {response.text}", Colors.RED)
        except:
            pass
    
    return success, response

def main():
    print(f"{Colors.PURPLE + Colors.BOLD}")
    print("="*60)
    print("           Flask API Server Test Suite (Reliable)")
    print("="*60)
    print(f"{Colors.END}")
    
    # Check server connectivity first
    try:
        response = requests.get(f"{BASE_URL}/api/health", timeout=10)
        log("Server is accessible!", Colors.GREEN)
    except:
        log(f"Cannot connect to server at {BASE_URL}", Colors.RED)
        log("Please make sure the Flask server is running", Colors.YELLOW)
        return
    
    passed_tests = 0
    total_tests = 0
    
    # Store tokens
    access_token = None
    refresh_token = None
    admin_access_token = None
    timestamp = str(int(time.time()))
    
    log("Starting comprehensive API tests...", Colors.CYAN)
    time.sleep(1)  # Give server a moment
    
    # Test 1: Health Check
    success, response = test_endpoint(
        "Health Check", 
        "GET", 
        "/health", 
        200,
        check_response=lambda data: data.get('status') == 'healthy'
    )
    total_tests += 1
    if success: passed_tests += 1
    time.sleep(0.5)
    
    # Test 2: User Signup
    signup_data = {
        "email": f"testuser{timestamp}@example.com",
        "password": "testpass123",
        "name": "Test User",
        "role": "user"
    }
    
    success, response = test_endpoint(
        "User Signup",
        "POST",
        "/signup",
        201,
        data=signup_data,
        check_response=lambda data: 'access_token' in data and 'refresh_token' in data
    )
    total_tests += 1
    if success: 
        passed_tests += 1
        if response:
            try:
                data = response.json()
                access_token = data.get('access_token')
                refresh_token = data.get('refresh_token')
                log("✓ Tokens saved for further testing", Colors.CYAN)
            except:
                pass
    time.sleep(0.5)
    
    # Test 3: Duplicate Signup
    success, response = test_endpoint(
        "Duplicate User Signup",
        "POST",
        "/signup",
        409,
        data=signup_data
    )
    total_tests += 1
    if success: passed_tests += 1
    time.sleep(0.5)
    
    # Test 4: Admin Signup
    admin_signup_data = {
        "email": f"testadmin{timestamp}@example.com",
        "password": "adminpass123",
        "name": "Test Admin",
        "role": "admin"
    }
    
    success, response = test_endpoint(
        "Admin Signup",
        "POST",
        "/signup",
        201,
        data=admin_signup_data,
        check_response=lambda data: data.get('user', {}).get('role') == 'admin'
    )
    total_tests += 1
    if success: 
        passed_tests += 1
        if response:
            try:
                data = response.json()
                admin_access_token = data.get('access_token')
                log("✓ Admin token saved for testing", Colors.CYAN)
            except:
                pass
    time.sleep(0.5)
    
    # Test 5: User Signin
    signin_data = {
        "email": "user@example.com",
        "password": "user123"
    }
    
    success, response = test_endpoint(
        "User Signin",
        "POST",
        "/signin",
        200,
        data=signin_data,
        check_response=lambda data: 'access_token' in data
    )
    total_tests += 1
    if success: passed_tests += 1
    time.sleep(0.5)
    
    # Test 6: Invalid Credentials
    invalid_signin_data = {
        "email": "user@example.com",
        "password": "wrongpassword"
    }
    
    success, response = test_endpoint(
        "Invalid Credentials",
        "POST",
        "/signin",
        401,
        data=invalid_signin_data
    )
    total_tests += 1
    if success: passed_tests += 1
    time.sleep(0.5)
    
    # Test 7: Profile without token
    success, response = test_endpoint(
        "Profile - No Token",
        "GET",
        "/profile",
        401
    )
    total_tests += 1
    if success: passed_tests += 1
    time.sleep(0.5)
    
    # Test 8: Profile with valid token
    if access_token:
        success, response = test_endpoint(
            "Profile - Valid Token",
            "GET",
            "/profile",
            200,
            auth_token=access_token,
            check_response=lambda data: 'user' in data
        )
        total_tests += 1
        if success: passed_tests += 1
        time.sleep(0.5)
    
    # Test 9: User Dashboard
    if access_token:
        success, response = test_endpoint(
            "User Dashboard",
            "GET",
            "/user/dashboard",
            200,
            auth_token=access_token
        )
        total_tests += 1
        if success: passed_tests += 1
        time.sleep(0.5)
    
    # Test 10: Admin endpoint without token
    success, response = test_endpoint(
        "Admin Users - No Token",
        "GET",
        "/admin/users",
        401
    )
    total_tests += 1
    if success: passed_tests += 1
    time.sleep(0.5)
    
    # Test 11: Admin endpoint with user token
    if access_token:
        success, response = test_endpoint(
            "Admin Users - User Token",
            "GET",
            "/admin/users",
            403,
            auth_token=access_token
        )
        total_tests += 1
        if success: passed_tests += 1
        time.sleep(0.5)
    
    # Test 12: Admin endpoint with admin token
    if admin_access_token:
        success, response = test_endpoint(
            "Admin Users - Admin Token",
            "GET",
            "/admin/users",
            200,
            auth_token=admin_access_token,
            check_response=lambda data: 'users' in data and 'total' in data
        )
        total_tests += 1
        if success: passed_tests += 1
        time.sleep(0.5)
    
    # Test 13: Token refresh without token
    success, response = test_endpoint(
        "Token Refresh - No Token",
        "POST",
        "/refresh",
        400,
        data={}
    )
    total_tests += 1
    if success: passed_tests += 1
    time.sleep(0.5)
    
    # Test 14: Token refresh with valid token
    if refresh_token:
        success, response = test_endpoint(
            "Token Refresh - Valid Token",
            "POST",
            "/refresh",
            200,
            data={"refresh_token": refresh_token},
            check_response=lambda data: 'access_token' in data
        )
        total_tests += 1
        if success: passed_tests += 1
        time.sleep(0.5)
    
    # Test 15: Invalid endpoint
    success, response = test_endpoint(
        "Invalid Endpoint",
        "GET",
        "/invalid-endpoint",
        404
    )
    total_tests += 1
    if success: passed_tests += 1
    time.sleep(0.5)
    
    # Test 16: Input validation - missing password
    success, response = test_endpoint(
        "Signup - Missing Password",
        "POST",
        "/signup",
        400,
        data={"email": "test@example.com"}
    )
    total_tests += 1
    if success: passed_tests += 1
    time.sleep(0.5)
    
    # Test 17: Logout
    if access_token and refresh_token:
        success, response = test_endpoint(
            "Logout",
            "POST",
            "/logout",
            200,
            data={"refresh_token": refresh_token},
            auth_token=access_token
        )
        total_tests += 1
        if success: passed_tests += 1
    
    # Print summary
    log("\n" + "="*50, Colors.PURPLE + Colors.BOLD)
    log("TEST SUMMARY", Colors.PURPLE + Colors.BOLD)
    log("="*50, Colors.PURPLE + Colors.BOLD)
    log(f"Total Tests: {total_tests}", Colors.WHITE)
    log(f"Passed: {passed_tests}", Colors.GREEN)
    log(f"Failed: {total_tests - passed_tests}", Colors.RED)
    log(f"Success Rate: {(passed_tests/total_tests)*100:.1f}%", Colors.CYAN)
    
    if passed_tests == total_tests:
        log("🎉 All tests passed!", Colors.GREEN + Colors.BOLD)
    else:
        log(f"⚠️  {total_tests - passed_tests} test(s) failed", Colors.RED + Colors.BOLD)

if __name__ == "__main__":
    main()