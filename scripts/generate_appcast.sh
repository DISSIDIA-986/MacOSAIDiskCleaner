#!/bin/bash
#
# generate_appcast.sh
# MacOSAIDiskCleaner Sparkle Appcast Generator
#
# Usage: ./scripts/generate_appcast.sh <version> <dmg_path> <private_key_path>
#
# This script generates a Sparkle-compatible appcast.xml file for the MacOSAIDiskCleaner app.
# It signs the DMG using the provided EdDSA private key and creates an RSS feed entry.
#
# Requirements:
# - Sparkle sign_update tool (from https://github.com/sparkle-project/Sparkle/releases)
# - Private EdDSA key file
# - Valid DMG file
#
# Example:
#   ./scripts/generate_appcast.sh "0.1.0" "build/MacOSAIDiskCleaner-0.1.0.dmg" "~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem"

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GITHUB_PAGES_URL="https://dissidia-986.github.io/MacOSAIDiskCleaner"
GITHUB_RELEASES_URL="https://github.com/DISSIDIA-986/MacOSAIDiskCleaner/releases"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate arguments
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <version> <dmg_path> [private_key_path]"
    echo ""
    echo "Arguments:"
    echo "  version        - Version string (e.g., '0.1.0')"
    echo "  dmg_path       - Path to DMG file"
    echo "  private_key_path - Path to EdDSA private key (optional, defaults to SPARKLE_PRIVATE_KEY env var)"
    echo ""
    echo "Example:"
    echo "  $0 0.1.0 build/MacOSAIDiskCleaner-0.1.0.dmg ~/.sparkle_keys/MacOSAIDiskCleaner_private_key.pem"
    exit 1
fi

VERSION="$1"
DMG_PATH="$2"
PRIVATE_KEY_PATH="${3:-${SPARKLE_PRIVATE_KEY:-}}"

# Validate DMG file exists
if [ ! -f "$DMG_PATH" ]; then
    log_error "DMG file not found: $DMG_PATH"
    exit 1
fi

# Get DMG file size
DMG_SIZE=$(stat -f%z "$DMG_PATH" 2>/dev/null || stat -c%s "$DMG_PATH" 2>/dev/null)
if [ -z "$DMG_SIZE" ]; then
    log_error "Failed to get DMG file size"
    exit 1
fi

log_info "DMG file: $DMG_PATH"
log_info "Version: $VERSION"
log_info "File size: $DMG_SIZE bytes"

# Find sign_update tool
SIGN_UPDATE_TOOL=""
if command -v sign_update &> /dev/null; then
    SIGN_UPDATE_TOOL=$(command -v sign_update)
    log_info "Using sign_update from PATH"
else
    # Try to find in common locations
    POSSIBLE_PATHS=(
        "/usr/local/bin/sign_update"
        "$HOME/bin/sign_update"
        "./Sparkle/bin/sign_update"
    )

    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$path" ]; then
            SIGN_UPDATE_TOOL="$path"
            log_info "Found sign_update at: $path"
            break
        fi
    done
fi

if [ -z "$SIGN_UPDATE_TOOL" ]; then
    log_error "sign_update tool not found!"
    echo ""
    echo "Please install Sparkle signing tools:"
    echo "  1. Download: https://github.com/sparkle-project/Sparkle/releases"
    echo "  2. Extract: tar xf Sparkle-*.tar.xz"
    echo "  3. Install: sudo cp Sparkle/bin/sign_update /usr/local/bin/"
    exit 1
fi

# Resolve private key path
if [ -z "$PRIVATE_KEY_PATH" ]; then
    log_error "Private key path not provided"
    echo "Set SPARKLE_PRIVATE_KEY environment variable or provide as third argument"
    exit 1
fi

# Check if PRIVATE_KEY_PATH is an environment variable or file path
if [ -f "$PRIVATE_KEY_PATH" ] || [ "$PRIVATE_KEY_PATH" = "${SPARKLE_PRIVATE_KEY:-}" ]; then
    # It's a file path or we need to create temp file from env var
    if [ -f "$PRIVATE_KEY_PATH" ]; then
        PRIVATE_KEY_FILE="$PRIVATE_KEY_PATH"
    else
        # Create temporary file from environment variable
        PRIVATE_KEY_FILE=$(mktemp)
        trap "rm -f $PRIVATE_KEY_FILE" EXIT
        echo "$PRIVATE_KEY_PATH" > "$PRIVATE_KEY_FILE"
        chmod 600 "$PRIVATE_KEY_FILE"
    fi
else
    # Assume it's the key content itself
    PRIVATE_KEY_FILE=$(mktemp)
    trap "rm -f $PRIVATE_KEY_FILE" EXIT
    echo "$PRIVATE_KEY_PATH" > "$PRIVATE_KEY_FILE"
    chmod 600 "$PRIVATE_KEY_FILE"
fi

# Verify private key file
if [ ! -f "$PRIVATE_KEY_FILE" ]; then
    log_error "Private key file not found: $PRIVATE_KEY_FILE"
    exit 1
fi

# Sign the DMG
log_info "Signing DMG with EdDSA key..."
SIGNATURE_OUTPUT=$("$SIGN_UPDATE_TOOL" "$DMG_PATH" "$PRIVATE_KEY_FILE" 2>&1)

if [ $? -ne 0 ]; then
    log_error "Failed to sign DMG"
    echo "$SIGNATURE_OUTPUT"
    exit 1
fi

# Extract signature and length from output
# Expected format: sparkle:edSignature="..." length="..."
SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"$//')
LENGTH=$(echo "$SIGNATURE_OUTPUT" | grep -o 'length="[0-9]*"' | sed 's/length="//;s/"$//')

if [ -z "$SIGNATURE" ] || [ -z "$LENGTH" ]; then
    log_error "Failed to parse signature output"
    echo "Output: $SIGNATURE_OUTPUT"
    exit 1
fi

log_info "Signature generated successfully"
log_info "Signature: ${SIGNATURE:0:20}..."
log_info "Length: $LENGTH bytes"

# Get DMG filename for URL
DMG_FILENAME=$(basename "$DMG_PATH")
DMG_URL="${GITHUB_RELEASES_URL}/download/v${VERSION}/${DMG_FILENAME}"

# Get current date in RFC 822 format
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")

# Create appcast.xml
log_info "Generating appcast.xml..."

APPCAST_FILE="$PROJECT_ROOT/gh-pages/appcast.xml"

# Ensure gh-pages directory exists
mkdir -p "$(dirname "$APPCAST_FILE")"

# Generate appcast.xml content
cat > "$APPCAST_FILE" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
                 xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>MacOS AI Disk Cleaner Updates</title>
        <link>${GITHUB_PAGES_URL}/appcast.xml</link>
        <description>Most recent updates for MacOS AI Disk Cleaner</description>
        <language>en</language>

        <item>
            <title>Version ${VERSION}</title>
            <link>${GITHUB_RELEASES_URL}</link>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>What's New in Version ${VERSION}</h2>
                <p>Download the latest version from GitHub Releases.</p>
                <p>For detailed release notes, visit:
                <a href="${GITHUB_RELEASES_URL}/tag/v${VERSION}">Release v${VERSION}</a></p>
            ]]></description>
            <pubDate>${PUB_DATE}</pubDate>
            <enclosure
                url="${DMG_URL}"
                sparkle:edSignature="${SIGNATURE}"
                length="${LENGTH}"
                type="application/octet-stream" />
        </item>
    </channel>
</rss>
EOF

log_info "appcast.xml generated successfully: $APPCAST_FILE"

# Validate XML
if command -v xmllint &> /dev/null; then
    if xmllint --noout "$APPCAST_FILE" 2>&1; then
        log_info "✓ XML validation passed"
    else
        log_warn "⚠ XML validation failed (but file was generated)"
    fi
else
    log_warn "⚠ xmllint not found, skipping XML validation"
fi

# Show next steps
echo ""
log_info "Next steps:"
echo "  1. Review the generated appcast.xml: $APPCAST_FILE"
echo "  2. If needed, edit the <description> field with detailed release notes"
echo "  3. Commit and push to gh-pages branch:"
echo "     git checkout gh-pages"
echo "     cp $APPCAST_FILE appcast.xml"
echo "     git commit -am 'Update appcast for v${VERSION}'"
echo "     git push origin gh-pages"
echo ""
log_info "Done!"
