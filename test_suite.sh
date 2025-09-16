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
YELLOW='\033[0;33m'
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

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
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

# New function to test apple-touch-icon priority
assert_apple_touch_icon_preferred() {
    local url_to_test=$1
    local description=$2
    ((TESTS_RUN++))
    log_test "Checking apple-touch-icon priority for '$url_to_test' ($description)"
    
    # Get verbose output to see the decision process
    local full_output
    full_output=$(bash "$SCRIPT_TO_TEST" -v "$url_to_test" 2>&1 || true)
    
    # Extract the final URL (last line that starts with http)
    local final_url
    final_url=$(echo "$full_output" | grep "^http" | tail -n1)
    
    # Check if apple-touch-icon was mentioned in the logs
    if echo "$full_output" | grep -q "apple-touch-icon"; then
        # Check if the debug output shows apple-touch-icon was selected with high priority
        if echo "$full_output" | grep -q "rel=apple-touch-icon.*priority=1[0-5]"; then
            log_pass "Apple-touch-icon correctly prioritized for $url_to_test"
            log_info "Selected URL: $final_url"
        else
            # Fallback: check if any apple-touch-icon related URL was selected
            if [[ "$final_url" == *"apple-touch-icon"* ]] || [[ "$final_url" == *"touch-icon"* ]]; then
                log_pass "Apple-touch-icon URL selected for $url_to_test"
                log_info "Selected URL: $final_url"
            else
                log_info "Debug output for analysis:"
                echo "$full_output" | grep -E "(apple-touch-icon|priority=|Selected)" | head -5
                log_fail "Apple-touch-icon not properly prioritized for $url_to_test"
            fi
        fi
    else
        log_info "No apple-touch-icon found for $url_to_test, checking if regular icons work"
        if [[ -n "$final_url" && "$final_url" == http* ]]; then
            log_pass "Regular icon fallback worked for $url_to_test"
        else
            log_fail "No valid icon found for $url_to_test"
        fi
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
    
    # Category 2b: apple-touch-icon priority test
    echo -e '\n--- Category: <link rel="apple-touch-icon"> prefer over <link rel> ---'
    # notion has apple touch icon and normal rel="link", touch icon should be preferred
    assert_apple_touch_icon_preferred "https://www.notion.com/" "Apple-touch-icon priority test"
    # Additional test sites known to have apple-touch-icons
    assert_apple_touch_icon_preferred "github.com" "GitHub apple-touch-icon test"
    
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