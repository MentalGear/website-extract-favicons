#!/bin/bash
# Minimal favicon extraction script for debugging

set -euo pipefail

VERBOSE=0
if [ "${1:-}" = "-v" ]; then
    VERBOSE=1
    shift
fi

if [ $# -lt 1 ]; then
    echo "Usage: $0 [-v] <URL>"
    exit 1
fi

URL="$1"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

log() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "[DEBUG] $*" >&2
    fi
}

log "Starting favicon extraction for: $URL"

# Fetch the page
log "Fetching page..."
if ! curl -sSL "$URL" -o "$TMPDIR/page.html"; then
    log "Failed to fetch page"
    exit 1
fi

log "Page fetched successfully"

# Try to find manifest
log "Looking for manifest..."
MANIFEST_HREF=""
if command -v xmllint >/dev/null 2>&1; then
    MANIFEST_HREF=$(xmllint --html --xpath 'string(//link[@rel="manifest"]/@href)' "$TMPDIR/page.html" 2>/dev/null || true)
fi

log "Manifest href: '$MANIFEST_HREF'"

if [ -n "$MANIFEST_HREF" ]; then
    # Build full manifest URL
    MANIFEST_URL=$(python3 -c "
import urllib.parse
print(urllib.parse.urljoin('$URL', '$MANIFEST_HREF'))
")
    
    log "Manifest URL: $MANIFEST_URL"
    
    # Fetch manifest
    if curl -sSL "$MANIFEST_URL" -o "$TMPDIR/manifest.json"; then
        log "Manifest fetched successfully"
        
        if command -v jq >/dev/null 2>&1; then
            # Simple jq approach
            LARGEST_ICON=$(jq -r '
                .icons 
                | map(select(.src != null))
                | sort_by((.sizes | split("x")[0] | tonumber? // 16))
                | reverse 
                | .[0].src' "$TMPDIR/manifest.json" 2>/dev/null || echo "")
            
            log "Largest icon from manifest: '$LARGEST_ICON'"
            
            if [ -n "$LARGEST_ICON" ] && [ "$LARGEST_ICON" != "null" ]; then
                ICON_URL=$(python3 -c "
import urllib.parse
print(urllib.parse.urljoin('$MANIFEST_URL', '$LARGEST_ICON'))
")
                log "Final icon URL: $ICON_URL"
                echo "$ICON_URL"
                exit 0
            fi
        else
            log "jq not available, skipping manifest parsing"
        fi
    else
        log "Failed to fetch manifest"
    fi
fi

# Fallback to HTML link tags
log "Looking for HTML link icons..."
if command -v xmllint >/dev/null 2>&1; then
    ICON_HREF=$(xmllint --html --xpath 'string(//link[@rel="icon"]/@href)' "$TMPDIR/page.html" 2>/dev/null || true)
    if [ -n "$ICON_HREF" ]; then
        ICON_URL=$(python3 -c "
import urllib.parse
print(urllib.parse.urljoin('$URL', '$ICON_HREF'))
")
        log "Found HTML icon: $ICON_URL"
        echo "$ICON_URL"
        exit 0
    fi
fi

# Fallback to favicon.ico
log "Trying favicon.ico fallback..."
BASE_URL=$(python3 -c "
import urllib.parse
u = urllib.parse.urlparse('$URL')
print(f'{u.scheme}://{u.netloc}/favicon.ico')
")

if curl -sSL --head "$BASE_URL" >/dev/null 2>&1; then
    log "Found favicon.ico: $BASE_URL"
    echo "$BASE_URL"
    exit 0
fi

log "No icon found"
exit 2