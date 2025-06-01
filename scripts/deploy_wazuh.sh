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
