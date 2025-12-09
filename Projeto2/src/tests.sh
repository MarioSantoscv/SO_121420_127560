#!/bin/bash
# test_server.sh - Simple automated tester for your HTTP server

SERVER_URL="http://localhost:8080"
DOCROOT="/home/mario/Desktop/SO_121420_127560/Projeto2/www"
LOG="test_results.log"
TMP_IMG="/home/mario/Desktop/SO_121420_127560/Projeto2/www/homempau.png"

echo "=== Functional HTTP Server Tests ===" | tee "$LOG"

# 1. Test GET requests for various file types
echo -e "\n[GET] index.html" | tee -a "$LOG"
curl -sv "$SERVER_URL/index.html" -o /dev/null | tee -a "$LOG"

echo -e "\n[GET] style.css" | tee -a "$LOG"
curl -sv "$SERVER_URL/style.css" -o /dev/null | tee -a "$LOG"

echo -e "\n[GET] app.js" | tee -a "$LOG"
curl -sv "$SERVER_URL/app.js" -o /dev/null | tee -a "$LOG"

echo -e "\n[GET] image.jpg" | tee -a "$LOG"
curl -sv "$SERVER_URL/image.jpg" -o "$TMP_IMG" | tee -a "$LOG"

# 2. Check HTTP status codes
echo -e "\n[HTTP 200] (should be 200)" | tee -a "$LOG"
curl -s -o /dev/null -w "%{http_code}\n" "$SERVER_URL/index.html" | tee -a "$LOG"

echo -e "\n[HTTP 404] (should be 404)" | tee -a "$LOG"
curl -s -o /dev/null -w "%{http_code}\n" "$SERVER_URL/doesnotexist.txt" | tee -a "$LOG"

echo -e "\n[HTTP 403] (should be 403)" | tee -a "$LOG"
curl -s -o /dev/null -w "%{http_code}\n" "$SERVER_URL/../secret.txt" | tee -a "$LOG"

# 3. Directory index (200/403/404 depending on implementation)
echo -e "\n[Directory index on '/']" | tee -a "$LOG"
curl -sv "$SERVER_URL/" -o /dev/null | tee -a "$LOG"

# 4. Content-Type headers
echo -e "\n[Content-Type] index.html" | tee -a "$LOG"
curl -sI "$SERVER_URL/index.html" | grep -i "Content-Type" | tee -a "$LOG"

echo -e "\n[Content-Type] style.css" | tee -a "$LOG"
curl -sI "$SERVER_URL/style.css" | grep -i "Content-Type" | tee -a "$LOG"

echo -e "\n[Content-Type] app.js" | tee -a "$LOG"
curl -sI "$SERVER_URL/app.js" | grep -i "Content-Type" | tee -a "$LOG"

echo -e "\n[Content-Type] image.jpg" | tee -a "$LOG"
curl -sI "$SERVER_URL/image.jpg" | grep -i "Content-Type" | tee -a "$LOG"

echo -e "\n=== Test Run Complete ==="
echo "Check $LOG for results and review Content-Type headers and HTTP status codes."