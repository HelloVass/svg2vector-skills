#!/usr/bin/env sh
# svg2vector binary installer.
#
# Detects the host platform and downloads the matching native binary from
# this project's GitHub Releases to ~/.local/bin/svg2vector (override with
# SVG2VECTOR_DIR=...).
#
# Two-layer download strategy:
#   1. Anonymous `curl` from the GitHub Releases CDN — works for public
#      repos with no auth needed.
#   2. Fallback to `gh release download` — works for private repos as
#      long as `gh auth status` shows the user is signed in. Useful while
#      this project is in private review before going public.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/HelloVass/svg2vector-skills/main/install.sh | sh

set -e

REPO="HelloVass/svg2vector-skills"
INSTALL_DIR="${SVG2VECTOR_DIR:-$HOME/.local/bin}"

OS=$(uname -s | tr 'A-Z' 'a-z')
ARCH=$(uname -m)

# Normalize Linux's amd64 alias into the asset-naming convention.
case "$ARCH" in
  amd64) ARCH=x86_64 ;;
esac

case "$OS-$ARCH" in
  darwin-arm64)  ASSET=svg2vector-darwin-arm64 ;;
  darwin-x86_64) ASSET=svg2vector-darwin-x86_64 ;;
  linux-x86_64)  ASSET=svg2vector-linux-x86_64 ;;
  *)
    echo "Unsupported platform: $OS-$ARCH" >&2
    echo "Supported: darwin-arm64, darwin-x86_64, linux-x86_64" >&2
    exit 1
    ;;
esac

URL="https://github.com/$REPO/releases/latest/download/$ASSET"
DEST="$INSTALL_DIR/svg2vector"

mkdir -p "$INSTALL_DIR"
echo "Installing svg2vector ($ASSET) → $DEST"

# Layer 1: anonymous curl. Fast path for the (public) common case.
if curl -fsSL "$URL" -o "$DEST" 2>/dev/null; then
  echo "  fetched via anonymous CDN"
# Layer 2: gh CLI fallback. Triggers when the request above 404'd or got
# redirected to the login wall — typically because the repo is private.
elif command -v gh >/dev/null 2>&1; then
  rm -f "$DEST"
  echo "  anonymous fetch failed; falling back to 'gh release download'"
  if ! gh release download -R "$REPO" -p "$ASSET" -O "$DEST"; then
    echo "" >&2
    echo "gh release download failed too. Make sure you're authenticated:" >&2
    echo "  gh auth status" >&2
    echo "  gh auth login   # if not signed in" >&2
    exit 1
  fi
else
  echo "" >&2
  echo "Could not download anonymously and 'gh' CLI is not installed." >&2
  echo "Either:" >&2
  echo "  - install gh (https://cli.github.com), run 'gh auth login', then re-run; or" >&2
  echo "  - wait for this repo to go public so anonymous CDN download works." >&2
  exit 1
fi

chmod +x "$DEST"

echo
echo "Installed."
echo

# Verify PATH has the install dir.
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo "WARNING: $INSTALL_DIR is not in your PATH."
    echo "Add this to your shell rc:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
esac

echo "Verify with: svg2vector --version"
