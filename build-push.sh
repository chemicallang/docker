#!/usr/bin/env bash
set -euo pipefail

# Simple build-and-push script
# Usage:
#   ./script.sh                   # build & push all images
#   ./script.sh --select a,b,c    # build & push only those (comma-separated base names)
#
# Notes:
# - For each name X the script expects a Dockerfile named "X.Dockerfile" in the current dir.
# - Each image is pushed twice: latest and $VERSION.
# - Special case: "tcc-alpine-glibc" will be tagged without a suffix (i.e. chemicallang/chemical:latest and :$VERSION)

REPO="chemicallang/chemical"
VERSION="${VERSION:-v0.0.24}"

# Known image base names (correspond to Dockerfile names like "ubuntu.Dockerfile")
ALL_IMAGES=(
  "tcc-alpine-glibc"
  "ubuntu"
  "alpine"
  "alpine-glibc"
  "slim"
  "tcc-ubuntu"
  "tcc-alpine"
  "tcc-slim"
)

# Parse optional --select
SELECT_LIST=""
if [ "${1:-}" = "--select" ]; then
  if [ "${2:-}" = "" ]; then
    echo "Usage: $0 --select name1,name2"
    exit 2
  fi
  SELECT_LIST="$2"
fi

# Build list to operate on
IMAGES_TO_RUN=()
if [ -z "$SELECT_LIST" ]; then
  IMAGES_TO_RUN=("${ALL_IMAGES[@]}")
else
  IFS=',' read -r -a sel <<< "$SELECT_LIST"
  for n in "${sel[@]}"; do
    # trim whitespace
    n="$(printf '%s' "$n" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -n "$n" ]; then
      IMAGES_TO_RUN+=("$n")
    fi
  done
fi

# quick docker check
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: docker not running or you are not logged in. Run 'docker login' and ensure daemon is running."
  exit 1
fi

for name in "${IMAGES_TO_RUN[@]}"; do
  dockerfile="${name}.Dockerfile"

  if [ ! -f "$dockerfile" ]; then
    echo "Warning: $dockerfile not found — skipping $name"
    continue
  fi

  # special-case: tcc-alpine-glibc -> no suffix
  if [ "$name" = "tcc-alpine-glibc" ]; then
    tag_latest="${REPO}:latest"
    tag_version="${REPO}:${VERSION}"
  else
    tag_latest="${REPO}:latest-${name}"
    tag_version="${REPO}:${VERSION}-${name}"
  fi

  echo
  echo "-------------------------------------------------"
  echo "Building $dockerfile"
  echo "  -> $tag_latest"
  echo "  -> $tag_version"
  echo "-------------------------------------------------"

  # Build once with both tags
  docker build -f "$dockerfile" -t "$tag_latest" -t "$tag_version" .

  echo "Pushing $tag_latest"
  docker push "$tag_latest"

  echo "Pushing $tag_version"
  docker push "$tag_version"
done

echo
echo "Done."