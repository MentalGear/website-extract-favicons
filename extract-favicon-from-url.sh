#!/bin/bash
set -euo pipefail

VERBOSE=0
RETRIES=3
DELAY=2

while getopts "v" opt; do
  case $opt in
    v) VERBOSE=1 ;;
    *) echo "Usage: $0 [-v] <WEBSITE_URL>"; exit 1 ;;
  esac
done
shift $((OPTIND -1))

if [ $# -lt 1 ]; then
  echo "Usage: $0 [-v] <WEBSITE_URL>"
  exit 1
fi

URL="$1"
if [[ ! "$URL" == http* ]]; then
  URL="https://"$URL
fi
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$*" >&2
  fi
}

fetch_with_retries() {
  local url=$1
  local outfile=$2
  local attempt=1
  while [ $attempt -le $RETRIES ]; do
    log "[DEBUG] Attempt $attempt: fetching $url"
    # Standard curl builds often don't decompress content unless you tell them to. Browsers, on the other hand, always handle decompression.
    # A common way to ask curl to handle decompression is to add the --compressed flag. This will make curl request compressed content and decompress it automatically if the server sends it.
    if curl -sSL --compressed -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36" \
      "$url" -o "$outfile"; then
      if [ -s "$outfile" ]; then
        return 0
      fi
    fi
    log "[WARN] Retry in $DELAY seconds..."
    sleep $DELAY
    attempt=$((attempt+1))
  done
  return 1
}

log "[INFO] Fetching page: $URL"
if ! fetch_with_retries "$URL" "$TMPDIR/page.html"; then
  echo "[ERROR] Failed to fetch page after $RETRIES attempts"
  exit 1
fi

ICON_URL=""

# --- Step 1: Manifest ---
log "[INFO] Trying manifest.json..."
MANIFEST_HREF=$(xmllint --html --xpath \
  'string(//link[translate(@rel,"ABCDEFGHIJKLMNOPQRSTUVWXYZ","abcdefghijklmnopqrstuvwxyz")="manifest"]/@href)' \
  "$TMPDIR/page.html" 2>/dev/null || true)

if [ -n "$MANIFEST_HREF" ]; then
  MANIFEST_URL=$(python3 -c "import urllib.parse; print(urllib.parse.urljoin('$URL','$MANIFEST_HREF'))")
  log "[INFO] Found manifest URL: $MANIFEST_URL"

  if fetch_with_retries "$MANIFEST_URL" "$TMPDIR/manifest.json"; then
    if [ "$VERBOSE" -eq 1 ]; then
      if ! jq -e . "$TMPDIR/manifest.json" >/dev/null 2>&1; then
        log "[DEBUG] Manifest is not valid JSON. Content:"
        log "---"
        cat "$TMPDIR/manifest.json" >&2
        log "---"
      fi
    fi
    ICON_SRC=$( (
      if [ "$VERBOSE" -eq 1 ]; then
        jq -r '.icons[] | [.sizes, .src] | @tsv' "$TMPDIR/manifest.json" || true
      else
        jq -r '.icons[] | [.sizes, .src] | @tsv' "$TMPDIR/manifest.json" 2>/dev/null || true
      fi
    ) |
    awk -F'\t' '{ size = $1; sub(/x.*/, "", size); if (size == "any") size = 99999; print size "\t" $2 }' |
    sort -rn | head -n1 | cut -f2
    )

    if [ -n "$ICON_SRC" ] && [ "$ICON_SRC" != "null" ]; then
      ICON_URL=$(python3 -c "import urllib.parse; print(urllib.parse.urljoin('$MANIFEST_URL','$ICON_SRC'))")
      log "[INFO] Selected icon from manifest: $ICON_URL"
    else
      log "[WARN] No icons array found in manifest"
    fi
  else
    log "[WARN] Could not fetch manifest after retries"
  fi
else
  log "[INFO] No <link rel=manifest> found in HTML"
fi
log "[DEBUG] ICON_URL after manifest step: $ICON_URL"

# --- Step 2: HTML <link rel=icon/...> ---
if [ -z "$ICON_URL" ]; then
  log "[INFO] Trying HTML <link rel=icon> ..."
  # New attribute extraction logic will go here


  if [ -s "$TMPDIR/icons_list.txt" ]; then
    while IFS=$'\t' read -r P S H R; do
      log "[DEBUG] Candidate rel=$R href=$H size=$S priority=$P"
    done < "$TMPDIR/icons_list.txt"

    ICON_HREF=$(head -n1 "$TMPDIR/icons_list.txt" | cut -f3)
    ICON_URL=$(python3 -c "import urllib.parse; print(urllib.parse.urljoin('$URL','$ICON_HREF'))")
    log "[INFO] Selected HTML icon: $ICON_URL"
  else
    log "[WARN] No <link rel=icon> elements found"
  fi
fi
log "[DEBUG] ICON_URL after HTML rel=icon step: $ICON_URL"

# --- Step 3: Favicon.ico ---
if [ -z "$ICON_URL" ]; then
  log "[INFO] Trying fallback /favicon.ico"
  BASE_URL=$(python3 - <<EOF
import urllib.parse
u=urllib.parse.urlparse('$URL')
print(f"{u.scheme}://{u.netloc}/favicon.ico")
EOF
)
  if fetch_with_retries "$BASE_URL" "$TMPDIR/favicon.ico"; then
    if [ -s "$TMPDIR/favicon.ico" ]; then
      MIME_TYPE=$(file --mime-type -b "$TMPDIR/favicon.ico")
      log "[DEBUG] Favicon MIME type: $MIME_TYPE"
      if [[ "$MIME_TYPE" == "image/x-icon" || "$MIME_TYPE" == "image/vnd.microsoft.icon" || "$MIME_TYPE" == "image/x-ico" ]]; then
        ICON_URL="$BASE_URL"
        log "[INFO] Using /favicon.ico: $ICON_URL"
      else
        log "[ERROR] /favicon.ico is not a valid icon file (MIME type: $MIME_TYPE)"
      fi
    fi
  else
    log "[ERROR] /favicon.ico not found or empty"
  fi
fi
log "[DEBUG] ICON_URL after default favicon.ico path step: $ICON_URL"


# --- Result ---
if [ -z "$ICON_URL" ]; then
  log "[ERROR] No Website icon found."
  # error out
  exit 2
fi

log "[SUCCESS] Final icon URL:"
echo "$ICON_URL"
