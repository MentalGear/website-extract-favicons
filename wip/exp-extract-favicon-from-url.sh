#!/bin/bash
set -euo pipefail

# Finds the best available icon for a Website / PWA

# Configuration
readonly DEFAULT_RETRIES=3
readonly DEFAULT_DELAY=2
readonly USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

# Global variables
VERBOSE=0
RETRIES=$DEFAULT_RETRIES
DELAY=$DEFAULT_DELAY
TMPDIR=""

# Cleanup function
cleanup() {
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
    fi
}

# Logging function
log() {
    local level=$1
    shift
    case $level in
        DEBUG)
            [ "$VERBOSE" -eq 1 ] && echo "[DEBUG] $*" >&2
            ;;
        INFO)
            [ "$VERBOSE" -eq 1 ] && echo "[INFO] $*" >&2
            ;;
        WARN)
            echo "[WARN] $*" >&2
            ;;
        ERROR)
            echo "[ERROR] $*" >&2
            ;;
        SUCCESS)
            [ "$VERBOSE" -eq 1 ] && echo "[SUCCESS] $*" >&2
            ;;
    esac
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [-v] [-r RETRIES] [-d DELAY] <PWA_URL>

Options:
    -v              Enable verbose output
    -r RETRIES      Number of retry attempts (default: $DEFAULT_RETRIES)
    -d DELAY        Delay between retries in seconds (default: $DEFAULT_DELAY)
    -h              Show this help message

Arguments:
    PWA_URL         The URL of the Progressive Web App

Exit codes:
    0               Success - icon URL printed to stdout
    1               Invalid arguments or setup failure
    2               No icon found after trying all methods
    3               Network/fetch failure
EOF
}

# Parse command line arguments
parse_arguments() {
    while getopts "vr:d:h" opt; do
        case $opt in
            v) VERBOSE=1 ;;
            r) RETRIES="$OPTARG" ;;
            d) DELAY="$OPTARG" ;;
            h) usage; exit 0 ;;
            *) usage; exit 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    if [ $# -lt 1 ]; then
        log ERROR "Missing required PWA_URL argument"
        usage
        exit 1
    fi

    # Validate numeric arguments
    if ! [[ "$RETRIES" =~ ^[0-9]+$ ]] || [ "$RETRIES" -lt 1 ]; then
        log ERROR "RETRIES must be a positive integer"
        exit 1
    fi

    if ! [[ "$DELAY" =~ ^[0-9]+$ ]] || [ "$DELAY" -lt 0 ]; then
        log ERROR "DELAY must be a non-negative integer"
        exit 1
    fi

    echo "$1"
}

# Initialize temporary directory
init_tmpdir() {
    TMPDIR=$(mktemp -d)
    trap cleanup EXIT
    log DEBUG "Created temporary directory: $TMPDIR"
}

# Fetch URL with retries
fetch_with_retries() {
    local url=$1
    local outfile=$2
    local attempt=1

    while [ $attempt -le $RETRIES ]; do
        log DEBUG "Attempt $attempt: fetching $url"
        
        if curl -sSL -A "$USER_AGENT" "$url" -o "$outfile" 2>/dev/null; then
            if [ -s "$outfile" ]; then
                log DEBUG "Successfully fetched $url"
                return 0
            else
                log DEBUG "Fetched empty file from $url"
            fi
        else
            log DEBUG "curl failed for $url"
        fi
        
        if [ $attempt -lt $RETRIES ]; then
            log DEBUG "Retry in $DELAY seconds..."
            sleep "$DELAY"
        fi
        attempt=$((attempt + 1))
    done
    
    log WARN "Failed to fetch $url after $RETRIES attempts"
    return 1
}

# Resolve relative URL to absolute URL
resolve_url() {
    local base_url=$1
    local relative_url=$2
    python3 -c "import urllib.parse; print(urllib.parse.urljoin('$base_url', '$relative_url'))"
}

# Extract manifest URL from HTML
extract_manifest_url() {
    local html_file=$1
    local base_url=$2
    
    local manifest_href
    manifest_href=$(xmllint --html --xpath \
        'string(//link[translate(@rel,"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz")="manifest"]/@href)' \
        "$html_file" 2>/dev/null || true)
    
    if [ -n "$manifest_href" ]; then
        resolve_url "$base_url" "$manifest_href"
    fi
}

# Find best icon from manifest
find_manifest_icon() {
    local manifest_file=$1
    local manifest_url=$2
    
    if [ ! -f "$manifest_file" ]; then
        return 1
    fi
    
    local icon_src
    icon_src=$(jq -r '
        if .icons then
            .icons
            | map(select(.src != null and .src != ""))
            | map(.sizes as $sizes |
                ($sizes | split(" ") | map(tonumber? // 0) | max) as $maxsize |
                {src, maxsize})
            | sort_by(.maxsize) | reverse | .[0].src
        else empty end' "$manifest_file" 2>/dev/null || true)
    
    if [ -n "$icon_src" ] && [ "$icon_src" != "null" ]; then
        resolve_url "$manifest_url" "$icon_src"
        return 0
    fi
    
    return 1
}

# Extract and parse HTML link icons
extract_html_icons() {
    local html_file=$1
    local base_url=$2
    local icons_list_file=$3
    
    # Extract link elements with icon-related rel attributes
    if ! xmllint --html --xpath \
        '//link[contains(translate(@rel,"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz"),"icon")]' \
        "$html_file" 2>/dev/null > "$TMPDIR/raw_links.xml"; then
        return 1
    fi
    
    # Parse the extracted links
    awk '
        {
            rel=""; href=""; sizes="";
            line=$0
            while (match(line, /(rel|href|sizes)="[^"]*"/, m)) {
                attr=m[1]
                val=substr(m[0], length(attr)+3, length(m[0])-(length(attr)+3))
                if (attr=="rel")   { rel=val }
                if (attr=="href")  { href=val }
                if (attr=="sizes") { sizes=val }
                line=substr(line, RSTART+RLENGTH)
            }
            if (rel && href) {
                sizeval=0
                if (sizes ~ /^[0-9]+x[0-9]+$/) {
                    split(sizes,a,"x"); sizeval=a[1]
                }
                # Prioritize apple-touch-icon
                prio=(index(tolower(rel),"apple-touch-icon") ? 1 : 0)
                print prio "\t" sizeval "\t" href "\t" rel
            }
        }' "$TMPDIR/raw_links.xml" | sort -t$'\t' -k1,1nr -k2,2nr > "$icons_list_file"
    
    [ -s "$icons_list_file" ]
}

# Find best HTML icon
find_html_icon() {
    local html_file=$1
    local base_url=$2
    
    local icons_list_file="$TMPDIR/icons_list.txt"
    
    if ! extract_html_icons "$html_file" "$base_url" "$icons_list_file"; then
        log DEBUG "No HTML link icons found"
        return 1
    fi
    
    if [ "$VERBOSE" -eq 1 ]; then
        while IFS=$'\t' read -r priority size href rel; do
            log DEBUG "Icon candidate: rel=$rel href=$href size=$size priority=$priority"
        done < "$icons_list_file"
    fi
    
    local best_icon_href
    best_icon_href=$(head -n1 "$icons_list_file" | cut -f3)
    
    if [ -n "$best_icon_href" ]; then
        resolve_url "$base_url" "$best_icon_href"
        return 0
    fi
    
    return 1
}

# Try favicon.ico fallback
find_favicon_fallback() {
    local base_url=$1
    
    local favicon_url
    favicon_url=$(python3 -c "
import urllib.parse
u = urllib.parse.urlparse('$base_url')
print(f'{u.scheme}://{u.netloc}/favicon.ico')
")
    
    if fetch_with_retries "$favicon_url" "$TMPDIR/favicon.ico"; then
        if [ -s "$TMPDIR/favicon.ico" ]; then
            echo "$favicon_url"
            return 0
        fi
    fi
    
    return 1
}

# Main icon finding logic
find_pwa_icon() {
    local url=$1
    local html_file="$TMPDIR/page.html"
    local icon_url=""
    
    # Fetch the main page
    log INFO "Fetching page: $url"
    if ! fetch_with_retries "$url" "$html_file"; then
        log ERROR "Failed to fetch page after $RETRIES attempts"
        return 3
    fi
    
    # Step 1: Try manifest.json
    log INFO "Searching for PWA manifest..."
    local manifest_url
    manifest_url=$(extract_manifest_url "$html_file" "$url")
    
    if [ -n "$manifest_url" ]; then
        log INFO "Found manifest URL: $manifest_url"
        local manifest_file="$TMPDIR/manifest.json"
        
        if fetch_with_retries "$manifest_url" "$manifest_file"; then
            if icon_url=$(find_manifest_icon "$manifest_file" "$manifest_url"); then
                log INFO "Selected icon from manifest: $icon_url"
                echo "$icon_url"
                return 0
            else
                log WARN "No suitable icons found in manifest"
            fi
        else
            log WARN "Could not fetch manifest"
        fi
    else
        log INFO "No PWA manifest found"
    fi
    
    # Step 2: Try HTML <link rel="icon"> elements
    log INFO "Searching HTML link elements..."
    if icon_url=$(find_html_icon "$html_file" "$url"); then
        log INFO "Selected HTML icon: $icon_url"
        echo "$icon_url"
        return 0
    else
        log WARN "No suitable HTML link icons found"
    fi
    
    # Step 3: Try favicon.ico fallback
    log INFO "Trying favicon.ico fallback..."
    if icon_url=$(find_favicon_fallback "$url"); then
        log INFO "Using favicon.ico: $icon_url"
        echo "$icon_url"
        return 0
    else
        log WARN "favicon.ico not found or empty"
    fi
    
    # No icon found
    log ERROR "No PWA icon found using any method"
    return 2
}

# Main function
main() {
    local url
    url=$(parse_arguments "$@")
    
    # Check dependencies
    for cmd in curl xmllint jq python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log ERROR "Required command '$cmd' not found"
            exit 1
        fi
    done
    
    init_tmpdir
    
    local icon_url
    local exit_code
    
    if icon_url=$(find_pwa_icon "$url"); then
        log SUCCESS "Found PWA icon"
        echo "$icon_url"
        exit_code=0
    else
        exit_code=$?
    fi
    
    return $exit_code
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi