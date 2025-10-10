#!/bin/bash
# Diagnostic script to check script execution issues

echo "=== Script Execution Diagnostic ==="

# Check if the script exists
SCRIPT_PATH="./extract-favicon-from-url.sh"
echo "1. Checking if script exists:"
if [ -f "$SCRIPT_PATH" ]; then
    echo "✓ Script exists at $SCRIPT_PATH"
    ls -la "$SCRIPT_PATH"
else
    echo "✗ Script not found at $SCRIPT_PATH"
    echo "Files in current directory:"
    ls -la
    exit 1
fi

# Check if script is executable
echo
echo "2. Checking script permissions:"
if [ -x "$SCRIPT_PATH" ]; then
    echo "✓ Script is executable"
else
    echo "✗ Script is not executable"
    echo "Making executable..."
    chmod +x "$SCRIPT_PATH"
    if [ -x "$SCRIPT_PATH" ]; then
        echo "✓ Script is now executable"
    else
        echo "✗ Failed to make script executable"
    fi
fi

# Check script content
echo
echo "3. Checking script shebang and first few lines:"
head -3 "$SCRIPT_PATH"

# Check required tools
echo
echo "4. Checking required tools:"
for tool in bash curl xmllint jq python3; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✓ $tool: $(which $tool)"
    else
        echo "✗ $tool: not found"
    fi
done

# Try to execute the script directly
echo
echo "5. Trying to execute script directly:"
echo "Command: bash $SCRIPT_PATH --help"
bash "$SCRIPT_PATH" --help 2>&1 || {
    echo "Script execution failed with exit code: $?"
}

echo
echo "6. Trying with explicit bash:"
echo "Command: /bin/bash $SCRIPT_PATH --help"
/bin/bash "$SCRIPT_PATH" --help 2>&1 || {
    echo "Explicit bash execution failed with exit code: $?"
}

# Check if we can execute with timeout
echo
echo "7. Testing timeout command:"
if command -v timeout >/dev/null 2>&1; then
    echo "✓ timeout command available"
    timeout 5 echo "timeout test works"
else
    echo "✗ timeout command not available"
    echo "This might be the issue on macOS. Let's check gtimeout:"
    if command -v gtimeout >/dev/null 2>&1; then
        echo "✓ gtimeout available (GNU timeout)"
    else
        echo "✗ gtimeout not available either"
        echo "You may need to install coreutils: brew install coreutils"
    fi
fi

echo
echo "=== End Diagnostic ==="