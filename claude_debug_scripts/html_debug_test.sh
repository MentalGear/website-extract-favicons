#!/bin/bash
# Debug script to check HTML generation and parsing

set -euo pipefail

TEST_DIR="html_debug_files"

cleanup() {
    if [ -f "/tmp/html_debug.pid" ]; then
        kill "$(cat "/tmp/html_debug.pid")" 2>/dev/null || true
        rm -f "/tmp/html_debug.pid"
    fi
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "=== HTML Debug Test ==="

# Create test files
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/manifest-test"

echo "1. Creating HTML file..."
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

echo "2. HTML file content:"
cat "$TEST_DIR/manifest-test/index.html"

echo
echo "3. Creating manifest file..."
cat > "$TEST_DIR/manifest-test/manifest.json" << 'EOF'
{
  "name": "Test App",
  "icons": [
    {"src": "icon-512.png", "sizes": "512x512", "type": "image/png"}
  ]
}
EOF

echo "4. Manifest file content:"
cat "$TEST_DIR/manifest-test/manifest.json"

echo
echo "5. Creating PNG file..."
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > "$TEST_DIR/manifest-test/icon-512.png"
ls -la "$TEST_DIR/manifest-test/"

# Start server
cd "$TEST_DIR"
python3 -m http.server 8890 > /dev/null 2>&1 &
echo $! > "/tmp/html_debug.pid"
cd ..
sleep 2

TEST_URL="http://localhost:8890/manifest-test/"

echo
echo "6. Testing server response:"
curl -s "$TEST_URL"

echo
echo "7. Testing xmllint manifest extraction (case sensitive):"
curl -s "$TEST_URL" | xmllint --html --xpath 'string(//link[@rel="manifest"]/@href)' - 2>/dev/null || echo "Not found with case sensitive"

echo
echo "8. Testing xmllint manifest extraction (case insensitive from script):"
curl -s "$TEST_URL" | xmllint --html --xpath \
  'string(//link[translate(@rel,"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz")="manifest"]/@href)' \
  - 2>/dev/null || echo "Not found with case insensitive"

echo
echo "9. Testing all link elements:"
curl -s "$TEST_URL" | xmllint --html --xpath '//link' - 2>/dev/null || echo "No link elements found"

echo
echo "10. Testing simple grep for manifest:"
curl -s "$TEST_URL" | grep -i manifest || echo "No manifest found with grep"

echo
echo "11. Running actual favicon script:"
bash ./extract-favicon-from-url.sh -v "$TEST_URL" 2>&1 || echo "Script failed"

echo
echo "=== Done ==="