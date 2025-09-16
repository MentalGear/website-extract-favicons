# Extract Favicon From Url
Attempts to return the best favicon's image path by trying `manifest.json`, then `<link rel='icon'>` and finally the default `./favicon.ico` path. If no icon is found, a path to a default icon is proposed.

If nothing is returned, you might want to use a default fallback icon, like `square-dashed` from [lucid icons](https://lucide.dev/icons/square-dashed).

# Make the script executable
chmod +x extract-favicon-from-url.sh

# Basic usage
Returns url of the best image found
./extract-favicon-from-url.sh https://example.com

# Verbose output for Debugging
./extract-favicon-from-url.sh -v https://example.com

# Custom retry settings
./extract-favicon-from-url.sh -r 5 -d 3 https://example.com

# Run tests
chmod +x tests.sh
./tests.sh ./extract-favicon-from-url.sh
