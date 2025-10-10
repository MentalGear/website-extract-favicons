#!/bin/bash
# Diagnostic script to debug favicon extraction issues

set -euo pipefail

TEST_URL="http://localhost:8888/manifest-test/"
SCRIPT_PATH="./extract-favicon-from-url.sh"

echo "=== Favicon Extraction Diagnostic ==="
echo "Testing URL: $TEST_URL"
echo

# Check if server is running
echo "1. Testing server connectivity:"
if curl -s "$TEST_URL" > /dev/null; then
    echo "✓ Server is responding"
else
    echo "✗ Server is not responding"
    exit 1
fi

# Check the HTML content
echo
echo "2. HTML content from server:"
echo "---"
curl -s "$TEST_URL" | head -20
echo "---"

# Check manifest link extraction
echo
echo "3. Testing manifest link extraction:"
MANIFEST_HREF=$(curl -s "$TEST_URL" | xmllint --html --xpath \
  'string(//link[translate(@rel,"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz")="manifest"]/@href)' \
  - 2>/dev/null || echo "")
echo "Manifest href: '$MANIFEST_HREF'"

if [ -n "$MANIFEST_HREF" ]; then
    MANIFEST_URL=$(python3 -c "import urllib.parse; print(urllib.parse.urljoin('$TEST_URL','$MANIFEST_HREF'))")
    echo "Full manifest URL: $MANIFEST_URL"
    
    # Check manifest content
    echo
    echo "4. Manifest content:"
    echo "---"
    curl -s "$MANIFEST_URL" || echo "Failed to fetch manifest"
    echo
    echo "---"
    
    # Test jq parsing
    echo
    echo "5. Testing jq parsing:"
    curl -s "$MANIFEST_URL" | jq -r '.icons[]? | select(.src != null) | [(.sizes | split("x")[0] | tonumber? // 16), .src] | @tsv' 2>/dev/null || {
        echo "Primary jq command failed, trying fallback:"
        curl -s "$MANIFEST_URL" | jq -r '.icons[]? | select(.src != null) | [.sizes, .src] | @tsv' 2>/dev/null | \
        awk -F'\t' '{ 
            size = $1; 
            sub(/x.*/, "", size); 
            if (size == "any") size = 99999; 
            if (size ~ /^[0-9]+$/) print size "\t" $2;
            else print "16\t" $2
        }' | sort -rn || echo "Fallback also failed"
    }
fi

# Test the actual script
echo
echo "6. Running the actual script with verbose output:"
echo "---"
if [ -f "$SCRIPT_PATH" ]; then
    bash "$SCRIPT_PATH" -v "$TEST_URL" || echo "Script failed with exit code $?"
else
    echo "Script not found at $SCRIPT_PATH"
fi
echo "---"

# Test individual components that might be missing
echo
echo "7. Testing required tools:"
which curl && echo "✓ curl available" || echo "✗ curl missing"
which xmllint && echo "✓ xmllint available" || echo "✗ xmllint missing"  
which jq && echo "✓ jq available" || echo "✗ jq missing"
which python3 && echo "✓ python3 available" || echo "✗ python3 missing"

echo
echo "=== End Diagnostic ==="