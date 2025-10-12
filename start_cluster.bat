@echo off

echo 🚀 Starting GenApp cluster with PM2...

:: Create logs directory if it doesn't exist
if not exist logs mkdir logs

:: Start all server instances
pm2 start ecosystem.config.js

:: Display status
echo.
echo 📊 PM2 Status:
pm2 status

echo.
echo 🎯 Cluster Information:
echo - Server 1: http://localhost:5001
echo - Server 2: http://localhost:5002
echo - Server 3: http://localhost:5003
echo.
echo 📋 Useful Commands:
echo - View logs: pm2 logs
echo - Stop cluster: pm2 stop ecosystem.config.js
echo - Restart cluster: pm2 restart ecosystem.config.js
echo - Monitor: pm2 monit
echo.
echo ✅ GenApp cluster started successfully!