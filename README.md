# NOTE

had the LLM add a convert to png function build in, but actually out of scope for library so I'll just leave it in a subbranch

# Extract Favicon From Url
CLI shell script attempting to extract the highest resolution favicon URL from a given website, by checking the following in order:

*   `manifest.json` (choses the highest resolution in PWA manifest)
*   `<link rel='apple-touch-icon'>`
*   `<link rel='icon'>`
*   The default `./favicon.ico` path

Finally, if no favicon is found through these methods, it will exit with a none zero code.

## Open Tasks
[ ] add option to convert returned image to a .png
[ ] fix deterministic local tests with own server, as in /wip_local_test

## Usage
### Setup: Make the script executable

`chmod +x extract-favicon-from-url.sh`

### Basic usage
Return URL of the best image found

`./extract-favicon-from-url.sh https://theguardian.com`

### Verbose output for Debugging
`./extract-favicon-from-url.sh -v https://theguardian.com`

### Custom retry settings
`./extract-favicon-from-url.sh -r 5 -d 3 https://example.com`

### Run tests

*Note: websites might change their icon settings which could make the tests fail*

`bash ./tests_web.sh`

or
`chmod +x tests.sh`
then run it