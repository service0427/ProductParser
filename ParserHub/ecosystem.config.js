module.exports = {
  apps: [{
    name: 'parser-hub',
    script: './dist/index.js',
    instances: 4,
    exec_mode: 'cluster',
    watch: false,
    env: {
      NODE_ENV: 'production',
      PORT: 8888
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_file: './logs/pm2-combined.log',
    time: true,
    max_memory_restart: '1G',
    kill_timeout: 5000,
    wait_ready: true,
    listen_timeout: 50000
  }]
}