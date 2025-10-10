#!/bin/bash
# Final working test suite - handles all edge cases properly

# Use less strict error handling for the main script
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

# Function to run favicon script and capture output properly
run_favicon_script() {
    local url="$1"
    local verbose="${2:-}"
    
    # Use a temporary file to capture all output
    local temp_output=$(mktemp)
    local exit_code=0
    
    # Run the script and capture everything
    if [ "$verbose" = "-v" ]; then
        bash "$SCRIPT_TO_TEST" -v "$url" > "$temp_output" 2>&1 || exit_code=$?
    else
        bash "$SCRIPT_TO_TEST" "$url" > "$temp_output" 2>&1 || exit_code=$?
    fi
    
    # Get the content
    local full_output=$(cat "$temp_output")
    rm -f "$temp_output"
    
    # Extract the final URL (last line that looks like a URL and isn't a debug line)
    local final_url=$(echo "$full_output" | grep -v '^\[' | grep '^http' | tail -n1 || echo "")
    
    # Return results via global variables (bash doesn't have good return mechanisms for complex data)
    SCRIPT_OUTPUT="$full_output"
    SCRIPT_EXIT_CODE="$exit_code"
    SCRIPT_FINAL_URL="$final_url"
}

# Server management
setup_test_server() {
    log_info "Setting up test server..."
    
    # Stop any existing server
    cleanup_test_server
    
    # Clean up test directory
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    
    # Create test files
    create_test_files
    
    # Start server in background
    cd "$TEST_DIR"
    python3 -m http.server $TEST_PORT >/dev/null 2>&1 &
    local server_pid=$!
    echo $server_pid > "$SERVER_PID_FILE"
    cd ..
    
    # Wait for server to be ready
    local max_attempts=20
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s --max-time 1 "http://$TEST_HOST/" >/dev/null 2>&1; then
            log_info "Test server running on http://$TEST_HOST (PID: $server_pid)"
            return 0
        fi
        sleep 0.5
        ((attempt++))
    done
    
    log_fail "Failed to start test server after $max_attempts attempts"
    return 1
}

cleanup_test_server() {
    if [ -f "$SERVER_PID_FILE" ]; then
        local server_pid=$(cat "$SERVER_PID_FILE")
        if ps -p "$server_pid" >/dev/null 2>&1; then
            kill "$server_pid" 2>/dev/null
            sleep 0.5
            # Force kill if still running
            if ps -p "$server_pid" >/dev/null 2>&1; then
                kill -9 "$server_pid" 2>/dev/null
            fi
            log_info "Test server stopped (PID: $server_pid)"
        fi
        rm -f "$SERVER_PID_FILE"
    fi
    rm -rf "$TEST_DIR" 2>/dev/null || true
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

    # Create invalid JSON structure
    cat > invalid-manifest-test/invalid-manifest.json << 'EOF'
{
  "name": "Test App",
  "icons": "this should be an array not a string"
}
EOF

    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==" | base64 -d > invalid-manifest-test/fallback-icon.png
}

# Test functions
assert_url_contains() {
    local url_to_test="$1"
    local expected_substring="$2"
    local description="$3"
    ((TESTS_RUN++))
    
    log_test "Testing '$url_to_test' should contain '$expected_substring' ($description)"
    
    # Verify server is still running
    if ! curl -s --max-time 2 "$url_to_test" >/dev/null 2>&1; then
        log_fail "Server not responding before test execution"
        return
    fi
    
    # Run the favicon script
    run_favicon_script "$url_to_test" "-v"
    
    if [[ $SCRIPT_EXIT_CODE -eq 0 && -n "$SCRIPT_FINAL_URL" && "$SCRIPT_FINAL_URL" == *"$expected_substring"* ]]; then
        log_pass "Found expected substring: $SCRIPT_FINAL_URL"
    else
        log_fail "Expected substring '$expected_substring' not found. Got: '$SCRIPT_FINAL_URL' (exit: $SCRIPT_EXIT_CODE)"
        # Show some debug output if verbose was captured
        if [[ "$SCRIPT_OUTPUT" == *"ERROR"* ]]; then
            echo "$SCRIPT_OUTPUT" | grep "ERROR" | head -2 >&2 || true
        fi
    fi
}

assert_apple_touch_icon_priority() {
    local url_to_test="$1"
    local description="$2"
    ((TESTS_RUN++))
    
    log_test "Testing apple-touch-icon priority for '$url_to_test' ($description)"
    
    # Verify server is still running
    if ! curl -s --max-time 2 "$url_to_test" >/dev/null 2>&1; then
        log_fail "Server not responding before test execution"
        return
    fi
    
    # Run the favicon script
    run_favicon_script "$url_to_test" "-v"
    
    if [[ $SCRIPT_EXIT_CODE -eq 0 && "$SCRIPT_FINAL_URL" == *"apple-touch-icon"* ]]; then
        log_pass "Apple-touch-icon correctly prioritized: $SCRIPT_FINAL_URL"
    else
        log_fail "Apple-touch-icon not prioritized. Got: '$SCRIPT_FINAL_URL' (exit: $SCRIPT_EXIT_CODE)"
        # Show debug info about icon selection
        echo "$SCRIPT_OUTPUT" | grep -E "(Candidate|Selected|priority)" | head -3 >&2 || true
    fi
}

assert_no_url_returned() {
    local url_to_test="$1"
    local description="$2"
    ((TESTS_RUN++))
    
    log_test "Testing '$url_to_test' should return no URL ($description)"
    
    # Run the favicon script (without -v to reduce noise)
    run_favicon_script "$url_to_test"
    
    if [[ $SCRIPT_EXIT_CODE -ne 0 && -z "$SCRIPT_FINAL_URL" ]]; then
        log_pass "No URL returned as expected (exit code: $SCRIPT_EXIT_CODE)"
    else
        log_fail "Unexpected result. URL: '$SCRIPT_FINAL_URL' (exit: $SCRIPT_EXIT_CODE)"
    fi
}

# Test server connectivity
test_server_connectivity() {
    log_info "Testing server connectivity..."
    
    for attempt in 1 2 3; do
        if curl -s --max-time 2 "http://$TEST_HOST" >/dev/null 2>&1; then
            log_info "Server connectivity verified"
            return 0
        fi
        if [ $attempt -lt 3 ]; then
            log_info "Retry $attempt/3..."
            sleep 1
        fi
    done
    
    log_fail "Server connectivity failed after 3 attempts"
    return 1
}

# Signal handling for cleanup
cleanup_and_exit() {
    local exit_code=$?
    cleanup_test_server
    exit $exit_code
}
trap cleanup_and_exit EXIT INT TERM

# Main test runner
run_tests() {
    echo "Running Final Working Favicon Extraction Test Suite"
    echo "=================================================="
    
    # Verify prerequisites
    if [ ! -f "$SCRIPT_TO_TEST" ]; then
        echo -e "${RED}Error: Script not found at '$SCRIPT_TO_TEST'${NC}"
        return 1
    fi
    
    if [ ! -x "$SCRIPT_TO_TEST" ]; then
        chmod +x "$SCRIPT_TO_TEST" || {
            echo -e "${RED}Error: Cannot make script executable${NC}"
            return 1
        }
    fi
    
    # Check if port is already in use
    if lsof -Pi :$TEST_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}Error: Port $TEST_PORT is already in use${NC}"
        return 1
    fi
    
    # Set up test environment
    if ! setup_test_server; then
        echo -e "${RED}Failed to set up test server${NC}"
        return 1
    fi
    
    # Verify server connectivity
    if ! test_server_connectivity; then
        echo -e "${RED}Server connectivity test failed${NC}"
        return 1
    fi
    
    echo
    echo "Running tests..."
    
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

# Main execution
run_tests