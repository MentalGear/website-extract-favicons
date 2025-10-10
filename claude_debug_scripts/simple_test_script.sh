#!/bin/bash
# Simple test script to debug the favicon extraction

set -euo pipefail

# Start a simple server for testing
TEST_PORT=8889
TEST_DIR="simple_test_files"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() {
    if [ -f "/tmp/simple_favicon_test.pid" ]; then
        local pid=$(cat "/tmp/simple_favicon_test.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "/tmp/simple_favicon_test.pid"
    fi
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Create test files
echo "Creating test files..."
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/manifest-test"

# Create HTML with manifest
cat > "$TEST_DIR/manifest-test/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Manifest Test</title>
    <link rel="manifest" href="manifest.json">
</head>
<body><h1>Manifest Test</h1></body>
</html>
EOF

# Create simple manifest
cat > "$TEST_DIR/manifest-test/manifest.json" << 'EOF'
{
  "name": "Test App",
  "icons": [
    {
      "src": "icon-16.png",
      "sizes": "16x16",
      "type": "image/png"
    },
    {
      "src": "icon-192.png", 
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icon-512.png",
      "sizes": "512x512", 
      "type": "image/png"
    }
  ]
}
EOF

# Create dummy PNG files
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > "$TEST_DIR/manifest-test/icon-16.png"
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > "$TEST_DIR/manifest-test/icon-192.png"
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > "$TEST_DIR/manifest-test/icon-512.png"

# Start server
cd "$TEST_DIR"
python3 -m http.server $TEST_PORT > /dev/null 2>&1 &
echo $! > "/tmp/simple_favicon_test.pid"
cd ..
sleep 2

echo "Server started on port $TEST_PORT"

# Test URL
TEST_URL="http://localhost:$TEST_PORT/manifest-test/"

# Manual tests
echo -e "\n${BLUE}=== Manual Testing ===${NC}"

echo "1. Testing server response:"
if curl -s "$TEST_URL" > /dev/null; then
    echo -e "${GREEN}✓ Server responding${NC}"
else
    echo -e "${RED}✗ Server not responding${NC}"
    exit 1
fi

echo
echo "2. HTML content:"
curl -s "$TEST_URL" | head -10

echo
echo "3. Manifest URL extraction:"
MANIFEST_HREF=$(curl -s "$TEST_URL" | xmllint --html --xpath 'string(//link[@rel="manifest"]/@href)' - 2>/dev/null || echo "")
echo "Manifest href: '$MANIFEST_HREF'"

if [ -n "$MANIFEST_HREF" ]; then
    MANIFEST_URL="http://localhost:$TEST_PORT/manifest-test/$MANIFEST_HREF"
    echo "Full manifest URL: $MANIFEST_URL"
    
    echo
    echo "4. Manifest content:"
    curl -s "$MANIFEST_URL"
    
    echo
    echo "5. jq parsing test:"
    LARGEST_ICON=$(curl -s "$MANIFEST_URL" | jq -r '.icons | sort_by(.sizes | split("x")[0] | tonumber) | reverse | .[0].src' 2>/dev/null || echo "jq failed")
    echo "Largest icon: $LARGEST_ICON"
fi

echo
echo -e "${BLUE}=== Testing with actual script ===${NC}"
if [ -f "./extract-favicon-from-url.sh" ]; then
    echo "Running script with verbose output:"
    bash ./extract-favicon-from-url.sh -v "$TEST_URL" 2>&1 || {
        exit_code=$?
        echo "Script exited with code: $exit_code"
    }
else
    echo "Script not found"
fi

echo -e "\n${BLUE}=== Done ===${NC}"