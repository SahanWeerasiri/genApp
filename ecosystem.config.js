module.exports = {
    apps: [
        {
            name: 'genapp-server-1',
            script: 'python',
            args: 'server.py',
            cwd: './backend',
            instances: 1,
            autorestart: true,
            watch: false,
            max_memory_restart: '1G',
            env: {
                PORT: 5001,
                WORKER_ID: 'worker-1',
                GEN_POOL_SIZE: 3,
                FLASK_ENV: 'production'
            },
            error_file: './logs/genapp-server-1-error.log',
            out_file: './logs/genapp-server-1-out.log',
            log_file: './logs/genapp-server-1.log',
            time: true
        },
        {
            name: 'genapp-server-2',
            script: 'python',
            args: 'server.py',
            cwd: './backend',
            instances: 1,
            autorestart: true,
            watch: false,
            max_memory_restart: '1G',
            env: {
                PORT: 5002,
                WORKER_ID: 'worker-2',
                GEN_POOL_SIZE: 3,
                FLASK_ENV: 'production'
            },
            error_file: './logs/genapp-server-2-error.log',
            out_file: './logs/genapp-server-2-out.log',
            log_file: './logs/genapp-server-2.log',
            time: true
        },
        {
            name: 'genapp-server-3',
            script: 'python',
            args: 'server.py',
            cwd: './backend',
            instances: 1,
            autorestart: true,
            watch: false,
            max_memory_restart: '1G',
            env: {
                PORT: 5003,
                WORKER_ID: 'worker-3',
                GEN_POOL_SIZE: 3,
                FLASK_ENV: 'production'
            },
            error_file: './logs/genapp-server-3-error.log',
            out_file: './logs/genapp-server-3-out.log',
            log_file: './logs/genapp-server-3.log',
            time: true
        }
    ]
};