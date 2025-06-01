#!/bin/bash
# Script to fix deployment issues and redeploy the monitoring stack

set -e

echo "==================================="
echo "Fixing deployment issues..."
echo "==================================="

# Stop existing containers
echo "Stopping existing containers..."
docker-compose -f docker-compose.logging.yml down

# Create necessary directories if they don't exist
echo "Creating directory structure..."
mkdir -p nginx/{conf.d,ssl} logstash/{config,pipeline,templates} filebeat elastalert/{rules,config} kibana/dashboards

# Copy fixed nginx.conf
echo "Fixing nginx configuration..."
cat > nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # JSON формат для удобного парсинга
    log_format json_analytics escape=json '{'
        '"time_local":"$time_local",'
        '"remote_addr":"$remote_addr",'
        '"remote_user":"$remote_user",'
        '"request":"$request",'
        '"status":"$status",'
        '"body_bytes_sent":"$body_bytes_sent",'
        '"request_time":"$request_time",'
        '"http_referrer":"$http_referer",'
        '"http_user_agent":"$http_user_agent",'
        '"http_x_forwarded_for":"$http_x_forwarded_for",'
        '"request_method":"$request_method",'
        '"request_uri":"$request_uri",'
        '"server_protocol":"$server_protocol",'
        '"ssl_protocol":"$ssl_protocol",'
        '"ssl_cipher":"$ssl_cipher",'
        '"upstream_addr":"$upstream_addr",'
        '"upstream_status":"$upstream_status",'
        '"upstream_response_time":"$upstream_response_time",'
        '"gzip_ratio":"$gzip_ratio"'
    '}';

    access_log /var/log/nginx/access.log json_analytics;

    # Настройки безопасности
    client_body_buffer_size 16K;
    client_header_buffer_size 1k;
    client_max_body_size 1M;
    large_client_header_buffers 4 8k;
    
    # Timeout настройки
    client_body_timeout 10;
    client_header_timeout 10;
    keepalive_timeout 5 5;
    send_timeout 10;

    # Скрытие версии сервера
    server_tokens off;

    # Защита от clickjacking
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Rate limiting зоны
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=2r/s;
    
    # Зона для отслеживания подозрительных запросов
    limit_req_zone $binary_remote_addr zone=suspicious:10m rate=1r/s;

    # Map для определения подозрительных User-Agent
    map $http_user_agent $suspicious_agent {
        default 0;
        ~*bot 1;
        ~*crawler 1;
        ~*spider 1;
        ~*scanner 1;
        ~*sqlmap 1;
        ~*nikto 1;
        ~*masscan 1;
        ~*wpscan 1;
        "" 1;
    }

    # Map для обнаружения SQL injection
    map $request_uri $sql_injection {
        default 0;
        ~*union.*select 1;
        ~*select.*from 1;
        ~*insert.*into 1;
        ~*delete.*from 1;
        ~*drop.*table 1;
        ~*update.*set 1;
        ~*benchmark\( 1;
        ~*\' 1;
        ~*\" 1;
        ~*\; 1;
        ~*-- 1;
    }

    # Map для обнаружения XSS
    map $request_uri $xss_attack {
        default 0;
        ~*<script 1;
        ~*javascript: 1;
        ~*onerror= 1;
        ~*onload= 1;
        ~*onclick= 1;
        ~*<iframe 1;
        ~*<object 1;
        ~*<embed 1;
    }

    # Переменная для логирования подозрительной активности
    set $log_suspicious "";

    include /etc/nginx/conf.d/*.conf;
}
EOF

# Create fixed default.conf without geoip references
echo "Creating nginx default.conf..."
cat > nginx/conf.d/default.conf << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Логирование на уровне сервера
    access_log /var/log/nginx/app_access.log json_analytics;
    error_log /var/log/nginx/app_error.log warn;

    # Корневая директория
    root /usr/share/nginx/html;
    index index.html index.htm;

    # Блокировка подозрительных User-Agent
    if ($suspicious_agent) {
        set $log_suspicious "${log_suspicious}UA;";
        return 403;
    }

    # Блокировка SQL injection
    if ($sql_injection) {
        set $log_suspicious "${log_suspicious}SQL;";
        return 403;
    }

    # Блокировка XSS атак
    if ($xss_attack) {
        set $log_suspicious "${log_suspicious}XSS;";
        return 403;
    }

    # Основной location для приложения
    location / {
        # Rate limiting
        limit_req zone=general burst=20 nodelay;
        
        proxy_pass http://app:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Дополнительные заголовки для безопасности
        proxy_hide_header X-Powered-By;
        proxy_hide_header Server;
        
        # Логирование тела запроса для подозрительных запросов
        if ($log_suspicious) {
            access_log /var/log/nginx/suspicious.log json_analytics;
        }
    }

    # API endpoints с более строгим rate limiting
    location /api/ {
        limit_req zone=api burst=10 nodelay;
        
        proxy_pass http://app:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Блокировка доступа к чувствительным файлам
    location ~ /\. {
        deny all;
        access_log /var/log/nginx/denied.log json_analytics;
    }

    location ~ /\.git {
        deny all;
        access_log /var/log/nginx/denied.log json_analytics;
    }

    location ~ /\.env {
        deny all;
        access_log /var/log/nginx/denied.log json_analytics;
    }

    # Блокировка доступа к конфигурационным файлам
    location ~ \.(ini|log|conf)$ {
        deny all;
        access_log /var/log/nginx/denied.log json_analytics;
    }

    # Обработка ошибок
    error_page 403 /403.html;
    location = /403.html {
        root /usr/share/nginx/html;
        internal;
    }

    error_page 404 /404.html;
    location = /404.html {
        root /usr/share/nginx/html;
        internal;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
        internal;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Статистика Nginx (только для локальных запросов)
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow 172.16.0.0/12;
        deny all;
    }
}
EOF

# Fix Logstash pipeline configuration
echo "Fixing Logstash pipeline configuration..."
mkdir -p logstash/pipeline
cat > logstash/pipeline/logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
}

filter {
  # Обработка Nginx access логов
  if [log_type] == "nginx_access" {
    # Парсинг JSON логов от Nginx
    json {
      source => "message"
      target => "nginx"
    }
    
    # Перемещение полей из nginx в корень документа
    mutate {
      rename => {
        "[nginx][time_local]" => "time_local"
        "[nginx][remote_addr]" => "remote_addr"
        "[nginx][request]" => "request"
        "[nginx][status]" => "status"
        "[nginx][body_bytes_sent]" => "body_bytes_sent"
        "[nginx][request_time]" => "request_time"
        "[nginx][http_user_agent]" => "http_user_agent"
        "[nginx][request_uri]" => "request_uri"
        "[nginx][request_method]" => "request_method"
      }
    }

    # Парсинг User-Agent
    if [http_user_agent] {
      useragent {
        source => "http_user_agent"
        target => "user_agent"
      }
    }

    # Определение типа атаки
    if [request_uri] {
      # SQL Injection detection
      if [request_uri] =~ /union.*select|select.*from|insert.*into|delete.*from|drop.*table|update.*set|benchmark\(|'|"|;|--/ {
        mutate {
          add_tag => [ "sql_injection", "security_alert" ]
          add_field => { "attack_type" => "SQL Injection" }
          add_field => { "severity" => "high" }
        }
      }

      # XSS detection
      if [request_uri] =~ /<script|javascript:|onerror=|onload=|onclick=|<iframe|<object|<embed/ {
        mutate {
          add_tag => [ "xss_attack", "security_alert" ]
          add_field => { "attack_type" => "XSS" }
          add_field => { "severity" => "high" }
        }
      }

      # Path traversal detection
      if [request_uri] =~ /\.\.\/|\.\.\\/ {
        mutate {
          add_tag => [ "path_traversal", "security_alert" ]
          add_field => { "attack_type" => "Path Traversal" }
          add_field => { "severity" => "medium" }
        }
      }
    }

    # Обнаружение подозрительных User-Agent
    if [http_user_agent] {
      if [http_user_agent] =~ /bot|crawler|spider|scanner|sqlmap|nikto|masscan|wpscan|nmap|^$|^-$/ {
        mutate {
          add_tag => [ "suspicious_user_agent", "security_alert" ]
          add_field => { "alert_reason" => "Suspicious User-Agent detected" }
        }
      }
    }

    # Преобразование типов данных
    mutate {
      convert => {
        "status" => "integer"
        "body_bytes_sent" => "integer"
        "request_time" => "float"
      }
    }

    # Добавление категории статуса
    if [status] {
      if [status] >= 200 and [status] < 300 {
        mutate { add_field => { "status_category" => "success" } }
      } else if [status] >= 300 and [status] < 400 {
        mutate { add_field => { "status_category" => "redirect" } }
      } else if [status] >= 400 and [status] < 500 {
        mutate { add_field => { "status_category" => "client_error" } }
        if [status] == 403 or [status] == 404 {
          mutate { add_tag => [ "potential_scanner" ] }
        }
      } else if [status] >= 500 {
        mutate { add_field => { "status_category" => "server_error" } }
      }
    }
  }

  # Добавление временной метки
  if [time_local] {
    date {
      match => [ "time_local", "dd/MMM/yyyy:HH:mm:ss Z" ]
      target => "@timestamp"
    }
  }
}

output {
  # Вывод в Elasticsearch
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "nginx-%{+YYYY.MM.dd}"
  }

  # Отправка критических алертов в отдельный индекс
  if "security_alert" in [tags] {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "security-alerts-%{+YYYY.MM.dd}"
    }
  }

  # Для отладки
  stdout { 
    codec => rubydebug 
  }
}
EOF

# Create error pages
echo "Creating error pages..."
cat > nginx/403.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>403 Forbidden</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #d32f2f; }
    </style>
</head>
<body>
    <h1>403 Forbidden</h1>
    <p>Access to this resource is denied.</p>
    <p>Your request has been logged and will be reviewed.</p>
</body>
</html>
EOF

cat > nginx/404.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>404 Not Found</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #f57c00; }
    </style>
</head>
<body>
    <h1>404 Not Found</h1>
    <p>The requested resource was not found on this server.</p>
</body>
</html>
EOF

cat > nginx/50x.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Server Error</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #d32f2f; }
    </style>
</head>
<body>
    <h1>Internal Server Error</h1>
    <p>The server encountered an error and could not complete your request.</p>
    <p>Please try again later.</p>
</body>
</html>
EOF

# Fix docker-compose.logging.yml to properly mount SMTP auth file
echo "Updating docker-compose file..."
cat > docker-compose.logging-fixed.yml << 'EOF'
# ELK Stack для сбора и анализа логов
version: '3.8'

services:
  # Elasticsearch - хранилище логов
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.3
    container_name: elasticsearch
    environment:
      - node.name=elasticsearch
      - cluster.name=es-docker-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
      - xpack.security.enrollment.enabled=false
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
      - "9300:9300"
    networks:
      - logging_net
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Logstash - обработка логов
  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.3
    container_name: logstash
    volumes:
      - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
      - ./logstash/templates:/usr/share/logstash/templates:ro
    ports:
      - "5044:5044"
      - "5000:5000/tcp"
      - "5000:5000/udp"
      - "9600:9600"
    environment:
      LS_JAVA_OPTS: "-Xmx512m -Xms512m"
    networks:
      - logging_net
    depends_on:
      elasticsearch:
        condition: service_healthy

  # Kibana - визуализация
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.3
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_URL: http://elasticsearch:9200
      ELASTICSEARCH_HOSTS: '["http://elasticsearch:9200"]'
    networks:
      - logging_net
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Filebeat - сбор логов
  filebeat:
    image: docker.elastic.co/beats/filebeat:8.11.3
    container_name: filebeat
    user: root
    volumes:
      - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - nginx_logs:/var/log/nginx:ro
      - app_logs:/var/log/app:ro
    networks:
      - logging_net
    depends_on:
      logstash:
        condition: service_started
    command: filebeat -e -strict.perms=false

  # Nginx с настроенным логированием
  nginx:
    image: nginx:alpine
    container_name: nginx_logging
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - nginx_logs:/var/log/nginx
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./nginx/403.html:/usr/share/nginx/html/403.html:ro
      - ./nginx/404.html:/usr/share/nginx/html/404.html:ro
      - ./nginx/50x.html:/usr/share/nginx/html/50x.html:ro
    networks:
      - logging_net
      - app_net
    depends_on:
      - app

  # Flask приложение
  app:
    build: .
    container_name: book_catalog_app
    environment:
      FLASK_CONFIG: production
      PYTHONUNBUFFERED: 1
    volumes:
      - app_logs:/var/log/app
    networks:
      - app_net
    expose:
      - "5000"

  # ElastAlert2 для уведомлений
  elastalert:
    image: ghcr.io/jertel/elastalert2/elastalert2:latest
    container_name: elastalert
    volumes:
      - ./elastalert/config.yaml:/opt/elastalert/config.yaml:ro
      - ./elastalert/rules:/opt/elastalert/rules:ro
      - ./elastalert/smtp_auth.yaml:/opt/elastalert/smtp_auth.yaml:ro
    networks:
      - logging_net
    depends_on:
      elasticsearch:
        condition: service_healthy

  # Redis для кеширования и rate limiting
  redis:
    image: redis:alpine
    container_name: redis_logging
    ports:
      - "6379:6379"
    networks:
      - app_net
    volumes:
      - redis_data:/data

volumes:
  elasticsearch_data:
  nginx_logs:
  app_logs:
  redis_data:

networks:
  logging_net:
    driver: bridge
  app_net:
    driver: bridge
EOF

# Start the stack with the fixed configuration
echo "Starting the monitoring stack..."
docker-compose -f docker-compose.logging-fixed.yml up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 30

# Create Kibana dashboards
echo "Creating Kibana dashboards..."
./scripts/create_kibana_dashboards.sh

echo "==================================="
echo "Deployment fixed!"
echo "==================================="
echo ""
echo "Services available at:"
echo "- Kibana: http://localhost:5601"
echo "- Elasticsearch: http://localhost:9200"
echo "- Application: http://localhost"
echo ""
echo "Next steps:"
echo "1. Generate anomalies: python3 scripts/generate_anomalies.py"
echo "2. Check Kibana dashboards"
echo "3. Deploy Wazuh: ./scripts/deploy_wazuh.sh"
