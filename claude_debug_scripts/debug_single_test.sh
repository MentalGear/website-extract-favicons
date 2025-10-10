#!/bin/bash
# Debug script to test a single URL with full output

set -euo pipefail

# Start test server
TEST_PORT=8889
TEST_DIR="debug_test_files"

cleanup() {
    if [ -f "/tmp/debug_favicon_test.pid" ]; then
        local pid=$(cat "/tmp/debug_favicon_test.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "/tmp/debug_favicon_test.pid"
    fi
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Create test files
echo "Creating test files..."
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/manifest-test"

# Create HTML
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

# Create manifest
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
echo $! > "/tmp/debug_favicon_test.pid"
cd ..
sleep 2

echo "Server started on port $TEST_PORT"
TEST_URL="http://localhost:$TEST_PORT/manifest-test/"

echo
echo "=== Testing server setup ==="
echo "1. Testing URL: $TEST_URL"
curl -s "$TEST_URL" | head -10

echo
echo "2. Testing manifest URL:"
MANIFEST_URL="http://localhost:$TEST_PORT/manifest-test/manifest.json"
echo "Manifest URL: $MANIFEST_URL"
curl -s "$MANIFEST_URL"

echo
echo "3. Testing icon files exist:"
for size in 16 192 512; do
    ICON_URL="http://localhost:$TEST_PORT/manifest-test/icon-${size}.png"
    if curl -s --head "$ICON_URL" | grep "200 OK" > /dev/null; then
        echo "✓ icon-${size}.png exists"
    else
        echo "✗ icon-${size}.png missing"
    fi
done

echo
echo "=== Running favicon script with full debug output ==="
if [ -f "./extract-favicon-from-url.sh" ]; then
    echo "Running: bash ./extract-favicon-from-url.sh -v $TEST_URL"
    echo "---"
    bash ./extract-favicon-from-url.sh -v "$TEST_URL" 2>&1 || {
        exit_code=$?
        echo "---"
        echo "Script exited with code: $exit_code"
    }
    echo "---"
else
    echo "Script not found"
fi

echo
echo "=== Manual step-by-step test ==="
echo "4. Manual manifest parsing test:"
echo "Using jq to parse manifest:"

# Test the jq command that the script uses
echo "Primary jq command:"
curl -s "$MANIFEST_URL" | jq -r '.icons[]? | select(.src != null) | [(.sizes | split("x")[0] | tonumber? // 16), .src] | @tsv' 2>&1 || {
    echo "Primary jq failed, trying fallback:"
    curl -s "$MANIFEST_URL" | jq -r '.icons[]? | select(.src != null) | [.sizes, .src] | @tsv' 2>/dev/null | \
    awk -F'\t' '{ 
        size = $1; 
        sub(/x.*/, "", size); 
        if (size == "any") size = 99999; 
        if (size ~ /^[0-9]+$/) print size "\t" $2;
        else print "16\t" $2
    }' | sort -rn || echo "Fallback also failed"
}

echo
echo "=== Done ==="