#!/bin/bash
# Fixed deterministic test suite for favicon extraction using local server
set -euo pipefail

# Configuration
readonly SCRIPT_TO_TEST="./extract-favicon-from-url.sh"
readonly TEST_PORT=8888
readonly TEST_HOST="localhost:$TEST_PORT"
readonly TEST_DIR="test_server_files"
readonly SERVER_PID_FILE="/tmp/favicon_test_server.pid"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Utility functions
log_test() { echo -e "${BLUE}[TEST]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; ((TESTS_FAILED++)); }
log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

# Server management
setup_test_server() {
    log_info "Setting up test server..."
    
    # Clean up any existing test directory
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    
    # Create test files
    create_test_files
    
    # Start Python HTTP server
    cd "$TEST_DIR"
    python3 -m http.server $TEST_PORT >/dev/null 2>&1 &
    local server_pid=$!
    echo $server_pid > "$SERVER_PID_FILE"
    cd ..
    
    # Wait for server to start
    sleep 3
    
    # Verify server is running
    local max_attempts=10
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "http://$TEST_HOST" >/dev/null; then
            break
        fi
        sleep 1
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}Failed to start test server after $max_attempts attempts${NC}"
        exit 1
    fi
    
    log_info "Test server running on http://$TEST_HOST (PID: $server_pid)"
}

cleanup_test_server() {
    if [ -f "$SERVER_PID_FILE" ]; then
        local server_pid=$(cat "$SERVER_PID_FILE")
        if kill "$server_pid" 2>/dev/null; then
            log_info "Test server stopped (PID: $server_pid)"
        fi
        rm -f "$SERVER_PID_FILE"
    fi
    rm -rf "$TEST_DIR"
}

create_test_files() {
    # Create a simple 1x1 pixel ICO file (base64 encoded)
    echo "AAABAAEAEBAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAQAABILAAASCwAAAAAAAAAAAAD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==" | base64 -d > favicon.ico
    
    # Test Case 1: PWA Manifest
    mkdir -p manifest-test
    cat > manifest-test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Manifest Test</title>
    <link rel="manifest" href="manifest.json">
</head>
<body><h1>Manifest Test</h1></body>
</html>
EOF

    cat > manifest-test/manifest.json << 'EOF'
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

    # Create a simple 1x1 PNG (base64 encoded)
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > manifest-test/icon-16.png
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > manifest-test/icon-192.png
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > manifest-test/icon-512.png

    # Test Case 2: Apple Touch Icon Priority
    mkdir -p apple-touch-test
    cat > apple-touch-test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Apple Touch Icon Test</title>
    <link rel="icon" href="regular-icon.png" sizes="32x32">
    <link rel="apple-touch-icon" href="apple-touch-icon.png" sizes="180x180">
    <link rel="shortcut icon" href="shortcut-icon.ico">
</head>
<body><h1>Apple Touch Icon Priority Test</h1></body>
</html>
EOF

    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > apple-touch-test/regular-icon.png
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > apple-touch-test/apple-touch-icon.png
    cp favicon.ico apple-touch-test/shortcut-icon.ico

    # Test Case 3: Regular Link Icons
    mkdir -p link-icon-test
    cat > link-icon-test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Link Icon Test</title>
    <link rel="icon" href="icon-16.png" sizes="16x16">
    <link rel="icon" href="icon-32.png" sizes="32x32">
    <link rel="shortcut icon" href="favicon.ico">
</head>
<body><h1>Link Icon Test</h1></body>
</html>
EOF

    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > link-icon-test/icon-16.png
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > link-icon-test/icon-32.png
    cp favicon.ico link-icon-test/favicon.ico

    # Test Case 4: Favicon.ico Fallback
    mkdir -p favicon-fallback-test
    cat > favicon-fallback-test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Favicon Fallback Test</title>
</head>
<body><h1>Favicon Fallback Test</h1></body>
</html>
EOF
    cp favicon.ico favicon-fallback-test/favicon.ico

    # Test Case 5: No Icon Available
    mkdir -p no-icon-test
    cat > no-icon-test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>No Icon Test</title>
</head>
<body><h1>No Icon Test</h1></body>
</html>
EOF
    # Intentionally no favicon.ico file

    # Test Case 6: Invalid Manifest
    mkdir -p invalid-manifest-test
    cat > invalid-manifest-test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Invalid Manifest Test</title>
    <link rel="manifest" href="invalid-manifest.json">
    <link rel="icon" href="fallback-icon.png">
</head>
<body><h1>Invalid Manifest Test</h1></body>
</html>
EOF

    cat > invalid-manifest-test/invalid-manifest.json << 'EOF'
{
  "name": "Test App",
  "icons": "this is invalid json syntax"
}
EOF

    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > invalid-manifest-test/fallback-icon.png
}

# Test functions with better error handling
assert_url_contains() {
    local url_to_test=$1
    local expected_substring=$2
    local description=$3
    ((TESTS_RUN++))
    
    log_test "Testing '$url_to_test' should contain '$expected_substring' ($description)"
    
    local output exit_code full_output
    set +e
    full_output=$(bash "$SCRIPT_TO_TEST" -v "$url_to_test" 2>&1)
    exit_code=$?
    output=$(echo "$full_output" | grep "^http" | tail -n1 2>/dev/null || echo "")
    set -e
    
    if [[ $exit_code -eq 0 && -n "$output" && "$output" == *"$expected_substring"* ]]; then
        log_pass "URL contains expected substring: $output"
    else
        log_fail "Expected substring '$expected_substring' not found. Got: '$output' (exit: $exit_code)"
        if [[ $exit_code -ne 0 ]]; then
            log_info "Debug output: $(echo "$full_output" | grep -E "(ERROR|WARN|DEBUG)" | head -3 || echo "No debug info")"
        fi
    fi
}

assert_apple_touch_icon_priority() {
    local url_to_test=$1
    local description=$2
    ((TESTS_RUN++))
    
    log_test "Testing apple-touch-icon priority for '$url_to_test' ($description)"
    
    local full_output final_url exit_code
    set +e
    full_output=$(bash "$SCRIPT_TO_TEST" -v "$url_to_test" 2>&1)
    exit_code=$?
    set -e
    
    final_url=$(echo "$full_output" | grep "^http" | tail -n1 2>/dev/null || echo "")
    
    if [[ $exit_code -eq 0 && "$final_url" == *"apple-touch-icon"* ]]; then
        log_pass "Apple-touch-icon correctly prioritized: $final_url"
    else
        log_fail "Apple-touch-icon not prioritized. Got: '$final_url' (exit: $exit_code)"
        log_info "Debug output: $(echo "$full_output" | grep -E "(priority=|Selected|apple-touch-icon|DEBUG)" | head -5 || echo "No debug info")"
    fi
}

assert_no_url_returned() {
    local url_to_test=$1
    local description=$2
    ((TESTS_RUN++))
    
    log_test "Testing '$url_to_test' should return no URL ($description)"
    
    local output exit_code
    set +e
    output=$(bash "$SCRIPT_TO_TEST" "$url_to_test" 2>/dev/null)
    exit_code=$?
    set -e
    
    if [[ $exit_code -ne 0 && -z "$output" ]]; then
        log_pass "No URL returned as expected (exit code: $exit_code)"
    else
        log_fail "Unexpected URL returned: '$output' (exit code: $exit_code)"
    fi
}

# Test server connectivity
test_server_connectivity() {
    log_info "Testing server connectivity..."
    
    # Test basic connectivity
    if ! curl -s "http://$TEST_HOST" >/dev/null; then
        log_fail "Server connectivity test failed"
        return 1
    fi
    
    # Test manifest endpoint specifically
    if ! curl -s "http://$TEST_HOST/manifest-test/manifest.json" >/dev/null; then
        log_fail "Manifest endpoint test failed"
        return 1
    fi
    
    log_info "Server connectivity tests passed"
    return 0
}

# Main test runner
run_tests() {
    echo "Running Fixed Deterministic Favicon Extraction Test Suite"
    echo "========================================================"
    
    # Test server connectivity first
    if ! test_server_connectivity; then
        echo -e "${RED}Server connectivity tests failed. Aborting.${NC}"
        return 1
    fi
    
    # Temporarily disable -e to allow all tests to run
    set +e
    
    # Category 1: PWA Manifest
    echo -e "\n--- Category: PWA Manifest ---"
    assert_url_contains "http://$TEST_HOST/manifest-test/" "icon-512.png" "Largest manifest icon selected"
    
    # Category 2: Apple Touch Icon Priority
    echo -e "\n--- Category: Apple Touch Icon Priority ---"
    assert_apple_touch_icon_priority "http://$TEST_HOST/apple-touch-test/" "Apple-touch-icon over regular icon"
    
    # Category 3: Regular Link Icons
    echo -e "\n--- Category: Link Icons ---"
    assert_url_contains "http://$TEST_HOST/link-icon-test/" "icon-32.png" "Larger icon preferred"
    
    # Category 4: Favicon.ico Fallback
    echo -e "\n--- Category: Favicon.ico Fallback ---"
    assert_url_contains "http://$TEST_HOST/favicon-fallback-test/" "favicon.ico" "Favicon.ico fallback"
    
    # Category 5: Invalid Manifest Fallback
    echo -e "\n--- Category: Invalid Manifest Fallback ---"
    assert_url_contains "http://$TEST_HOST/invalid-manifest-test/" "fallback-icon.png" "Fallback after invalid manifest"
    
    # Category 6: No Icon Available
    echo -e "\n--- Category: No Icon Available ---"
    assert_no_url_returned "http://$TEST_HOST/no-icon-test/" "No icon should fail"
    
    # Re-enable -e
    set -e
    
    # Report results
    echo
    echo "Test Results:"
    echo "============="
    echo "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed! 🎉${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed. 😞${NC}"
        return 1
    fi
}

# Trap cleanup
trap cleanup_test_server EXIT

# Main execution
if [ ! -f "$SCRIPT_TO_TEST" ]; then
    echo -e "${RED}Error: Script to test not found at '$SCRIPT_TO_TEST'${NC}"
    exit 1
fi

# Check if port is available
if lsof -Pi :$TEST_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${RED}Error: Port $TEST_PORT is already in use${NC}"
    exit 1
fi

chmod +x "$SCRIPT_TO_TEST"
setup_test_server
run_tests