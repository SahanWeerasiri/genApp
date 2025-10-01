import requests
import base64

BASE_URL = "http://localhost:5000/api"
LOGIN_ENDPOINT = f"{BASE_URL}/signin"
GENERATE_ENDPOINT = f"{BASE_URL}/generate"

# Dummy user credentials
USER_EMAIL = "user@example.com"
USER_PASSWORD = "user123"

# Prompt for image generation
test_prompt = "A futuristic city skyline at sunset"
test_style = "Painted Anime"

# Step 1: Login and get access token
def login(email, password):
    resp = requests.post(LOGIN_ENDPOINT, json={"email": email, "password": password})
    if resp.status_code == 200:
        data = resp.json()
        return data.get("access_token")
    print(f"Login failed: {resp.status_code} {resp.text}")
    return None

# Step 2: Send prompt to generate image
def generate_image(token, prompt, style="Painted Anime"):
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.post(GENERATE_ENDPOINT, json={"prompt": prompt, "style": style}, headers=headers)
    if resp.status_code == 200:
        data = resp.json()
        return data.get("image")
    print(f"Image generation failed: {resp.status_code} {resp.text}")
    return None

# Step 3: Save image from base64 string
def save_image(image_b64, filename="generated_image.png"):
    try:
        with open(filename, "wb") as f:
            f.write(base64.b64decode(image_b64))
        print(f"Image saved as {filename}")
    except Exception as e:
        print(f"Failed to save image: {e}")

if __name__ == "__main__":
    print("Logging in...")
    token = login(USER_EMAIL, USER_PASSWORD)
    if not token:
        exit(1)
    print("Generating image...")
    image_b64 = generate_image(token, test_prompt, test_style)
    if image_b64:
        save_image(image_b64)
    else:
        print("No image returned.")
