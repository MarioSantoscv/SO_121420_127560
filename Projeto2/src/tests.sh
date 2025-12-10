#!/bin/bash
# tests_content_type_custom.sh - Testa Content-Type para os ficheiros principais do teu projeto

SERVER_URL="http://localhost:8080"
FILES=("index.html" "style.css" "script.js" "homempau.png")
EXPECTED=("text/html" "text/css" "application/javascript" "image/png")

for i in "${!FILES[@]}"; do
    FILE=${FILES[$i]}
    EXPECTED_TYPE=${EXPECTED[$i]}
    echo "---------------------------------------"
    echo "File: $FILE   (Esperado: $EXPECTED_TYPE)"
    CONTENT_TYPE=$(curl -s -D - "$SERVER_URL/$FILE" -o /dev/null | grep -i "^Content-Type:" | awk '{print $2}' | tr -d '\r')
    if [[ "$CONTENT_TYPE" == "$EXPECTED_TYPE" ]]; then
        echo -e "✅ Content-Type correto: $CONTENT_TYPE"
    else
        echo -e "❌ Content-Type errado: $CONTENT_TYPE (esperado: $EXPECTED_TYPE)"
    fi
done
echo "---------------------------------------"