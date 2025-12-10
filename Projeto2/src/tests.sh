#!/bin/bash
# tests.sh - Simple HTTP server GET test for HTML file

SERVER_URL="http://localhost:8080"
DOCROOT="/home/mario/Desktop/SO_121420_127560/Projeto2/www"
LOG="test_html_get.log"

echo "=== HTML GET Test ===" | tee "$LOG"

HTML_FILE="index.html"

echo -e "\n[GET] /$HTML_FILE" | tee -a "$LOG"
curl -sv "$SERVER_URL/$HTML_FILE" -o /dev/null 2>&1 | tee -a "$LOG"

echo -e "\n[Content-Type] /$HTML_FILE" | tee -a "$LOG"
curl -sI "$SERVER_URL/$HTML_FILE" | grep -i "Content-Type" | tee -a "$LOG"

echo -e "\n[HTTP Status] /$HTML_FILE" | tee -a "$LOG"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$SERVER_URL/$HTML_FILE" | tee -a "$LOG"

echo -e "\n=== Test Complete ===" | tee -a "$LOG"
echo "Check $LOG for GET response, Content-Type header, and status code."