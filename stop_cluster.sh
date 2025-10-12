#!/bin/bash

echo "🛑 Stopping GenApp cluster..."

# Stop all processes
pm2 stop ecosystem.config.js

# Delete processes from PM2 list
pm2 delete ecosystem.config.js

echo "✅ GenApp cluster stopped successfully!"

# Show final status
pm2 status