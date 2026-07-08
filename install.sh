#!/bin/sh
# csph installer — https://install.computesphere.com
#
#   curl -fsSL https://install.computesphere.com | sh
#
# Downloads the ComputeSphere CLI (`csph`) release archive for your platform
# from https://github.com/computesphere/csph/releases, verifies its SHA-256
# checksum, and installs the binary onto your PATH.
#
# Environment overrides:
#   CSPH_VERSION      Version to install (default: latest, e.g. "0.11.6")
#   CSPH_INSTALL_DIR  Install directory (default: ~/.local/bin)
#   CSPH_NO_MODIFY_PATH=1  Skip the PATH hint
#
# This script installs to a per-user directory and never needs root.
set -eu

REPO="computesphere/csph"
BINARY="csph"

info()  { printf '\033[0;34m==>\033[0m %s\n' "$1"; }
warn()  { printf '\033[0;33mwarning:\033[0m %s\n' "$1" >&2; }
error() { printf '\033[0;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || error "required command not found: $1"; }

# --- pick a downloader -------------------------------------------------------
if command -v curl >/dev/null 2>&1; then
  dl() { curl -fsSL "$1" -o "$2"; }
  dl_out() { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
  dl() { wget -qO "$2" "$1"; }
  dl_out() { wget -qO - "$1"; }
else
  error "need either curl or wget installed"
fi

need tar
need uname

# --- detect OS ---------------------------------------------------------------
os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$os" in
  linux)   OS="linux" ;;
  darwin)  OS="darwin" ;;
  *)       error "unsupported operating system: $os (try Homebrew, or download from https://github.com/$REPO/releases)" ;;
esac

# --- detect arch -------------------------------------------------------------
arch=$(uname -m)
case "$arch" in
  x86_64|amd64)   ARCH="amd64" ;;
  arm64|aarch64)  ARCH="arm64" ;;
  armv7l|armv6l|arm) ARCH="arm" ;;
  i386|i686)      ARCH="386" ;;
  *)              error "unsupported architecture: $arch" ;;
esac

ASSET="${OS}_${ARCH}.tar.gz"
CHECKSUMS="linux_macos_sha256S_checksums.txt"

# --- resolve version ---------------------------------------------------------
VERSION="${CSPH_VERSION:-}"
if [ -z "$VERSION" ]; then
  info "Resolving latest release..."
  # Read the tag_name from the GitHub releases API (downloader-agnostic).
  VERSION=$(dl_out "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
    | grep -m1 '"tag_name"' \
    | sed -e 's/.*"tag_name"[[:space:]]*:[[:space:]]*"//' -e 's/".*//')
  [ -n "$VERSION" ] || \
    error "could not resolve the latest version — set CSPH_VERSION explicitly (e.g. CSPH_VERSION=0.11.6)"
fi

BASE="https://github.com/$REPO/releases/download/$VERSION"
info "Installing csph $VERSION ($OS/$ARCH)"

# --- download into a temp dir ------------------------------------------------
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t csph)
trap 'rm -rf "$TMP"' EXIT INT TERM

info "Downloading $ASSET..."
dl "$BASE/$ASSET" "$TMP/$ASSET" || \
  error "download failed: $BASE/$ASSET (does version $VERSION ship $OS/$ARCH?)"

# --- verify checksum ---------------------------------------------------------
if dl "$BASE/$CHECKSUMS" "$TMP/$CHECKSUMS" 2>/dev/null; then
  expected=$(grep " $ASSET\$" "$TMP/$CHECKSUMS" | awk '{print $1}')
  if [ -n "$expected" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      actual=$(sha256sum "$TMP/$ASSET" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
      actual=$(shasum -a 256 "$TMP/$ASSET" | awk '{print $1}')
    else
      actual=""
      warn "no sha256sum/shasum available — skipping checksum verification"
    fi
    if [ -n "$actual" ]; then
      [ "$actual" = "$expected" ] || error "checksum mismatch for $ASSET (expected $expected, got $actual)"
      info "Checksum verified."
    fi
  else
    warn "no checksum listed for $ASSET — skipping verification"
  fi
else
  warn "could not fetch $CHECKSUMS — skipping checksum verification"
fi

# --- extract -----------------------------------------------------------------
tar -xzf "$TMP/$ASSET" -C "$TMP"
# archives are wrap_in_directory: true → binary lives in <os>_<arch>/csph
BIN_PATH=$(find "$TMP" -type f -name "$BINARY" ! -name '*.tar.gz' | head -n1)
[ -n "$BIN_PATH" ] || error "could not find '$BINARY' inside $ASSET"
chmod +x "$BIN_PATH"

# --- install -----------------------------------------------------------------
INSTALL_DIR="${CSPH_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$INSTALL_DIR"
mv -f "$BIN_PATH" "$INSTALL_DIR/$BINARY"
info "Installed csph to $INSTALL_DIR/$BINARY"

# --- PATH hint ---------------------------------------------------------------
if [ "${CSPH_NO_MODIFY_PATH:-0}" != "1" ]; then
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) : ;;
    *)
      warn "$INSTALL_DIR is not on your PATH."
      printf '  Add it by appending this to your shell profile:\n\n    export PATH="%s:$PATH"\n\n' "$INSTALL_DIR"
      ;;
  esac
fi

info "Done. Run 'csph auth login' to get started."
