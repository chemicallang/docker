#!/usr/bin/env bash
# test-images.sh
# Place this in the same directory as hello-world.ch
#
# Usage:
#   ./test-images.sh                 # uses default image list below
#   ./test-images.sh image1 image2   # test only the images passed as args
#   IMAGES="img1 img2" ./test-images.sh
#   ./test-images.sh -e              # stop on first failure
#
# Environment:
#   REPO    (optional) default: chemicallang/chemical
#   VERSION (optional) default: v0.0.25
#
set -o pipefail

STOP_ON_FAILURE=false

# parse simple flags
while getopts ":e" opt; do
  case ${opt} in
    e ) STOP_ON_FAILURE=true ;;
    \? ) echo "Unknown option: -$OPTARG" >&2; exit 1 ;;
  esac
done
shift $((OPTIND -1))

REPO="${REPO:-chemicallang/chemical}"
VERSION="${VERSION:-v0.0.25}"

# default images (matching your workflow tags)
DEFAULT_IMAGES=(
  "${REPO}:latest-ubuntu"
  "${REPO}:${VERSION}-ubuntu"
  "${REPO}:latest-tcc-ubuntu"
  "${REPO}:${VERSION}-tcc-ubuntu"
  "${REPO}:latest-alpine"
  "${REPO}:${VERSION}-alpine"
  "${REPO}:latest-tcc-alpine"
  "${REPO}:${VERSION}-tcc-alpine"
  "${REPO}:latest-alpine-glibc"
  "${REPO}:${VERSION}-alpine-glibc"
  "${REPO}:latest-tcc-alpine-glibc"
  "${REPO}:${VERSION}-tcc-alpine-glibc"
)

# Choose images: command-line args override, then IMAGES env, then defaults
if [ "$#" -gt 0 ]; then
  IMAGES=("$@")
elif [ -n "${IMAGES:-}" ]; then
  # split IMAGES env (space separated)
  read -r -a IMAGES <<< "$IMAGES"
else
  IMAGES=("${DEFAULT_IMAGES[@]}")
fi

PWD_DIR="$(pwd)"
HELLO_FILE="$PWD_DIR/hello-world.ch"

if [ ! -f "$HELLO_FILE" ]; then
  echo "ERROR: hello-world.ch not found in current directory ($PWD_DIR)."
  exit 2
fi

echo "Testing images (will mount current directory: $PWD_DIR):"
for img in "${IMAGES[@]}"; do
  echo
  echo "============================================================"
  echo "IMAGE: $img"
  echo "Pulling image (this ensures we run the most recent pushed image)..."
  if ! docker pull "$img"; then
    echo "WARNING: docker pull failed for $img (image may not exist or network issue)."
    if $STOP_ON_FAILURE; then
      echo "Stopping on failure (-e set)."
      exit 3
    else
      echo "Continuing to next image."
      continue
    fi
  fi

  echo "Running compile + run inside container..."
  echo "Command executed inside container: chemical hello-world.ch -o main.exe && ./main.exe"
  echo "------ output below (start) ------"

  # Use a shell inside container; mount current dir as /work and set workdir
  # Use --rm so container is removed after run. Use -t so output formatting is preserved.
  # Use --user "$(id -u):$(id -g)" optionally if you want files created with your uid,
  # but that is not strictly necessary for this read/run use case.
  #
  # We don't capture output; Docker streams it directly to the terminal.
  if docker run --rm -v "$PWD_DIR":/work -w /work -it "$img" /bin/sh -c \
     "set -e; chemical hello-world.ch -o main.exe && chmod +x ./main.exe && ./main.exe"; then
    echo "------ output above (end) ------"
    echo "Result: SUCCESS for $img"
  else
    echo "------ output above (end) ------"
    echo "Result: FAILURE for $img"
    if $STOP_ON_FAILURE; then
      echo "Stopping on failure (-e set)."
      exit 4
    fi
  fi

  echo "------------------------------------------------------------"
done

echo
echo "All done."