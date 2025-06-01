#!/bin/bash
# Minimal nginx fix to get it running

cd /home/arifjan/dot-bc

echo "Creating minimal nginx configuration..."

# Create the most basic nginx.conf that will work
cat > nginx/nginx.conf << 'EOF'
user nginx;
worker_processes 1;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format json_combined escape=json '{'
        '"time_local":"$time_local",'
        '"remote_addr":"$remote_addr",'
        '"request":"$request",'
        '"status":"$status",'
        '"body_bytes_sent":"$body_bytes_sent",'
        '"request_time":"$request_time",'
        '"http_user_agent":"$http_user_agent",'
        '"request_uri":"$request_uri",'
        '"request_method":"$request_method"'
    '}';
    
    access_log /var/log/nginx/access.log json_combined;
    
    server {
        listen 80;
        server_name _;
        
        location / {
            proxy_pass http://app:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        location /health {
            access_log off;
            return 200 "OK\n";
        }
    }
}
EOF

# Also create a minimal conf.d/default.conf
mkdir -p nginx/conf.d
cat > nginx/conf.d/default.conf << 'EOF'
# Minimal configuration - everything is in nginx.conf
EOF

echo "Restarting nginx container..."
docker restart nginx_logging

sleep 5

# Check if it's running
if docker ps | grep -q nginx_logging; then
    echo "✅ Nginx is now running!"
    
    # Test it
    echo "Testing nginx..."
    curl -s http://localhost/health && echo "✅ Nginx is responding!"
else
    echo "❌ Nginx still failing. Checking logs..."
    docker logs --tail 20 nginx_logging
fi
