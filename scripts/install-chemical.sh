#!/usr/bin/env bash
set -euo pipefail

# Usage: ./install-chemical.sh
# Env vars:
#   VERSION (default v0.0.25)
#   RELEASE_PLATFORM (optional: e.g. linux, linux-alpine, macos, windows)
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

cd "${TMPDIR:-/tmp}"

# map uname -m -> our tokens
detect_arch() {
  if [ -n "${ARCH_OVERRIDE:-}" ]; then
    echo "$ARCH_OVERRIDE"
    return
  fi

  m="$(uname -m || true)"
  case "$m" in
    x86_64|amd64) echo "x64" ;;
    aarch64|arm64) echo "arm64" ;;
    i386|i686) echo "x64" ;; # treat 32-bit as x64 fallback
    *) echo "x64" ;; # conservative fallback
  esac
}

# Detect platform: linux | linux-alpine | macos | windows
detect_platform() {
  if [ -n "${RELEASE_PLATFORM:-}" ]; then
    # honor explicit override
    echo "$RELEASE_PLATFORM"
    return
  fi

  uname_s="$(uname -s 2>/dev/null || echo Unknown)"
  case "$uname_s" in
    Darwin*)
      echo "macos"
      return
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT*)
      # Git Bash / MSYS / Cygwin on Windows
      echo "windows"
      return
      ;;
    Linux*)
      # Try to detect alpine (musl) vs glibc
      # 1) /etc/os-release often contains ID=alpine
      if [ -f /etc/os-release ]; then
        if grep -qi '^ID=alpine' /etc/os-release 2>/dev/null || grep -qi 'alpine' /etc/os-release 2>/dev/null; then
          echo "linux-alpine"
          return
        fi
      fi

      # 2) try ldd --version output contains musl
      if command -v ldd >/dev/null 2>&1; then
        if ldd --version 2>&1 | tr '[:upper:]' '[:lower:]' | grep -q musl; then
          echo "linux-alpine"
          return
        fi
      fi

      # 3) check for musl dynamic loader
      if ls /lib/ld-musl-* >/dev/null 2>&1 || ls /usr/glibc-* >/dev/null 2>&1; then
        if ls /lib/ld-musl-* >/dev/null 2>&1; then
          echo "linux-alpine"
          return
        fi
      fi

      # default Linux (glibc)
      echo "linux"
      return
      ;;
    *)
      # unknown: be conservative and return "linux"
      echo "linux"
      return
      ;;
  esac
}

ARCH_TOKEN="$(detect_arch)"
DETECTED_PLATFORM="$(detect_platform)"

# If user provided RELEASE_PLATFORM env, keep it; otherwise use detected
if [ -z "${RELEASE_PLATFORM:-}" ]; then
  RELEASE_PLATFORM="$DETECTED_PLATFORM"
fi

# Build candidate asset names (tries variant-specific first then non-variant)
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
echo "  VERSION= $VERSION"
echo "  RELEASE_PLATFORM= $RELEASE_PLATFORM"
echo "  DETECTED_PLATFORM= $DETECTED_PLATFORM"
echo "  VARIANT= $VARIANT"
echo "  ARCH_TOKEN= $ARCH_TOKEN"
echo "  CANDIDATES= ${candidates[*]}"

# choose downloader: prefer wget, fallback to curl
_downloader_check() {
  if command -v wget >/dev/null 2>&1; then
    echo "wget"
  elif command -v curl >/dev/null 2>&1; then
    echo "curl"
  else
    echo ""
  fi
}

# choose extractor: prefer unzip, else bsdtar/tar, else python
_extractor_check() {
  if command -v unzip >/dev/null 2>&1; then
    echo "unzip"
  elif command -v bsdtar >/dev/null 2>&1; then
    echo "bsdtar"
  elif command -v jar >/dev/null 2>&1; then
    echo "jar"
  elif command -v python3 >/dev/null 2>&1; then
    echo "python3"
  elif command -v python >/dev/null 2>&1; then
    echo "python"
  else
    echo ""
  fi
}

DOWNLOADER="$(_downloader_check)"
EXTRACTOR="$(_extractor_check)"

if [ -z "$DOWNLOADER" ]; then
  echo "ERROR: neither wget nor curl found. Please install one to download release assets." >&2
  exit 3
fi

if [ -z "$EXTRACTOR" ]; then
  echo "ERROR: no unzip/bsdtar/python available to extract zip files. Please install unzip or bsdtar." >&2
  exit 4
fi

cleanup_tmp() {
  if [ -n "${TMP_EXTRACT_DIR:-}" ] && [ -d "${TMP_EXTRACT_DIR}" ]; then
    rm -rf "${TMP_EXTRACT_DIR}"
  fi
  if [ -n "${TMP_ZIP_PATH:-}" ] && [ -f "${TMP_ZIP_PATH}" ]; then
    rm -f "${TMP_ZIP_PATH}"
  fi
}

trap cleanup_tmp EXIT

# Choose install directory (writable)
choose_install_dir() {
  if [ "$(uname -s 2>/dev/null || echo '')" = "Windows_NT" ]; then
    # Native Windows Git Bash / MSYS
    if [ -n "${USERPROFILE:-}" ]; then
      echo "${USERPROFILE//\\//}/.chemical"
      return
    fi
  fi

  # Non-Windows systems
  if [ -w /opt ] || mkdir -p /opt/chemical 2>/dev/null; then
    echo "/opt/chemical"
    return
  fi

  # Fallback to home
  echo "${HOME:-/tmp}/.chemical"
}


download_and_extract() {
  TMP_EXTRACT_DIR="$(mktemp -d -t chemical_unzip.XXXXXX)"

  tmpdir="$(choose_install_dir)"
  mkdir -p "$tmpdir"

  for name in "${candidates[@]}"; do
    url="${BASE_URL}/${name}"
    echo "Checking $url ..."

    # check exists
    if [ "$DOWNLOADER" = "wget" ]; then
      if wget --spider -q "$url"; then
        echo "Found $name → downloading..."
        TMP_ZIP_PATH="$(mktemp -p "${TMPDIR:-/tmp}" "chemical_XXXXXX.zip")"
        wget -q "$url" -O "$TMP_ZIP_PATH"
      else
        echo "Not found: $name"
        continue
      fi
    else
      # curl
      if curl -sfI "$url" >/dev/null 2>&1; then
        echo "Found $name → downloading..."
        TMP_ZIP_PATH="$(mktemp -p "${TMPDIR:-/tmp}" "chemical_XXXXXX.zip")"
        curl -sSL "$url" -o "$TMP_ZIP_PATH"
      else
        echo "Not found: $name"
        continue
      fi
    fi

    # extract
    echo "Extracting $TMP_ZIP_PATH to $TMP_EXTRACT_DIR ..."
    case "$EXTRACTOR" in
      unzip)
        unzip -q "$TMP_ZIP_PATH" -d "$TMP_EXTRACT_DIR"
        ;;
      bsdtar)
        bsdtar -xf "$TMP_ZIP_PATH" -C "$TMP_EXTRACT_DIR"
        ;;
      jar)
        (cd "$TMP_EXTRACT_DIR" && jar xf "$TMP_ZIP_PATH")
        ;;
      python3|python)
        # use python zipfile to extract
        "$EXTRACTOR" - <<PYCODE
import sys, zipfile
p = sys.argv[1]
with zipfile.ZipFile(p) as z:
    z.extractall(sys.argv[2])
PYCODE
        # Note: the above uses the interpreter but we need to pass args; simpler to call with -c:
        # but bash heredoc above won't supply args; fallback to direct invocation:
        "$EXTRACTOR" -c "import sys,zipfile;zipfile.ZipFile('${TMP_ZIP_PATH}').extractall('${TMP_EXTRACT_DIR}')"
        ;;
      *)
        echo "No extractor available" >&2
        return 5
        ;;
    esac

    # Move contents into /opt/chemical in a clean way.
    # The zip may contain a single directory (e.g. linux-x64/...) or bare files.
    first_item="$(ls -A "$TMP_EXTRACT_DIR" | head -n1 || true)"
    if [ -z "$first_item" ]; then
      echo "ERROR: zip was empty"
      return 1
    fi

    # remove old contents (but keep directory)
    rm -rf "${tmpdir:?}/"*

    if [ -d "${TMP_EXTRACT_DIR}/${first_item}" ]; then
      # if that directory is the only top-level, move its contents
      mv "${TMP_EXTRACT_DIR}/${first_item}"/* "$tmpdir"/ || true
    else
      mv "${TMP_EXTRACT_DIR}"/* "$tmpdir"/ || true
    fi

    # cleanup that zip & extract dir (trap handles remaining cleanup)
    chmod -R +x "$tmpdir"
    echo "Installed to $tmpdir"
    return 0
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
