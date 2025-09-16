#!/bin/bash

# Test suite for favicon extraction

set -euo pipefail

# Configuration
readonly SCRIPT_TO_TEST="./extract-favicon-from-url.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

assert_url_returned() {
    local url_to_test=$1
    local description=$2
    
    ((TESTS_RUN++))
    log_test "Checking '$url_to_test' ($description)"
    
    local output
    output=$(bash "$SCRIPT_TO_TEST" -v "$url_to_test")
    
    if [[ -n "$output" && "$output" == http* ]]; then
        log_pass "URL returned for $url_to_test: $output"
    else
        log_fail "No valid URL returned for $url_to_test"
    fi
}

assert_no_url_returned() {
    local url_to_test=$1
    local description=$2
    
    ((TESTS_RUN++))
    log_test "Checking '$url_to_test' ($description)"
    
    local output
    output=$(bash "$SCRIPT_TO_TEST" -v "$url_to_test" 2>/dev/null || true)
    
    if [[ -z "$output" ]]; then
        log_pass "No URL returned for $url_to_test as expected"
    else
        log_fail "A URL was unexpectedly returned for $url_to_test: $output"
    fi
}

# Test runner
run_tests() {
    echo "Running Favicon Extraction Test Suite"
    echo "====================================="
    
    # Category 1: has PWA manifest
    echo -e "\n--- Category: Has PWA manifest ---"
    assert_url_returned "theguardian.com" "PWA manifest"
    assert_url_returned "ft.com" "PWA manifest"
    # TODO: Test fails since spotify, even though it has a manifest, the code does not seem to be able to extract the icon path. Why not?
    # debug: manually curl each manifest for ft.com and spotify.com and compare them
    assert_url_returned "spotify.com" "PWA manifest"
    
    # Category 2: has <link rel>
    echo -e "\n--- Category: <link rel> ---"
    assert_url_returned "notion.so" "<link rel>"
    assert_url_returned "meetup.com" "<link rel>"
    
    # Category 3: has favicon.ico
    echo -e "\n--- Category: favicon.ico ---"
    assert_url_returned "google.com" "favicon.ico"
    
    # Category 4: does NOT even a favicon.ico present
    echo -e "\n--- Category: No Icon available ---"
    # TODO: check tests
    assert_no_url_returned "example.com" "Invalid favicon.ico (text/html)"
    assert_url_returned "gmail.com" "favicon.ico"

    # Report results
    echo
    echo "Test Results:"
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
if [ ! -f "$SCRIPT_TO_TEST" ]; then
    echo -e "${RED}Error: Script to test not found at '$SCRIPT_TO_TEST'${NC}"
    exit 1
fi

chmod +x "$SCRIPT_TO_TEST"

run_tests
