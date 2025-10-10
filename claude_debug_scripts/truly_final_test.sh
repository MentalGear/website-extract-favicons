#!/bin/bash
# Truly final test script - fixes the output parsing issue

set -eo pipefail

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

# Fixed function to run favicon script and capture output
run_favicon_script() {
    local url="$1"
    local verbose="${2:-}"
    
    local temp_output=$(mktemp)
    local exit_code=0
    
    # Run the script and capture everything
    if [ "$verbose" = "-v" ]; then
        bash "$SCRIPT_TO_TEST" -v "$url" > "$temp_output" 2>&1 || exit_code=$?
    else
        bash "$SCRIPT_TO_TEST" "$url" > "$temp_output" 2>&1 || exit_code=$?
    fi
    
    local full_output=$(cat "$temp_output")
    rm -f "$temp_output"
    
    # The script outputs the URL as the LAST line (after all the debug info)
    # We need to get the very last line that contains http
    local final_url=""
    
    # Method 1: Get the last line that starts with http
    final_url=$(echo "$full_output" | grep '^http' | tail -n1 || echo "")
    
    # Method 2: If that didn't work, try getting the last line after [SUCCESS]
    if [ -z "$final_url" ]; then
        # Look for lines after [SUCCESS] that contain http
        final_url=$(echo "$full_output" | awk '/\[SUCCESS\]/{flag=1; next} flag && /^http/{print; exit}' || echo "")
    fi
    
    # Method 3: If still nothing, get any line with http that's not a debug line
    if [ -z "$final_url" ]; then
        final_url=$(echo "$full_output" | grep -v '^\[' | grep 'http' | tail -n1 || echo "")
    fi
    
    # Return results via global variables
    SCRIPT_OUTPUT="$full_output"
    SCRIPT_EXIT_CODE="$exit_code"
    SCRIPT_FINAL_URL="$final_url"
}

# Server management (simplified)
setup_test_server() {
    log_info "Setting up test server..."
    
    cleanup_test_server
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    create_test_files
    
    cd "$TEST_DIR"
    python3 -m http.server $TEST_PORT >/dev/null 2>&1 &
    local server_pid=$!
    echo $server_pid > "$SERVER_PID_FILE"
    cd ..
    
    # Wait for server
    for i in {1..20}; do
        if curl -s --max-time 1 "http://$TEST_HOST/" >/dev/null 2>&1; then
            log_info "Test server running on http://$TEST_HOST (PID: $server_pid)"
            return 0
        fi
        sleep 0.5
    done
    
    log_fail "Server failed to start"
    return 1
}

cleanup_test_server() {
    if [ -f "$SERVER_PID_FILE" ]; then
        local server_pid=$(cat "$SERVER_PID_FILE")
        kill "$server_pid" 2>/dev/null || true
        sleep 1
        kill -9 "$server_pid" 2>/dev/null || true
        rm -f "$SERVER_PID_FILE"
    fi
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

create_test_files() {
    # Create ICO file
    echo "AAABAAEAEBAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAQAABILAAASCwAAAAAAAAAAAAD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==" | base64 -d > favicon.ico
    
    # PNG file
    local PNG_DATA="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg=="
    
    # Test Case 1: PWA Manifest
    mkdir -p manifest-test
    cat > manifest-test/index.html << 'EOF'
<!DOCTYPE html>
<html><head><title>Test</title><link rel="manifest" href="manifest.json"></head><body><h1>Test</h1></body></html>
EOF
    
    cat > manifest-test/manifest.json << 'EOF'
{
  "name": "Test App",
  "icons": [
    {"src": "icon-16.png", "sizes": "16x16", "type": "image/png"},
    {"src": "icon-192.png", "sizes": "192x192", "type": "image/png"},
    {"src": "icon-512.png", "sizes": "512x512", "type": "image/png"}
  ]
}
EOF
    
    echo "$PNG_DATA" | base64 -d > manifest-test/icon-16.png
    echo "$PNG_DATA" | base64 -d > manifest-test/icon-192.png
    echo "$PNG_DATA" | base64 -d > manifest-test/icon-512.png

    # Test Case 2: Apple Touch Icon Priority
    mkdir -p apple-touch-test
    cat > apple-touch-test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Apple Test</title>
    <link rel="icon" href="regular-icon.png" sizes="32x32">
    <link rel="apple-touch-icon" href="apple-touch-icon.png" sizes="180x180">
    <link rel="shortcut icon" href="shortcut-icon.ico">
</head>
<body><h1>Test</h1></body>
</html>
EOF
    
    echo "$PNG_DATA" | base64 -d > apple-touch-test/regular-icon.png
    echo "$PNG_DATA" | base64 -d > apple-touch-test/apple-touch-icon.png
    cp favicon.ico apple-touch-test/shortcut-icon.ico

    # Test Case 3: Regular Link Icons
    mkdir -p link-icon-test
    cat > link-icon-test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Link Test</title>
    <link rel="icon" href="icon-16.png" sizes="16x16">
    <link rel="icon" href="icon-32.png" sizes="32x32">
    <link rel="shortcut icon" href="favicon.ico">
</head>
<body><h1>Test</h1></body>
</html>
EOF
    
    echo "$PNG_DATA" | base64 -d > link-icon-test/icon-16.png
    echo "$PNG_DATA" | base64 -d > link-icon-test/icon-32.png
    cp favicon.ico link-icon-test/favicon.ico

    # Test Case 4: Favicon.ico Fallback
    mkdir -p favicon-fallback-test
    echo '<!DOCTYPE html><html><head><title>Test</title></head><body><h1>Test</h1></body></html>' > favicon-fallback-test/index.html
    cp favicon.ico favicon-fallback-test/favicon.ico

    # Test Case 5: No Icon Available
    mkdir -p no-icon-test
    echo '<!DOCTYPE html><html><head><title>Test</title></head><body><h1>Test</h1></body></html>' > no-icon-test/index.html

    # Test Case 6: Invalid Manifest
    mkdir -p invalid-manifest-test
    cat > invalid-manifest-test/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Invalid Test</title>
    <link rel="manifest" href="invalid-manifest.json">
    <link rel="icon" href="fallback-icon.png">
</head>
<body><h1>Test</h1></body>
</html>
EOF
    
    echo '{"name": "Test App", "icons": "invalid"}' > invalid-manifest-test/invalid-manifest.json
    echo "$PNG_DATA" | base64 -d > invalid-manifest-test/fallback-icon.png
}

# Test functions
assert_url_contains() {
    local url_to_test="$1"
    local expected_substring="$2"
    local description="$3"
    ((TESTS_RUN++))
    
    log_test "Testing '$url_to_test' should contain '$expected_substring' ($description)"
    
    # Quick server check
    if ! curl -s --max-time 2 "$url_to_test" >/dev/null 2>&1; then
        log_fail "Server not responding"
        return
    fi
    
    # Run the script
    run_favicon_script "$url_to_test" "-v"
    
    # Debug: Show what we actually got
    if [ -n "$SCRIPT_OUTPUT" ]; then
        echo "[DEBUG] Full output:" >&2
        echo "$SCRIPT_OUTPUT" | head -10 >&2
        echo "[DEBUG] Final URL extracted: '$SCRIPT_FINAL_URL'" >&2
    fi
    
    if [[ $SCRIPT_EXIT_CODE -eq 0 && -n "$SCRIPT_FINAL_URL" && "$SCRIPT_FINAL_URL" == *"$expected_substring"* ]]; then
        log_pass "Found expected substring: $SCRIPT_FINAL_URL"
    else
        log_fail "Expected '$expected_substring', got: '$SCRIPT_FINAL_URL' (exit: $SCRIPT_EXIT_CODE)"
    fi
}

assert_apple_touch_icon_priority() {
    local url_to_test="$1"
    local description="$2"
    ((TESTS_RUN++))
    
    log_test "Testing apple-touch-icon priority for '$url_to_test' ($description)"
    
    if ! curl -s --max-time 2 "$url_to_test" >/dev/null 2>&1; then
        log_fail "Server not responding"
        return
    fi
    
    run_favicon_script "$url_to_test" "-v"
    
    if [[ $SCRIPT_EXIT_CODE -eq 0 && "$SCRIPT_FINAL_URL" == *"apple-touch-icon"* ]]; then
        log_pass "Apple-touch-icon prioritized: $SCRIPT_FINAL_URL"
    else
        log_fail "Apple-touch-icon not prioritized. Got: '$SCRIPT_FINAL_URL' (exit: $SCRIPT_EXIT_CODE)"
    fi
}

assert_no_url_returned() {
    local url_to_test="$1"
    local description="$2"
    ((TESTS_RUN++))
    
    log_test "Testing '$url_to_test' should return no URL ($description)"
    
    run_favicon_script "$url_to_test"
    
    if [[ $SCRIPT_EXIT_CODE -ne 0 && -z "$SCRIPT_FINAL_URL" ]]; then
        log_pass "No URL returned as expected (exit: $SCRIPT_EXIT_CODE)"
    else
        log_fail "Unexpected result. URL: '$SCRIPT_FINAL_URL' (exit: $SCRIPT_EXIT_CODE)"
    fi
}

# Signal handling
trap cleanup_test_server EXIT INT TERM

# Main execution
echo "Running Truly Final Favicon Extraction Test Suite"
echo "================================================="

# Prerequisites
if [ ! -f "$SCRIPT_TO_TEST" ]; then
    echo -e "${RED}Error: Script not found at '$SCRIPT_TO_TEST'${NC}"
    exit 1
fi

chmod +x "$SCRIPT_TO_TEST" 2>/dev/null

# Check port availability
if lsof -Pi :$TEST_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${RED}Error: Port $TEST_PORT already in use${NC}"
    exit 1
fi

# Setup and run tests
if ! setup_test_server; then
    echo -e "${RED}Failed to set up server${NC}"
    exit 1
fi

# Quick server test
if ! curl -s --max-time 2 "http://$TEST_HOST" >/dev/null 2>&1; then
    echo -e "${RED}Server not responding${NC}"
    exit 1
fi

log_info "Server ready, running tests..."

# Run one test first with debug to see what's happening
echo -e "\n--- Debug Test ---"
assert_url_contains "http://$TEST_HOST/manifest-test/" "icon-512.png" "DEBUG - Largest manifest icon"

echo -e "\n--- All Tests ---"

# PWA Manifest
assert_url_contains "http://$TEST_HOST/manifest-test/" "icon-512.png" "Largest manifest icon selected"

# Apple Touch Icon Priority
assert_apple_touch_icon_priority "http://$TEST_HOST/apple-touch-test/" "Apple-touch-icon over regular icon"

# Regular Link Icons
assert_url_contains "http://$TEST_HOST/link-icon-test/" "icon-32.png" "Larger icon preferred"

# Favicon.ico Fallback
assert_url_contains "http://$TEST_HOST/favicon-fallback-test/" "favicon.ico" "Favicon.ico fallback"

# Invalid Manifest Fallback
assert_url_contains "http://$TEST_HOST/invalid-manifest-test/" "fallback-icon.png" "Fallback after invalid manifest"

# No Icon Available
assert_no_url_returned "http://$TEST_HOST/no-icon-test/" "No icon should fail"

# Results
echo
echo "Test Results:"
echo "============="
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed! 🎉${NC}"
else
    echo -e "\n${RED}Some tests failed. 😞${NC}"
fi