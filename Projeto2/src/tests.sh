#!/bin/bash

SERVER_URL="http://localhost:8080"
FILES=("index.html" "about.html" "contact.html" "faq.html") # Add as needed
CONCURRENCY=20    # Number of parallel monkeys
ITERATIONS=500    # Requests per monkey

fail=0

# Function to make repeated requests for a file and log output
monkey() {
    local file=$1
    local id=$2
    for ((i=0; i<$ITERATIONS; i++)); do
        # Random delay
        sleep $(echo "scale=2; $RANDOM/32768/10" | bc)
        out=$(curl -s ${SERVER_URL}/${file})
        echo "$out" > /tmp/monkey_${file}_${id}_${i}.txt
    done
}

# Launch monkeys for each file
for file in "${FILES[@]}"; do
    for ((j=0; j<$CONCURRENCY; j++)); do
        monkey $file $j &
    done
done

wait

# Check consistency for each file
for file in "${FILES[@]}"; do
    ref=$(cat /tmp/monkey_${file}_0_0.txt)
    for txt in /tmp/monkey_${file}_*_*txt; do
        cmp -s <(echo "${ref}") "$txt"
        if [ $? -ne 0 ]; then
            echo "❌ Inconsistent cache for $file: $txt"
            fail=1
        fi
    done
done

if [ $fail -eq 0 ]; then
    echo "✅ Cache consistency PASSED for all tested files."
else
    echo "❌ Some cache inconsistencies detected!"
fi

# Clean up
rm /tmp/monkey_*txt