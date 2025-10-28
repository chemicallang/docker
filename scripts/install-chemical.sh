#!/usr/bin/env bash
set -euo pipefail

# Usage: ./install-chemical.sh
# Env vars:
#   VERSION (default v0.0.25)
#   RELEASE_PLATFORM (e.g. linux, linux-alpine, macos, windows)  -- corresponds to release asset prefix
#   VARIANT (empty OR tcc OR lsp)
#   ARCH_OVERRIDE (optional: amd64 | arm64 | x64 etc)
#   GITHUB_OWNER (default chemicallang)
#   GITHUB_REPO (default chemical)

VERSION="${VERSION:-v0.0.25}"
RELEASE_PLATFORM="${RELEASE_PLATFORM:-}"
VARIANT="${VARIANT:-}"
ARCH_OVERRIDE="${ARCH_OVERRIDE:-}"

GITHUB_OWNER="${GITHUB_OWNER:-chemicallang}"
GITHUB_REPO="${GITHUB_REPO:-chemical}"

cd /tmp

# map uname -m -> our tokens
detect_arch() {
  if [ -n "$ARCH_OVERRIDE" ]; then
    echo "$ARCH_OVERRIDE"
    return
  fi

  m="$(uname -m)"
  case "$m" in
    x86_64|amd64) echo "x64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "x64" ;; # be conservative
  esac
}

ARCH_TOKEN="$(detect_arch)"

# normalized candidates: try specific variant first, then non-variant, then fallback to x64
candidates=()

if [ -n "$VARIANT" ]; then
  candidates+=("${RELEASE_PLATFORM}-${ARCH_TOKEN}-${VARIANT}.zip")
fi
candidates+=("${RELEASE_PLATFORM}-${ARCH_TOKEN}.zip")

# fallback to x64 if arch-specific not present
if [ "$ARCH_TOKEN" != "x64" ]; then
  if [ -n "$VARIANT" ]; then
    candidates+=("${RELEASE_PLATFORM}-x64-${VARIANT}.zip")
  fi
  candidates+=("${RELEASE_PLATFORM}-x64.zip")
fi

BASE_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${VERSION}"

echo "Installation settings:"
echo "  VERSION=$VERSION"
echo "  PLATFORM=$RELEASE_PLATFORM"
echo "  VARIANT=$VARIANT"
echo "  ARCH_TOKEN=$ARCH_TOKEN"
echo "  CANDIDATES: ${candidates[*]}"

download_and_extract() {
  for name in "${candidates[@]}"; do
    url="${BASE_URL}/${name}"
    echo "Checking $url ..."
    # --spider will check without saving
    if wget --spider -q "$url"; then
      echo "Found $name → downloading..."
      wget -q "$url" -O "/tmp/${name}"
      tmpdir="/opt/chemical"
      mkdir -p "$tmpdir"
      # remove old
      rm -rf "$tmpdir"/*
      unzip -q "/tmp/${name}" -d /tmp/chemical_unzip
      # Move contents into /opt/chemical in a clean way.
      # The zip may contain a single directory (linux-x64/...) or bare files.
      # Find the first non-empty directory inside /tmp/chemical_unzip and move it.
      first_item="$(ls -A /tmp/chemical_unzip | head -n1 || true)"
      if [ -z "$first_item" ]; then
        echo "ERROR: zip was empty"
        return 1
      fi

      # if top-level item is a directory, move its contents. Else move files.
      if [ -d "/tmp/chemical_unzip/${first_item}" ]; then
        mv /tmp/chemical_unzip/"${first_item}"/* "$tmpdir"/
      else
        mv /tmp/chemical_unzip/* "$tmpdir"/
      fi

      rm -rf /tmp/chemical_unzip "/tmp/${name}"
      chmod -R +x "$tmpdir"
      echo "Installed to $tmpdir"
      return 0
    else
      echo "Not found: $name"
    fi
  done

  echo "ERROR: no release asset found for any of: ${candidates[*]}" >&2
  return 2
}

download_and_extract

# Add to PATH for current shell (the Dockerfile should set PATH too)
export PATH="/opt/chemical:${PATH}"

# Optional: run configure if binary available
if command -v chemical >/dev/null 2>&1; then
  chemical --configure || true
fi

echo "Done install-chemical.sh"
