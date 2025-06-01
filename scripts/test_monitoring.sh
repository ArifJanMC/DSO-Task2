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
