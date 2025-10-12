# Server Health Check System

This project includes an automated health check system to keep the backend server active and prevent it from going to sleep.

## Health Check Endpoints

### `/api/health-generate` (Primary Health Check)
- **Purpose**: Submits an image generation job to keep the AI model and generation system warm
- **Method**: GET or POST
- **Prompt**: "lovely couple with painted anime style"
- **Style**: anime
- **Response**: Returns status and queue information
- **No Authentication Required**: This endpoint is public for monitoring

### `/api/health` (Basic Health Check)
- **Purpose**: Simple health check without resource-intensive operations
- **Method**: GET
- **Response**: Returns basic server status and timestamp

## GitHub Actions Workflow

### Schedule
- **Frequency**: Twice daily (6 AM and 6 PM UTC)
- **Cron**: `0 6,18 * * *`
- **Manual Trigger**: Available via workflow_dispatch

### Configuration
1. Set `SERVER_URL` as a repository secret (optional)
2. If not set, defaults to `http://68.233.117.166:5000`

### Workflow Steps
1. **Health Generate Check**: Calls `/api/health-generate` to submit image generation job
2. **Basic Health Check**: Calls `/api/health` for basic server status
3. **Logging**: Reports success/failure status

## Benefits

1. **Prevents Server Sleep**: Regular API calls keep hosting services active
2. **Model Warmup**: Image generation jobs keep AI models loaded in memory
3. **Early Detection**: Identifies server issues before users encounter them
4. **Resource Optimization**: Maintains optimal performance by preventing cold starts

## Monitoring

Check the **Actions** tab in GitHub to monitor health check results:
- ✅ Green checkmarks indicate successful health checks
- ❌ Red X marks indicate failed health checks requiring attention

## Local Testing

Test the health check endpoints locally:

```bash
# Health check with image generation
curl -X GET http://localhost:5000/api/health-generate

# Basic health check
curl -X GET http://localhost:5000/api/health
```

## Server Configuration

Make sure your server:
1. Has the health check endpoints enabled
2. Is accessible from the internet (for GitHub Actions)
3. Has proper error handling and logging
4. Maintains the image generation queue system