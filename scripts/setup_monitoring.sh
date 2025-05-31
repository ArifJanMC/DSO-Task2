#!/bin/bash
# Script to setup and deploy the complete monitoring stack

set -e

echo "==================================="
echo "Setting up monitoring stack..."
echo "==================================="

# Create necessary directories
echo "Creating directory structure..."
mkdir -p {nginx/{conf.d,ssl},logstash/{config,pipeline,templates},filebeat,elastalert/{rules,config},wazuh/{config/{agent,wazuh_cluster,wazuh_indexer,wazuh_dashboard},certs},scripts,kibana/dashboards}

# Generate self-signed certificates for testing (replace with real certs in production)
echo "Generating SSL certificates..."
if [ ! -f nginx/ssl/nginx.crt ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout nginx/ssl/nginx.key \
        -out nginx/ssl/nginx.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
fi

# Create Elasticsearch template
cat > logstash/templates/nginx-template.json << 'EOF'
{
  "index_patterns": ["nginx-*"],
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "index.refresh_interval": "5s"
  },
  "mappings": {
    "properties": {
      "@timestamp": { "type": "date" },
      "remote_addr": { "type": "ip" },
      "geoip": {
        "properties": {
          "location": { "type": "geo_point" },
          "latitude": { "type": "float" },
          "longitude": { "type": "float" },
          "country_name": { "type": "keyword" },
          "city_name": { "type": "keyword" },
          "country_code": { "type": "keyword" }
        }
      },
      "status": { "type": "integer" },
      "body_bytes_sent": { "type": "long" },
      "request_time": { "type": "float" },
      "http_user_agent": { "type": "text", "fields": { "keyword": { "type": "keyword" } } },
      "request_uri": { "type": "text", "fields": { "keyword": { "type": "keyword" } } },
      "request_method": { "type": "keyword" },
      "attack_type": { "type": "keyword" },
      "severity": { "type": "keyword" },
      "tags": { "type": "keyword" }
    }
  }
}
EOF

# Create SMTP auth file for ElastAlert (update with your credentials)
cat > elastalert/smtp_auth.yaml << 'EOF'
user: "your-email@gmail.com"
password: "your-app-password"
EOF

# Create error pages for Nginx
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

# Create deployment script
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
# Deploy monitoring stack

echo "Starting ELK stack..."
docker-compose -f docker-compose.logging.yml up -d

echo "Waiting for Elasticsearch to be ready..."
until curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green\|yellow"'; do
    sleep 5
    echo "Waiting for Elasticsearch..."
done

echo "Creating Kibana index patterns..."
sleep 30  # Wait for Kibana to fully start

# Create index pattern for nginx logs
curl -X POST "localhost:5601/api/saved_objects/index-pattern" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d '{
  "attributes": {
    "title": "nginx-*",
    "timeFieldName": "@timestamp"
  }
}'

echo "Stack deployed successfully!"
echo "Access points:"
echo "- Kibana: http://localhost:5601"
echo "- Elasticsearch: http://localhost:9200"
echo "- Application: http://localhost"
EOF

chmod +x scripts/deploy.sh

# Create Wazuh deployment script
cat > scripts/deploy_wazuh.sh << 'EOF'
#!/bin/bash
# Deploy Wazuh SIEM

echo "Generating Wazuh certificates..."
# In production, use proper certificates
# This is a simplified version for testing

echo "Starting Wazuh stack..."
docker-compose -f docker-compose.wazuh.yml up -d

echo "Waiting for Wazuh to be ready..."
sleep 60

echo "Wazuh deployed successfully!"
echo "Access points:"
echo "- Wazuh Dashboard: https://localhost:5601"
echo "- Default credentials: admin / SecretPassword"
EOF

chmod +x scripts/deploy_wazuh.sh

# Create monitoring dashboard setup script
cat > scripts/setup_dashboards.sh << 'EOF'
#!/bin/bash
# Setup Kibana dashboards and visualizations

KIBANA_URL="http://localhost:5601"

echo "Waiting for Kibana to be ready..."
until curl -s "$KIBANA_URL/api/status" | grep -q '"level":"available"'; do
    sleep 5
done

echo "Creating visualizations..."

# Create security dashboard
curl -X POST "$KIBANA_URL/api/saved_objects/dashboard" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d @kibana/dashboards/security_dashboard.json

echo "Dashboards created successfully!"
EOF

chmod +x scripts/setup_dashboards.sh

# Create test script
cat > scripts/test_monitoring.sh << 'EOF'
#!/bin/bash
# Test monitoring setup

echo "Testing monitoring setup..."

# Test Elasticsearch
echo -n "Elasticsearch: "
if curl -s http://localhost:9200/_cluster/health | grep -q '"status"'; then
    echo "OK"
else
    echo "FAILED"
fi

# Test Kibana
echo -n "Kibana: "
if curl -s http://localhost:5601/api/status | grep -q '"level"'; then
    echo "OK"
else
    echo "FAILED"
fi

# Test Nginx
echo -n "Nginx: "
if curl -s http://localhost/health | grep -q "healthy"; then
    echo "OK"
else
    echo "FAILED"
fi

# Test log flow
echo "Generating test request..."
curl -s http://localhost/ > /dev/null

sleep 5

echo -n "Log ingestion: "
if curl -s "http://localhost:9200/nginx-*/_count" | grep -q '"count":[1-9]'; then
    echo "OK"
else
    echo "FAILED"
fi
EOF

chmod +x scripts/test_monitoring.sh

echo "==================================="
echo "Setup complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Update configuration files with your specific settings"
echo "2. Run: ./scripts/deploy.sh"
echo "3. Generate anomalies: python3 scripts/generate_anomalies.py"
echo "4. Access Kibana at http://localhost:5601"
echo "5. For Wazuh SIEM: ./scripts/deploy_wazuh.sh"
echo ""
echo "Configuration files to update:"
echo "- elastalert/smtp_auth.yaml (email credentials)"
echo "- nginx/conf.d/default.conf (domain settings)"
echo "- docker-compose.logging.yml (resource limits)"
echo ""