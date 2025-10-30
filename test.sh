#!/usr/bin/env bash
# test-images.sh
# Robust tester for multiple Docker images on Linux and Git Bash (Windows).
# Tries to mount current dir; if that fails (Git Bash path issues), falls back to docker copy+exec.
#
# Usage:
#   ./test-images.sh                # tests defaults
#   ./test-images.sh img1 img2      # test only listed images
#   ./test-images.sh -e             # stop on first failure
# Env:
#   REPO (default chemicallang/chemical)
#   VERSION (default v0.0.25)

set -o pipefail

STOP_ON_FAILURE=false
while getopts ":e" opt; do
  case ${opt} in
    e ) STOP_ON_FAILURE=true ;;
    \? ) echo "Unknown option: -$OPTARG" >&2; exit 1 ;;
  esac
done
shift $((OPTIND -1))

REPO="${REPO:-chemicallang/chemical}"
VERSION="${VERSION:-v0.0.25}"

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

if [ "$#" -gt 0 ]; then
  IMAGES=("$@")
elif [ -n "${IMAGES:-}" ]; then
  read -r -a IMAGES <<< "$IMAGES"
else
  IMAGES=("${DEFAULT_IMAGES[@]}")
fi

HOST_PWD="$(pwd -P)"   # physical cwd
HELLO_FILE="$HOST_PWD/hello-world.ch"
if [ ! -f "$HELLO_FILE" ]; then
  echo "ERROR: hello-world.ch not found in current directory ($HOST_PWD)."
  exit 2
fi

# Determine docker-friendly path for mounting.
# - On Linux/WSL use Linux path (pwd)
# - On Git Bash / MSYS (MSYSTEM or OSTYPE contains msys/mingw) convert Windows-style to /c/...
DOCKER_PWD="$HOST_PWD"
if [ -n "${MSYSTEM:-}" ] || [[ "${OSTYPE:-}" == msys* ]] || [[ "${OSTYPE:-}" == cygwin* ]] || [[ "${OSTYPE:-}" == mingw* ]]; then
  # prefer pwd -W (Windows style) if available, then convert to /c/... form
  WINPWD=$(pwd -W 2>/dev/null || echo "$HOST_PWD")
  # Convert "C:\path" or "C:/path" or "C:/" to "/c/path", and backslashes -> slashes
  DOCKER_PWD=$(printf '%s' "$WINPWD" | sed -E 's#^([A-Za-z]):[\\/]*#/\L\1/#' | sed 's#\\#/#g')
fi

echo "Host working dir: $HOST_PWD"
echo "Docker mount path: $DOCKER_PWD"
echo

# helper: run with mount (preferred)
run_with_mount() {
  local img="$1"
  # The command runs inside container: compile and run; leave main.exe behind in host dir
  docker run --rm -v "${DOCKER_PWD}":/work -w /work -it "$img" /bin/sh -c \
    "set -e; chemical hello-world.ch -o main.exe && chmod +x ./main.exe && ./main.exe"
}

# fallback: copy file into temp container, run, copy main.exe back
run_with_copy_fallback() {
  local img="$1"
  local name="chemical_test_$(date +%s%N)"
  echo "Fallback mode: creating temporary container ($name), copying files..."
  # Start container in detached sleep so we can docker cp and docker exec
  if ! docker create --name "$name" "$img" /bin/sh -c "sleep 999999"; then
    echo "ERROR: failed to create temporary container from $img"
    return 2
  fi
  # Ensure we always remove container at end
  cleanup_container() {
    docker rm -f "$name" >/dev/null 2>&1 || true
  }
  trap cleanup_container RETURN

  # Copy hello-world.ch into /work inside container
  if ! docker cp "$HELLO_FILE" "$name":/hello-world.ch; then
    echo "ERROR: docker cp failed (input copy)."
    cleanup_container
    return 3
  fi

  # Exec the compile+run in container, streaming output
  # create work dir and move file there (so compiled main.exe will be under /work)
  if ! docker start "$name" >/dev/null; then
    echo "ERROR: docker start failed for $name"
    cleanup_container
    return 4
  fi

  # Run compile+execute. We run in /work to be consistent.
  if ! docker exec --tty "$name" /bin/sh -c "mkdir -p /work && mv /hello-world.ch /work/hello-world.ch && cd /work && set -e; chemical hello-world.ch -o main.exe && chmod +x ./main.exe && ./main.exe"; then
    echo "Container run failed (see output above)."
    # still attempt to copy any produced main.exe (maybe partial)
    docker cp "$name":/work/main.exe "$HOST_PWD"/main.exe >/dev/null 2>&1 || true
    cleanup_container
    return 5
  fi

  # Copy main.exe back to host (so temp files are in current dir)
  docker cp "$name":/work/main.exe "$HOST_PWD"/main.exe >/dev/null 2>&1 || true

  cleanup_container
  return 0
}

# Main loop
for img in "${IMAGES[@]}"; do
  echo
  echo "============================================================"
  echo "IMAGE: $img"
  echo "Pulling image..."
  if ! docker pull "$img"; then
    echo "WARNING: docker pull failed for $img (image may not exist or network issue)."
    $STOP_ON_FAILURE && exit 3
    continue
  fi

  echo "Attempting to run by mounting current directory into container..."
  if run_with_mount "$img"; then
    echo "Result: SUCCESS for $img (mount mode)."
  else
    echo "Mount-run failed. Falling back to copy+exec method (works even if mount path is invalid)."
    if run_with_copy_fallback "$img"; then
      echo "Result: SUCCESS for $img (fallback mode)."
    else
      echo "Result: FAILURE for $img (both mount and fallback failed)."
      $STOP_ON_FAILURE && exit 4
    fi
  fi
  echo "------------------------------------------------------------"
done

echo
echo "All done."