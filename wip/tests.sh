#!/bin/bash

# Test suite

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_SCRIPT="${1:-$SCRIPT_DIR/pwa_icon_finder.sh}"
readonly TEST_TMPDIR="$(mktemp -d)"
readonly MOCK_SERVER_PORT=8888
readonly MOCK_SERVER_PID_FILE="$TEST_TMPDIR/mock_server.pid"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    echo -e "\n${BLUE}Cleaning up...${NC}"
    
    # Kill mock server if running
    if [ -f "$MOCK_SERVER_PID_FILE" ]; then
        local pid
        pid=$(cat "$MOCK_SERVER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            wait "$pid" 2>/dev/null || true
        fi
        rm -f "$MOCK_SERVER_PID_FILE"
    fi
    
    # Clean up test directory
    if [ -d "$TEST_TMPDIR" ]; then
        rm -rf "$TEST_TMPDIR"
    fi
    
    echo -e "${BLUE}Cleanup complete.${NC}"
}

trap cleanup EXIT

# Utility functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
}

# Test assertion functions
assert_equals() {
    local expected=$1
    local actual=$2
    local message=${3:-""}
    
    ((TESTS_RUN++))
    
    if [ "$expected" = "$actual" ]; then
        log_pass "$message"
    else
        log_fail "$message - Expected: '$expected', Got: '$actual'"
        return 1
    fi
}

assert_exit_code() {
    local expected_code=$1
    local actual_code=$2
    local message=${3:-""}
    
    ((TESTS_RUN++))
    
    if [ "$expected_code" -eq "$actual_code" ]; then
        log_pass "$message"
    else
        log_fail "$message - Expected exit code: $expected_code, Got: $actual_code"
        return 1
    fi
}

assert_contains() {
    local haystack=$1
    local needle=$2
    local message=${3:-""}
    
    ((TESTS_RUN++))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        log_pass "$message"
    else
        log_fail "$message - '$haystack' does not contain '$needle'"
        return 1
    fi
}

# Mock HTTP server for testing
start_mock_server() {
    local server_root=$1
    
    # Simple Python HTTP server
    cat > "$TEST_TMPDIR/mock_server.py" << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import sys
import os

class MockHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Suppress logging
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

if __name__ == "__main__":
    port = int(sys.argv[1])
    web_dir = sys.argv[2]
    os.chdir(web_dir)
    
    with socketserver.TCPServer(("", port), MockHTTPRequestHandler) as httpd:
        httpd.serve_forever()
EOF
    
    python3 "$TEST_TMPDIR/mock_server.py" "$MOCK_SERVER_PORT" "$server_root" &
    echo $! > "$MOCK_SERVER_PID_FILE"
    
    # Wait for server to start
    sleep 1
    
    log_info "Mock server started on port $MOCK_SERVER_PORT"
}

# Create test HTML pages and resources
setup_test_resources() {
    local test_root="$TEST_TMPDIR/www"
    mkdir -p "$test_root"
    
    # Test page with full PWA manifest
    mkdir -p "$test_root/pwa-full"
    cat > "$test_root/pwa-full/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <link rel="manifest" href="manifest.json">
    <title>PWA Full Test</title>
</head>
<body>
    <h1>PWA Full Test</h1>
</body>
</html>
EOF
    
    cat > "$test_root/pwa-full/manifest.json" << 'EOF'
{
  "name": "PWA Full Test",
  "icons": [
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
    
    # Create mock icon files
    echo "fake-png-192" > "$test_root/pwa-full/icon-192.png"
    echo "fake-png-512" > "$test_root/pwa-full/icon-512.png"
    
    # Test page with HTML link icons only
    mkdir -p "$test_root/html-icons"
    cat > "$test_root/html-icons/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png">
    <link rel="icon" type="image/png" sizes="16x16" href="favicon-16x16.png">
    <link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png">
    <title>HTML Icons Test</title>
</head>
<body>
    <h1>HTML Icons Test</h1>
</body>
</html>
EOF
    
    echo "fake-favicon-32" > "$test_root/html-icons/favicon-32x32.png"
    echo "fake-favicon-16" > "$test_root/html-icons/favicon-16x16.png"
    echo "fake-apple-touch" > "$test_root/html-icons/apple-touch-icon.png"
    
    # Test page with only favicon.ico
    mkdir -p "$test_root/favicon-only"
    cat > "$test_root/favicon-only/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Favicon Only Test</title>
</head>
<body>
    <h1>Favicon Only Test</h1>
</body>
</html>
EOF
    
    echo "fake-favicon-ico" > "$test_root/favicon-only/favicon.ico"
    
    # Test page with no icons
    mkdir -p "$test_root/no-icons"
    cat > "$test_root/no-icons/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>No Icons Test</title>
</head>
<body>
    <h1>No Icons Test</h1>
</body>
</html>
EOF
    
    # Test page with broken manifest
    mkdir -p "$test_root/broken-manifest"
    cat > "$test_root/broken-manifest/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <link rel="manifest" href="manifest.json">
    <link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png">
    <title>Broken Manifest Test</title>
</head>
<body>
    <h1>Broken Manifest Test</h1>
</body>
</html>
EOF
    
    cat > "$test_root/broken-manifest/manifest.json" << 'EOF'
{
  "name": "Broken Manifest Test"
  // This is invalid JSON due to the comment
}
EOF
    
    echo "fake-favicon-32-broken" > "$test_root/broken-manifest/favicon-32x32.png"
    
    log_info "Test resources created in $test_root"
    start_mock_server "$test_root"
}

# Test functions
test_script_exists() {
    log_test "Testing script existence and executability"
    
    if [ ! -f "$TEST_SCRIPT" ]; then
        log_fail "Script not found: $TEST_SCRIPT"
        return 1
    fi
    
    if [ ! -x "$TEST_SCRIPT" ]; then
        log_fail "Script not executable: $TEST_SCRIPT"
        return 1
    fi
    
    log_pass "Script exists and is executable"
}

test_help_option() {
    log_test "Testing help option"
    
    local output
    local exit_code=0
    output=$("$TEST_SCRIPT" -h 2>&1) || exit_code=$?
    
    assert_exit_code 0 $exit_code "Help option should exit with code 0"
    assert_contains "$output" "Usage:" "Help output should contain usage information"
}

test_invalid_arguments() {
    log_test "Testing invalid arguments"
    
    local exit_code=0
    "$TEST_SCRIPT" 2>/dev/null || exit_code=$?
    assert_exit_code 1 $exit_code "No arguments should exit with code 1"
    
    exit_code=0
    "$TEST_SCRIPT" -z 2>/dev/null || exit_code=$?
    assert_exit_code 1 $exit_code "Invalid option should exit with code 1"
    
    exit_code=0
    "$TEST_SCRIPT" -r abc http://example.com 2>/dev/null || exit_code=$?
    assert_exit_code 1 $exit_code "Invalid retry count should exit with code 1"
    
    exit_code=0
    "$TEST_SCRIPT" -d -1 http://example.com 2>/dev/null || exit_code=$?
    assert_exit_code 1 $exit_code "Negative delay should exit with code 1"
}

test_pwa_with_manifest() {
    log_test "Testing PWA with full manifest"
    
    local url="http://localhost:$MOCK_SERVER_PORT/pwa-full/"
    local output
    local exit_code=0
    
    output=$("$TEST_SCRIPT" "$url" 2>/dev/null) || exit_code=$?
    
    assert_exit_code 0 $exit_code "PWA with manifest should succeed"
    assert_contains "$output" "icon-512.png" "Should select largest icon from manifest"
}

test_html_icons_only() {
    log_test "Testing HTML icons only (no manifest)"
    
    local url="http://localhost:$MOCK_SERVER_PORT/html-icons/"
    local output
    local exit_code=0
    
    output=$("$TEST_SCRIPT" "$url" 2>/dev/null) || exit_code=$?
    
    assert_exit_code 0 $exit_code "HTML icons should succeed"
    assert_contains "$output" "apple-touch-icon.png" "Should prefer apple-touch-icon"
}

test_favicon_fallback() {
    log_test "Testing favicon.ico fallback"
    
    local url="http://localhost:$MOCK_SERVER_PORT/favicon-only/"
    local output
    local exit_code=0
    
    output=$("$TEST_SCRIPT" "$url" 2>/dev/null) || exit_code=$?
    
    assert_exit_code 0 $exit_code "Favicon fallback should succeed"
    assert_contains "$output" "favicon.ico" "Should use favicon.ico as fallback"
}

test_no_icons_found() {
    log_test "Testing page with no icons"
    
    local url="http://localhost:$MOCK_SERVER_PORT/no-icons/"
    local exit_code=0
    
    "$TEST_SCRIPT" "$url" 2>/dev/null || exit_code=$?
    
    assert_exit_code 2 $exit_code "No icons should exit with code 2"
}

test_broken_manifest_fallback() {
    log_test "Testing broken manifest with HTML fallback"
    
    local url="http://localhost:$MOCK_SERVER_PORT/broken-manifest/"
    local output
    local exit_code=0
    
    output=$("TEST_SCRIPT" "$url" 2>/dev/null) || exit_code=$?
    
    assert_exit_code 0 $exit_code "Broken manifest should fall back to HTML icons"
    assert_contains "$output" "favicon-32x32.png" "Should fall back to HTML icons"
}

test_verbose_option() {
    log_test "Testing verbose option"
    
    local url="http://localhost:$MOCK_SERVER_PORT/pwa-full/"
    local output
    local exit_code=0
    
    output=$("$TEST_SCRIPT" -v "$url" 2>&1) || exit_code=$?
    
    assert_exit_code 0 $exit_code "Verbose option should work"
    assert_contains "$output" "[INFO]" "Verbose output should contain info logs"
    assert_contains "$output" "[SUCCESS]" "Verbose output should contain success logs"
}

test_custom_retries_and_delay() {
    log_test "Testing custom retries and delay options"
    
    local url="http://localhost:$MOCK_SERVER_PORT/pwa-full/"
    local output
    local exit_code=0
    
    output=$("$TEST_SCRIPT" -r 1 -d 1 "$url" 2>/dev/null) || exit_code=$?
    
    assert_exit_code 0 $exit_code "Custom retries and delay should work"
}

test_nonexistent_url() {
    log_test "Testing nonexistent URL"
    
    local url="http://localhost:99999/nonexistent/"
    local exit_code=0
    
    "$TEST_SCRIPT" -r 1 "$url" 2>/dev/null || exit_code=$?
    
    assert_exit_code 3 $exit_code "Nonexistent URL should exit with code 3"
}

# Test runner
run_all_tests() {
    log_info "Starting Extract Favicon From Url test suite"
    log_info "Testing script: $TEST_SCRIPT"
    
    # Setup
    setup_test_resources
    
    # Run tests
    test_script_exists
    test_help_option
    test_invalid_arguments
    test_pwa_with_manifest
    test_html_icons_only
    test_favicon_fallback
    test_no_icons_found
    test_broken_manifest_fallback
    test_verbose_option
    test_custom_retries_and_delay
    test_nonexistent_url
    
    # Report results
    echo
    log_info "Test Results:"
    log_info "Tests run: $TESTS_RUN"
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
main() {
    echo "Extract Favicon From Url Test Suite"
    echo "=========================="
    
    # Check dependencies
    for cmd in python3 curl xmllint jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${RED}Error: Required command '$cmd' not found${NC}"
            exit 1
        fi
    done
    
    if [ ! -f "$TEST_SCRIPT" ]; then
        echo -e "${RED}Error: Test script not found: $TEST_SCRIPT${NC}"
        echo "Usage: $0 [path_to_pwa_icon_finder.sh]"
        exit 1
    fi
    
    # Make script executable if it isn't already
    chmod +x "$TEST_SCRIPT"
    
    # Run tests
    if run_all_tests; then
        exit 0
    else
        exit 1
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi