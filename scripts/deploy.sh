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
