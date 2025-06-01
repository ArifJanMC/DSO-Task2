#!/bin/bash
# Quick script to generate various anomalies for testing

echo "Generating test anomalies..."

# Base URL
URL="http://localhost"

echo "1. Generating 404 errors (directory enumeration)..."
for i in {1..20}; do
    curl -s "$URL/admin$i" > /dev/null
    curl -s "$URL/backup$i" > /dev/null
    curl -s "$URL/.git/config$i" > /dev/null
done

echo "2. Generating 403 errors..."
for i in {1..15}; do
    curl -s "$URL/.htaccess" > /dev/null
    curl -s "$URL/.env" > /dev/null
    curl -s "$URL/config.ini" > /dev/null
done

echo "3. Testing with suspicious user agents..."
curl -s -H "User-Agent: sqlmap/1.3.11" "$URL/" > /dev/null
curl -s -H "User-Agent: nikto/2.1.5" "$URL/" > /dev/null
curl -s -H "User-Agent: " "$URL/" > /dev/null
curl -s -H "User-Agent: bot" "$URL/" > /dev/null
curl -s -H "User-Agent: scanner" "$URL/" > /dev/null

echo "4. SQL injection attempts..."
curl -s "$URL/api/books?id=1'+OR+'1'='1" > /dev/null
curl -s "$URL/search?q=admin'+DROP+TABLE+users--" > /dev/null
curl -s "$URL/api/authors?name=test'+UNION+SELECT+*+FROM+users--" > /dev/null

echo "5. XSS attempts..."
curl -s "$URL/search?q=<script>alert('XSS')</script>" > /dev/null
curl -s "$URL/api/books?title=<img+src=x+onerror=alert('XSS')>" > /dev/null

echo "6. Rate limit test (rapid requests)..."
for i in {1..30}; do
    curl -s "$URL/api/books" > /dev/null &
done
wait

echo "7. Normal traffic for comparison..."
for i in {1..10}; do
    curl -s "$URL/" > /dev/null
    curl -s "$URL/api/authors" > /dev/null
    curl -s "$URL/api/books" > /dev/null
    sleep 1
done

echo ""
echo "✅ Test anomalies generated!"
echo ""
echo "Wait 30 seconds for log processing, then check Kibana:"
echo "http://localhost:5601"
echo ""
echo "Go to Dashboard → 'Nginx Security Monitoring Dashboard'"
