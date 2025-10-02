# Image Generation App with Token System

This application implements a token-based image generation system with Firebase/Firestore integration.

## Features Implemented

### 1. User Profile Creation
- When users sign up/sign in, a profile is automatically created in Firestore
- Initial token count: 5 tokens per user
- Profile includes: UID, email, name, photo URL, token count, timestamps

### 2. Token Display in Profile
- Profile page fetches and displays current token count from Firestore
- Real-time updates when tokens are consumed or added

### 3. Token-Based Image Generation
- Backend validates token availability before generating images
- Consumes 1 token per successful image generation
- Returns appropriate error messages when tokens are insufficient

## Backend Setup

### Option 1: With Firestore (Recommended for Production)

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project
   - Enable Firestore Database

2. **Get Configuration**
   - Go to Project Settings → General
   - Copy your Project ID
   - Copy your Web API Key

3. **Configure Backend**
   ```bash
   cd backend
   cp .env.example .env
   ```
   
   Edit `.env` file:
   ```
   FIREBASE_PROJECT_ID=your-actual-project-id
   FIREBASE_API_KEY=your-actual-api-key
   ```

4. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

5. **Run Server**
   ```bash
   python server.py
   ```

### Option 2: Without Firestore (Development/Testing)

The backend includes a fallback in-memory token store that works without any Firebase configuration.

1. **Install Dependencies**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

2. **Run Server**
   ```bash
   python server.py
   ```

The server will automatically use the in-memory store if Firestore is not configured.

## Frontend Setup

1. **Install Dependencies**
   ```bash
   cd frontend/free_image_genie
   flutter pub get
   ```

2. **Firebase Configuration**
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Or use the existing demo configuration

3. **Run App**
   ```bash
   flutter run
   ```

## API Endpoints

### Token Management
- `GET /api/user/tokens/{userId}` - Get user's token count
- `GET /api/user/profile/{userId}` - Get user's full profile
- `POST /api/user/tokens/{userId}/add` - Add tokens to user account

### Image Generation
- `POST /api/generate` - Generate image with token validation
  ```json
  {
    "prompt": "a beautiful sunset",
    "style": "Painted Anime",
    "userId": "user_id_here"
  }
  ```

### Utility
- `GET /api/health` - Health check

## Testing

Test the token system:
```bash
cd backend
python test_token_system.py
```

## Architecture

### Frontend (Flutter)
- `UserProfileProvider` - Manages user profile and tokens
- `AuthProvider` - Handles authentication and profile creation
- `ImageProvider` - Manages image generation with token validation
- `FirestoreService` - Direct Firestore communication
- `ApiService` - Backend API communication

### Backend (Python/Flask)
- `FirestoreService` - Firestore REST API integration
- `InMemoryTokenStore` - Fallback token storage
- Token validation before image generation
- Automatic token consumption on successful generation

## Error Handling

- **Insufficient Tokens**: Returns 402 (Payment Required) with appropriate message
- **Firestore Unavailable**: Falls back to in-memory storage
- **Network Issues**: Graceful degradation with user-friendly messages

## Security Notes

For production:
1. Use proper Firebase service account credentials
2. Implement proper authentication middleware
3. Add rate limiting
4. Validate user tokens on backend
5. Use HTTPS for all communications

## Troubleshooting

### Common Issues

1. **Firestore not working**: Check your project ID and API key in `.env`
2. **CORS errors**: Ensure Flask-CORS is properly configured
3. **Network timeouts**: Adjust timeout values for image generation
4. **Token sync issues**: Profile page automatically refreshes token count

### Debug Mode

The backend logs all token operations for debugging:
- Token availability checks
- Token consumption
- Firestore fallback usage
- API request/response details