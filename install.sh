#!/usr/bin/env sh
# svg2vector binary installer.
#
# Detects the host platform, downloads the matching native binary from
# this project's GitHub Releases, and installs it to ~/.local/bin/svg2vector
# (override with SVG2VECTOR_DIR=...).
#
# Inspired by https://dl.google.com/android/cli/latest/darwin_arm64/install.sh
# — atomic write via mktemp+trap, prerequisite check, post-install warming.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/HelloVass/svg2vector-skills/main/install.sh | sh

set -e

# === Configuration ===
REPO="HelloVass/svg2vector-skills"
BINARY_NAME="svg2vector"
INSTALL_DIR="${SVG2VECTOR_DIR:-$HOME/.local/bin}"

# === Prerequisite check ===
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required to install $BINARY_NAME." >&2
  exit 1
fi

# === Platform detection ===
OS=$(uname -s | tr 'A-Z' 'a-z')
ARCH=$(uname -m)
case "$ARCH" in
  amd64) ARCH=x86_64 ;;  # normalize Linux's amd64 alias
esac

case "$OS-$ARCH" in
  darwin-arm64)  ASSET=svg2vector-darwin-arm64 ;;
  darwin-x86_64) ASSET=svg2vector-darwin-x86_64 ;;
  linux-x86_64)  ASSET=svg2vector-linux-x86_64 ;;
  *)
    echo "Error: unsupported platform $OS-$ARCH." >&2
    echo "Supported: darwin-arm64, darwin-x86_64, linux-x86_64" >&2
    exit 1
    ;;
esac

URL="https://github.com/$REPO/releases/latest/download/$ASSET"
DEST="$INSTALL_DIR/$BINARY_NAME"

mkdir -p "$INSTALL_DIR"

# === Atomic download via temp file ===
# Download to a temp file first so a failed/interrupted curl never leaves
# a half-written binary at $DEST. Trap cleans up on any exit path.
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

echo "Installing $BINARY_NAME ($ASSET) → $DEST"
curl -fsSL "$URL" -o "$TMP_FILE"

# === Atomic install ===
chmod +x "$TMP_FILE"
mv "$TMP_FILE" "$DEST"
trap - EXIT  # mv consumed the temp file; cancel cleanup

# === Post-install warming ===
# Run --version once to confirm the binary actually executes on this host
# (catches arch mismatch / glibc mismatch / corrupted download immediately).
echo ""
echo "----------------------------------------"
"$DEST" --version
echo "----------------------------------------"
echo "✅ Success! $BINARY_NAME is installed at $DEST"

# === PATH setup (Bun / uv / rustup style: auto-edit user's shell rc) ===
# ~/.local/bin is not on the default zsh / bash PATH on either macOS or
# Linux. We append an `export PATH=...` line to the user's shell rc so
# the binary is on PATH after the user opens a new terminal — same UX
# as Bun's installer, uv's installer, etc.
case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    # Already on PATH. Nothing to do.
    ;;
  *)
    # Detect the user's shell to pick the right rc file.
    case "${SHELL:-}" in
      */zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
      */bash)
        # On macOS, Terminal.app launches bash as a login shell which
        # reads .bash_profile (not .bashrc). On Linux it's the opposite.
        if [ "$OS" = "darwin" ] && [ -f "$HOME/.bash_profile" ]; then
          RC_FILE="$HOME/.bash_profile"
        else
          RC_FILE="$HOME/.bashrc"
        fi
        ;;
      *)
        RC_FILE=""
        ;;
    esac

    PATH_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""

    if [ -n "$RC_FILE" ]; then
      # Create the rc file if missing (fresh user accounts often lack it).
      touch "$RC_FILE"
      # Don't duplicate: if INSTALL_DIR appears anywhere in the rc, assume
      # PATH is already set up and just remind the user to reload.
      if ! grep -Fq "$INSTALL_DIR" "$RC_FILE"; then
        printf '\n# Added by svg2vector installer\n%s\n' "$PATH_LINE" >> "$RC_FILE"
        echo ""
        echo "✅ Added $INSTALL_DIR to PATH in $RC_FILE"
        echo "   Restart your shell or run:  source $RC_FILE"
      else
        echo ""
        echo "ℹ️  $INSTALL_DIR is already configured in $RC_FILE but not active in this shell."
        echo "   Restart your shell or run:  source $RC_FILE"
      fi
    else
      # Unknown shell (fish / nu / something custom) — fall back to manual instructions.
      echo ""
      echo "WARNING: Could not auto-detect your shell (SHELL=${SHELL:-unset})."
      echo "Add this line to your shell rc manually:"
      echo "  $PATH_LINE"
    fi
    ;;
esac
