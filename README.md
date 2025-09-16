# Extract Favicon From Url
This script attempts to extract the highest resolution favicon URL from a given website by checking the following in order:

*   `manifest.json` for web app manifests.
*   `<link rel='apple-touch-icon'>`
*   `<link rel='icon'>`
*   The default `./favicon.ico` path

If no favicon is found through these methods, it will exit with a none zero code.

(so if nothing is returned, you might want to use a default fallback icon, like `square-dashed` from [lucid icons](https://lucide.dev/icons/square-dashed).)

## Open Tasks
[ ] should prioritize `<link rel="apple-touch-icon">` over normal `<link rel=icon/...>`

[ ] check why notion.com is not working


## Usage

### Make the script executable

`chmod +x extract-favicon-from-url.sh`

### Basic usage
Return URL of the best image found

`./extract-favicon-from-url.sh https://theguardian.com`

### Verbose output for Debugging
`./extract-favicon-from-url.sh -v https://theguardian.com`

### Custom retry settings
`./extract-favicon-from-url.sh -r 5 -d 3 https://example.com`

### Run tests
`bash ./tests.sh`

or
`chmod +x tests.sh`
then run it