#!/bin/bash
# Create Kibana dashboards and visualizations for security monitoring

KIBANA_URL="http://localhost:5601"

echo "Waiting for Kibana to be ready..."
until curl -s "$KIBANA_URL/api/status" | grep -q '"summary":"All services are available"'; do
    sleep 5
done

echo "Creating index patterns..."

# Create index pattern for nginx logs
curl -X POST "$KIBANA_URL/api/saved_objects/index-pattern/nginx-*" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d '{
  "attributes": {
    "title": "nginx-*",
    "timeFieldName": "@timestamp"
  }
}'

# Create index pattern for security alerts
curl -X POST "$KIBANA_URL/api/saved_objects/index-pattern/security-alerts-*" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d '{
  "attributes": {
    "title": "security-alerts-*",
    "timeFieldName": "@timestamp"
  }
}'

echo "Creating visualizations and capturing IDs..."

# Function to extract ID from curl response (requires jq)
# If jq is not available, you might need to use grep/sed/awk, which is less robust.
extract_id() {
    echo "$1" | jq -r .id
}

# 1. 404 Errors Count
VIS_404_RESPONSE=$(curl -X POST "$KIBANA_URL/api/saved_objects/visualization" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d '{
  "attributes": {
    "title": "404 Errors Count",
    "visState": "{\"title\":\"404 Errors Count\",\"type\":\"metric\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"}],\"params\":{\"addTooltip\":true,\"addLegend\":false,\"type\":\"metric\",\"metric\":{\"colorSchema\":\"Green to Red\",\"metricColorMode\":\"None\",\"useRanges\":false}}}",
    "uiStateJSON": "{}",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[{\"meta\":{\"alias\":null,\"negate\":false,\"disabled\":false,\"type\":\"phrase\",\"key\":\"status\",\"params\":{\"query\":404}},\"query\":{\"match_phrase\":{\"status\":404}}}],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [
    {
      "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
      "type": "index-pattern",
      "id": "nginx-*"
    }
  ]
}')
VIS_404_ID=$(extract_id "$VIS_404_RESPONSE")
echo "404 Errors Count Visualization ID: $VIS_404_ID"

# 2. 403 Errors Count
VIS_403_RESPONSE=$(curl -X POST "$KIBANA_URL/api/saved_objects/visualization" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d '{
  "attributes": {
    "title": "403 Errors Count",
    "visState": "{\"title\":\"403 Errors Count\",\"type\":\"metric\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"}],\"params\":{\"addTooltip\":true,\"addLegend\":false,\"type\":\"metric\",\"metric\":{\"colorSchema\":\"Green to Red\",\"metricColorMode\":\"None\",\"useRanges\":false}}}",
    "uiStateJSON": "{}",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[{\"meta\":{\"alias\":null,\"negate\":false,\"disabled\":false,\"type\":\"phrase\",\"key\":\"status\",\"params\":{\"query\":403}},\"query\":{\"match_phrase\":{\"status\":403}}}],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [
    {
      "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
      "type": "index-pattern",
      "id": "nginx-*"
    }
  ]
}')
VIS_403_ID=$(extract_id "$VIS_403_RESPONSE")
echo "403 Errors Count Visualization ID: $VIS_403_ID"

# 3. Top IPs by Request Count
VIS_TOP_IP_RESPONSE=$(curl -X POST "$KIBANA_URL/api/saved_objects/visualization" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d '{
  "attributes": {
    "title": "Top IPs by Request Count",
    "visState": "{\"title\":\"Top IPs by Request Count\",\"type\":\"pie\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"remote_addr\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":10},\"schema\":\"segment\"}],\"params\":{\"type\":\"pie\",\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"isDonut\":true}}",
    "uiStateJSON": "{}",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [
    {
      "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
      "type": "index-pattern",
      "id": "nginx-*"
    }
  ]
}')
VIS_TOP_IP_ID=$(extract_id "$VIS_TOP_IP_RESPONSE")
echo "Top IPs Visualization ID: $VIS_TOP_IP_ID"

# 4. Security Alerts Over Time
VIS_ALERTS_TIME_RESPONSE=$(curl -X POST "$KIBANA_URL/api/saved_objects/visualization" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d '{
  "attributes": {
    "title": "Security Alerts Over Time",
    "visState": "{\"title\":\"Security Alerts Over Time\",\"type\":\"line\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"date_histogram\",\"params\":{\"field\":\"@timestamp\",\"interval\":\"auto\",\"min_doc_count\":0},\"schema\":\"segment\"}],\"params\":{\"type\":\"line\",\"grid\":{\"categoryLines\":false},\"categoryAxes\":[{\"id\":\"CategoryAxis-1\",\"type\":\"category\",\"position\":\"bottom\",\"show\":true,\"style\":{},\"scale\":{\"type\":\"linear\"},\"labels\":{\"show\":true,\"truncate\":100},\"title\":{}}],\"valueAxes\":[{\"id\":\"ValueAxis-1\",\"name\":\"LeftAxis-1\",\"type\":\"value\",\"position\":\"left\",\"show\":true,\"style\":{},\"scale\":{\"type\":\"linear\",\"mode\":\"normal\"},\"labels\":{\"show\":true,\"rotate\":0,\"filter\":false,\"truncate\":100},\"title\":{\"text\":\"Count\"}}],\"seriesParams\":[{\"show\":true,\"type\":\"line\",\"mode\":\"normal\",\"data\":{\"label\":\"Count\",\"id\":\"1\"},\"valueAxis\":\"ValueAxis-1\",\"drawLinesBetweenPoints\":true,\"lineWidth\":2,\"showCircles\":true}],\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\"}}",
    "uiStateJSON": "{}",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"tags:security_alert\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [
    {
      "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
      "type": "index-pattern",
      "id": "security-alerts-*"
    }
  ]
}')
VIS_ALERTS_TIME_ID=$(extract_id "$VIS_ALERTS_TIME_RESPONSE")
echo "Security Alerts Over Time Visualization ID: $VIS_ALERTS_TIME_ID"

# 5. Attack Types Distribution
VIS_ATTACK_TYPES_RESPONSE=$(curl -X POST "$KIBANA_URL/api/saved_objects/visualization" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d '{
  "attributes": {
    "title": "Attack Types Distribution",
    "visState": "{\"title\":\"Attack Types Distribution\",\"type\":\"pie\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"attack_type\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":10},\"schema\":\"segment\"}],\"params\":{\"type\":\"pie\",\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"isDonut\":false}}",
    "uiStateJSON": "{}",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [
    {
      "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
      "type": "index-pattern",
      "id": "security-alerts-*"
    }
  ]
}')
VIS_ATTACK_TYPES_ID=$(extract_id "$VIS_ATTACK_TYPES_RESPONSE")
echo "Attack Types Distribution Visualization ID: $VIS_ATTACK_TYPES_ID"

# 6. Suspicious User Agents
VIS_SUSPICIOUS_AGENTS_RESPONSE=$(curl -X POST "$KIBANA_URL/api/saved_objects/visualization" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d '{
  "attributes": {
    "title": "Suspicious User Agents",
    "visState": "{\"title\":\"Suspicious User Agents\",\"type\":\"data_table\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"http_user_agent\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":20},\"schema\":\"bucket\"}],\"params\":{\"perPage\":10,\"showPartialRows\":false,\"showMetricsAtAllLevels\":false,\"showTotal\":false,\"totalFunc\":\"sum\"}}",
    "uiStateJSON": "{}",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"tags:suspicious_user_agent\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [
    {
      "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
      "type": "index-pattern",
      "id": "nginx-*"
    }
  ]
}')
VIS_SUSPICIOUS_AGENTS_ID=$(extract_id "$VIS_SUSPICIOUS_AGENTS_RESPONSE")
echo "Suspicious User Agents Visualization ID: $VIS_SUSPICIOUS_AGENTS_ID"

# 7. HTTP Status Codes Distribution
VIS_STATUS_CODES_RESPONSE=$(curl -X POST "$KIBANA_URL/api/saved_objects/visualization" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d '{
  "attributes": {
    "title": "HTTP Status Codes Distribution",
    "visState": "{\"title\":\"HTTP Status Codes Distribution\",\"type\":\"histogram\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"status\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":20},\"schema\":\"segment\"}],\"params\":{\"type\":\"histogram\",\"grid\":{\"categoryLines\":false},\"categoryAxes\":[{\"id\":\"CategoryAxis-1\",\"type\":\"category\",\"position\":\"bottom\",\"show\":true,\"style\":{},\"scale\":{\"type\":\"linear\"},\"labels\":{\"show\":true,\"truncate\":100},\"title\":{}}],\"valueAxes\":[{\"id\":\"ValueAxis-1\",\"name\":\"LeftAxis-1\",\"type\":\"value\",\"position\":\"left\",\"show\":true,\"style\":{},\"scale\":{\"type\":\"linear\",\"mode\":\"normal\"},\"labels\":{\"show\":true,\"rotate\":0,\"filter\":false,\"truncate\":100},\"title\":{\"text\":\"Count\"}}],\"seriesParams\":[{\"show\":true,\"type\":\"histogram\",\"mode\":\"stacked\",\"data\":{\"label\":\"Count\",\"id\":\"1\"},\"valueAxis\":\"ValueAxis-1\"}],\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\"}}",
    "uiStateJSON": "{}",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [
    {
      "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
      "type": "index-pattern",
      "id": "nginx-*"
    }
  ]
}')
VIS_STATUS_CODES_ID=$(extract_id "$VIS_STATUS_CODES_RESPONSE")
echo "HTTP Status Codes Visualization ID: $VIS_STATUS_CODES_ID"


echo "Creating Security Dashboard..."

# Construct the references JSON
REFERENCES_JSON="[
  {\"name\":\"panel_1\",\"type\":\"visualization\",\"id\":\"${VIS_404_ID}\"},
  {\"name\":\"panel_2\",\"type\":\"visualization\",\"id\":\"${VIS_403_ID}\"},
  {\"name\":\"panel_3\",\"type\":\"visualization\",\"id\":\"${VIS_TOP_IP_ID}\"},
  {\"name\":\"panel_4\",\"type\":\"visualization\",\"id\":\"${VIS_ALERTS_TIME_ID}\"},
  {\"name\":\"panel_5\",\"type\":\"visualization\",\"id\":\"${VIS_ATTACK_TYPES_ID}\"},
  {\"name\":\"panel_6\",\"type\":\"visualization\",\"id\":\"${VIS_SUSPICIOUS_AGENTS_ID}\"},
  {\"name\":\"panel_7\",\"type\":\"visualization\",\"id\":\"${VIS_STATUS_CODES_ID}\"}
]"

# Create main security dashboard
curl -X POST "$KIBANA_URL/api/saved_objects/dashboard" \
-H "Content-Type: application/json" \
-H "kbn-xsrf: true" \
-d "{
  \"attributes\": {
    \"title\": \"Nginx Security Monitoring Dashboard\",
    \"hits\": 0,
    \"description\": \"Dashboard for monitoring Nginx security events and anomalies\",
    \"panelsJSON\": \"[{\\\"version\\\":\\\"8.11.3\\\",\\\"type\\\":\\\"visualization\\\",\\\"gridData\\\":{\\\"x\\\":0,\\\"y\\\":0,\\\"w\\\":12,\\\"h\\\":15,\\\"i\\\":\\\"1\\\"},\\\"panelIndex\\\":\\\"1\\\",\\\"embeddableConfig\\\":{\\\"enhancements\\\":{}},\\\"panelRefName\\\":\\\"panel_1\\\"},{\\\"version\\\":\\\"8.11.3\\\",\\\"type\\\":\\\"visualization\\\",\\\"gridData\\\":{\\\"x\\\":12,\\\"y\\\":0,\\\"w\\\":12,\\\"h\\\":15,\\\"i\\\":\\\"2\\\"},\\\"panelIndex\\\":\\\"2\\\",\\\"embeddableConfig\\\":{\\\"enhancements\\\":{}},\\\"panelRefName\\\":\\\"panel_2\\\"},{\\\"version\\\":\\\"8.11.3\\\",\\\"type\\\":\\\"visualization\\\",\\\"gridData\\\":{\\\"x\\\":24,\\\"y\\\":0,\\\"w\\\":24,\\\"h\\\":15,\\\"i\\\":\\\"3\\\"},\\\"panelIndex\\\":\\\"3\\\",\\\"embeddableConfig\\\":{\\\"enhancements\\\":{}},\\\"panelRefName\\\":\\\"panel_3\\\"},{\\\"version\\\":\\\"8.11.3\\\",\\\"type\\\":\\\"visualization\\\",\\\"gridData\\\":{\\\"x\\\":0,\\\"y\\\":15,\\\"w\\\":48,\\\"h\\\":15,\\\"i\\\":\\\"4\\\"},\\\"panelIndex\\\":\\\"4\\\",\\\"embeddableConfig\\\":{\\\"enhancements\\\":{}},\\\"panelRefName\\\":\\\"panel_4\\\"},{\\\"version\\\":\\\"8.11.3\\\",\\\"type\\\":\\\"visualization\\\",\\\"gridData\\\":{\\\"x\\\":0,\\\"y\\\":30,\\\"w\\\":24,\\\"h\\\":15,\\\"i\\\":\\\"5\\\"},\\\"panelIndex\\\":\\\"5\\\",\\\"embeddableConfig\\\":{\\\"enhancements\\\":{}},\\\"panelRefName\\\":\\\"panel_5\\\"},{\\\"version\\\":\\\"8.11.3\\\",\\\"type\\\":\\\"visualization\\\",\\\"gridData\\\":{\\\"x\\\":24,\\\"y\\\":30,\\\"w\\\":24,\\\"h\\\":15,\\\"i\\\":\\\"6\\\"},\\\"panelIndex\\\":\\\"6\\\",\\\"embeddableConfig\\\":{\\\"enhancements\\\":{}},\\\"panelRefName\\\":\\\"panel_6\\\"},{\\\"version\\\":\\\"8.11.3\\\",\\\"type\\\":\\\"visualization\\\",\\\"gridData\\\":{\\\"x\\\":0,\\\"y\\\":45,\\\"w\\\":48,\\\"h\\\":15,\\\"i\\\":\\\"7\\\"},\\\"panelIndex\\\":\\\"7\\\",\\\"embeddableConfig\\\":{\\\"enhancements\\\":{}},\\\"panelRefName\\\":\\\"panel_7\\\"}]\",
    \"optionsJSON\": \"{\\\"useMargins\\\":true,\\\"syncColors\\\":false,\\\"syncCursor\\\":true,\\\"syncTooltips\\\":false,\\\"hidePanelTitles\\\":false}\",
    \"timeRestore\": true,
    \"timeTo\": \"now\",
    \"timeFrom\": \"now-15m\",
    \"refreshInterval\": {
      \"pause\": false,
      \"value\": 10000
    },
    \"kibanaSavedObjectMeta\": {
      \"searchSourceJSON\": \"{\\\"query\\\":{\\\"query\\\":\\\"\\\",\\\"language\\\":\\\"kuery\\\"},\\\"filter\\\":[]}\"
    }
  },
  \"references\": ${REFERENCES_JSON}
}"

echo ""
echo "Dashboard creation complete!"
echo ""
echo "Access your dashboard at: $KIBANA_URL"
echo "Navigate to Dashboard section to see 'Nginx Security Monitoring Dashboard'"
