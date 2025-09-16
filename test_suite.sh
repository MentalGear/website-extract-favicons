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
    output=$(bash "$SCRIPT_TO_TEST" -v "$url_to_test" || true)
    
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
# ========================================================================
# NOTE: External Website's favicon settings can of course change icons at will
# but it can still be a good test for the moment, just ensure after some time
# that the outputs of websites are still what the test expects
# ========================================================================

run_tests() {
    echo "Running Favicon Extraction Test Suite"
    echo "====================================="
    
    # Temporarily disable -e to allow all tests to run
    set +e

    # Category 1: has PWA manifest
    echo -e "\n--- Category: Has PWA manifest ---"
    assert_url_returned "theguardian.com" "PWA manifest"
    assert_url_returned "ft.com" "PWA manifest"
    # spotify as an example of a compressed manifest file
    assert_url_returned "spotify.com" "PWA manifest"
    
    # Category 2: has <link rel>
    echo -e "\n--- Category: <link rel> ---"
    assert_url_returned "meetup.com" "<link rel>"
    
    # Category 2: has <link rel>
    echo -e '\n--- Category: <link rel="apple-touch-icon"> prefer over <link rel>  ---'
    # notion has apple touch icon and normal rel="link", touch icon should be preferred
    # TODO: Write test that ensures apple-touch-icon is preferred
    assert_url_returned "https://www.notion.com/" "<link rel>"
    

    # Category 3: has favicon.ico
    echo -e "\n--- Category: favicon.ico ---"
    assert_url_returned "google.com" "favicon.ico"
    assert_url_returned "apple.com" "favicon.ico"
    assert_url_returned "meetup.com" "favicon.ico"
    

    # Category 4: does NOT even a favicon.ico present
    echo -e "\n--- Category: No Icon available, should exit none zero ---"
    assert_no_url_returned "example.com" "Invalid favicon.ico (text/html)"
    assert_no_url_returned "gmail.com" "favicon.ico"

    # Re-enable -e
    set -e

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
