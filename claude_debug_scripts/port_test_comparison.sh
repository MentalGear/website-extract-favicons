#!/bin/bash
# Test to compare different ports and identify the issue

set -euo pipefail

# Test both ports
TEST_DIR="port_test_files"

cleanup() {
    for pid_file in /tmp/port_test_8888.pid /tmp/port_test_8889.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            kill "$pid" 2>/dev/null || true
            rm -f "$pid_file"
        fi
    done
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "=== Port Test Comparison ==="

# Create test files
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/manifest-test"

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

cat > "$TEST_DIR/manifest-test/manifest.json" << 'EOF'
{
  "name": "Test App",
  "icons": [
    {
      "src": "icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
EOF

echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > "$TEST_DIR/manifest-test/icon-512.png"

# Start servers on both ports
cd "$TEST_DIR"

echo "Starting server on port 8888..."
python3 -m http.server 8888 > /dev/null 2>&1 &
echo $! > "/tmp/port_test_8888.pid"

echo "Starting server on port 8889..."
python3 -m http.server 8889 > /dev/null 2>&1 &
echo $! > "/tmp/port_test_8889.pid"

cd ..
sleep 3

# Test both URLs
URL_8888="http://localhost:8888/manifest-test/"
URL_8889="http://localhost:8889/manifest-test/"

echo
echo "Testing connectivity to both ports:"
if curl -s --max-time 2 "$URL_8888" > /dev/null; then
    echo "✓ Port 8888 responding"
else
    echo "✗ Port 8888 not responding"
fi

if curl -s --max-time 2 "$URL_8889" > /dev/null; then
    echo "✓ Port 8889 responding"
else
    echo "✗ Port 8889 not responding"
fi

echo
echo "Testing favicon script on both ports:"

echo "--- Testing port 8888 ---"
bash ./extract-favicon-from-url.sh -v "$URL_8888" 2>&1 || {
    exit_code=$?
    echo "Port 8888 failed with exit code: $exit_code"
}

echo
echo "--- Testing port 8889 ---"
bash ./extract-favicon-from-url.sh -v "$URL_8889" 2>&1 || {
    exit_code=$?
    echo "Port 8889 failed with exit code: $exit_code"
}

echo
echo "=== Checking what process might be using port 8888 ==="
lsof -Pi :8888 -sTCP:LISTEN || echo "No processes found on port 8888"

echo
echo "=== Done ==="