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
