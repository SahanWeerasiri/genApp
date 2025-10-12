# PM2 Cluster Setup for GenApp

This document explains how to set up and manage the GenApp cluster using PM2 for horizontal scaling.

## **Prerequisites**

- Node.js and npm installed
- Python 3.7+ with required packages
- PM2 installed globally: `npm install -g pm2`

## **Cluster Configuration**

The cluster runs 3 server instances:
- **Server 1**: Port 5001 (Worker ID: worker-1)
- **Server 2**: Port 5002 (Worker ID: worker-2) 
- **Server 3**: Port 5003 (Worker ID: worker-3)

Each server has:
- **Gen Pool Size**: 3 AI model instances
- **Auto-restart**: Enabled
- **Memory limit**: 1GB per instance
- **Logging**: Individual log files per server

## **Management Commands**

### **Start Cluster**
```bash
# Linux/Mac
./start_cluster.sh

# Windows
start_cluster.bat

# Or directly with PM2
pm2 start ecosystem.config.js
```

### **Stop Cluster**
```bash
# Linux/Mac
./stop_cluster.sh

# Windows  
stop_cluster.bat

# Or directly with PM2
pm2 stop ecosystem.config.js
pm2 delete ecosystem.config.js
```

### **Monitor Cluster**
```bash
# View status
pm2 status

# Monitor in real-time
pm2 monit

# View logs
pm2 logs

# View logs for specific server
pm2 logs genapp-server-1
```

### **Restart Individual Servers**
```bash
# Restart single server
pm2 restart genapp-server-1

# Restart all servers
pm2 restart ecosystem.config.js

# Reload with zero downtime
pm2 reload ecosystem.config.js
```

## **Health Monitoring**

### **Individual Server Health**
```bash
# Check each server
curl http://localhost:5001/api/health
curl http://localhost:5002/api/health
curl http://localhost:5003/api/health
```

### **Generate Health Check**
```bash
# Test image generation queue
curl http://localhost:5001/api/health-generate
curl http://localhost:5002/api/health-generate
curl http://localhost:5003/api/health-generate
```

### **Response Format**
```json
{
  "status": "healthy",
  "worker_id": "worker-1",
  "port": 5001,
  "gen_pool_size": 3,
  "active_jobs": 0,
  "available_workers": 3,
  "timestamp": "2025-10-12T10:30:00.000Z"
}
```

## **Load Balancing**

### **Option 1: Application-Level (Simple)**
The mobile app can rotate between servers:
```dart
List<String> servers = [
  'http://your-server:5001',
  'http://your-server:5002', 
  'http://your-server:5003'
];

String getNextServer() {
  // Simple round-robin
  return servers[currentIndex++ % servers.length];
}
```

### **Option 2: Nginx Load Balancer (Recommended)**
```nginx
upstream genapp_backend {
    server 127.0.0.1:5001;
    server 127.0.0.1:5002;
    server 127.0.0.1:5003;
}

server {
    listen 80;
    location / {
        proxy_pass http://genapp_backend;
    }
}
```

## **Log Management**

### **Log Locations**
- **Server 1**: `./logs/genapp-server-1*.log`
- **Server 2**: `./logs/genapp-server-2*.log`
- **Server 3**: `./logs/genapp-server-3*.log`

### **Log Commands**
```bash
# View all logs
pm2 logs

# View specific server logs  
pm2 logs genapp-server-1

# Clear logs
pm2 flush

# Rotate logs
pm2 reloadLogs
```

## **Scaling**

### **Add More Servers**
1. Edit `ecosystem.config.js`
2. Add new server configuration:
```javascript
{
  name: 'genapp-server-4',
  script: 'python',
  args: 'server.py',
  cwd: './backend',
  env: {
    PORT: 5004,
    WORKER_ID: 'worker-4',
    GEN_POOL_SIZE: 3
  }
}
```
3. Restart cluster: `pm2 reload ecosystem.config.js`

### **Adjust Resources**
Edit `ecosystem.config.js` to change:
- `GEN_POOL_SIZE`: Number of AI models per server
- `max_memory_restart`: Memory limit before restart
- `instances`: PM2 cluster mode (keep at 1 for our setup)

## **Troubleshooting**

### **Server Won't Start**
```bash
# Check PM2 logs
pm2 logs genapp-server-1

# Check if port is in use
netstat -tlnp | grep 5001

# Manual start for debugging
cd backend
PORT=5001 WORKER_ID=worker-1 python server.py
```

### **High Memory Usage**
```bash
# Check memory usage
pm2 monit

# Restart high-memory servers
pm2 restart genapp-server-1

# Reduce GEN_POOL_SIZE in ecosystem.config.js
```

### **Load Balancing Issues**
```bash
# Test each server individually
for port in 5001 5002 5003; do
  curl http://localhost:$port/api/health
done

# Check nginx configuration (if using)
nginx -t
```

## **GitHub Actions Integration**

The health check workflow automatically:
1. Tests all 3 server instances
2. Checks health-generate endpoints
3. Monitors load distribution
4. Reports worker information

Configure these secrets in GitHub:
- `SERVER_URL`: Your server base URL (e.g., `http://68.233.117.166`)
- `LOAD_BALANCER_URL`: Load balancer URL (if using nginx)

## **Performance Optimization**

### **Recommended Configuration**
- **3 servers**: Good balance of redundancy and resource usage
- **3 Gen pools per server**: 9 total AI model instances
- **1GB memory limit**: Prevents runaway processes
- **Auto-restart**: Handles crashes gracefully

### **Monitoring Metrics**
- **Queue Size**: Should remain low during normal operation
- **Available Workers**: Should match Gen pool size when idle
- **Memory Usage**: Monitor with `pm2 monit`
- **Response Times**: Check with health endpoints

This PM2 setup provides true horizontal scaling with:
✅ **Load Distribution**: Requests spread across multiple servers
✅ **High Availability**: Servers can fail without total outage  
✅ **Easy Management**: Simple start/stop/monitor commands
✅ **Automatic Recovery**: PM2 restarts failed processes
✅ **Resource Control**: Memory limits and pool configuration