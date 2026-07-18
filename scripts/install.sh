#!/usr/bin/env sh
# Workloom CLI installer.
#
#   curl -fsSL https://raw.githubusercontent.com/catesandrew/workloom-x-releases/main/scripts/install.sh | sh
#
# Detects your platform, downloads the matching `wl` binary from the latest
# GitHub Release, verifies its SHA-256 against the release's SHA256SUMS asset,
# and installs it. Overridable with env vars:
#   WL_VERSION       release tag to install (default: latest, e.g. cli-v0.2.0)
#   WL_INSTALL_DIR   install directory   (default: $HOME/.workloom/bin)
set -eu

# The public mirror repo (source lives in the private catesandrew/workloom-x
# repo; release assets + this script are mirrored here so anonymous
# `curl | sh` works without a private-repo token).
REPO="catesandrew/workloom-x-releases"
INSTALL_DIR="${WL_INSTALL_DIR:-$HOME/.workloom/bin}"

say() { printf '%s\n' "$*"; }
err() { printf 'install: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || err "required command not found: $1"; }

need uname
need mktemp
# One of curl/wget for downloads.
if command -v curl >/dev/null 2>&1; then DL="curl -fsSL"; DLO="curl -fsSL -o";
elif command -v wget >/dev/null 2>&1; then DL="wget -qO-"; DLO="wget -qO";
else err "need curl or wget"; fi

# --- Detect platform -> release target name (matches release-cli.yml) ---
os="$(uname -s)"; arch="$(uname -m)"
case "$os" in
  Darwin) os=darwin ;;
  Linux)  os=linux ;;
  *) err "unsupported OS: $os (use the npm install or a GitHub Release asset)" ;;
esac
case "$arch" in
  arm64|aarch64) arch=arm64 ;;
  x86_64|amd64)  arch=x64 ;;
  *) err "unsupported architecture: $arch" ;;
esac
# Published targets: darwin-arm64, linux-x64. (darwin-x64/Intel Mac dropped —
# macos-13 CI runners were unreliable; linux-arm64 is not built yet — fail
# loudly rather than fetch a mismatched binary.)
target="${os}-${arch}"
case "$target" in
  darwin-arm64|linux-x64) ;;
  *) err "no prebuilt binary for $target yet — install via npm: npm i -g @workloom/cli" ;;
esac

# --- Resolve version tag ---
if [ -n "${WL_VERSION:-}" ]; then
  tag="$WL_VERSION"
else
  # Follow the "latest release" redirect to read its tag, no jq required.
  latest_url="$($DL "https://github.com/$REPO/releases/latest" 2>/dev/null | grep -o "tag/cli-v[^\"']*" | head -1 || true)"
  tag="${latest_url#tag/}"
  [ -n "$tag" ] || err "could not resolve the latest release tag; set WL_VERSION explicitly"
fi

asset="wl-${target}.tar.gz"
base="https://github.com/$REPO/releases/download/$tag"
say "Installing wl ($target) from $tag"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

$DLO "$tmp/$asset" "$base/$asset" || err "download failed: $base/$asset"

# --- Verify checksum against the release's SHA256SUMS (required) ---
if $DLO "$tmp/SHA256SUMS" "$base/SHA256SUMS" 2>/dev/null; then
  expected="$(grep " $asset\$" "$tmp/SHA256SUMS" | awk '{print $1}' | head -1)"
  [ -n "$expected" ] || err "SHA256SUMS has no entry for $asset"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$tmp/$asset" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')"
  else
    err "no sha256sum/shasum available to verify the download"
  fi
  [ "$expected" = "$actual" ] || err "checksum mismatch for $asset (expected $expected, got $actual)"
  say "Checksum verified."
else
  err "SHA256SUMS not found for $tag — refusing to install an unverified binary"
fi

# --- Extract + install ---
tar -xzf "$tmp/$asset" -C "$tmp" || err "extract failed"
mkdir -p "$INSTALL_DIR"
mv "$tmp/wl" "$INSTALL_DIR/wl"
chmod +x "$INSTALL_DIR/wl"
say "Installed to $INSTALL_DIR/wl"

# --- PATH hint ---
case ":$PATH:" in
  *":$INSTALL_DIR:"*) say "Run: wl --version" ;;
  *)
    say ""
    say "$INSTALL_DIR is not on your PATH. Add it, e.g.:"
    say "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.profile"
    say "Then: wl --version"
    ;;
esac
