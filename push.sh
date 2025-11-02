#!/usr/bin/env bash
set -euo pipefail

# Push the built Docker image to Docker Hub (or another registry).
# Note: If you use 'build.sh --multi-arch', the image is pushed automatically during build.
# This script is useful for:
#  - Re-tagging and pushing locally built images (non-multi-arch builds)
#  - Pushing to a different registry after a local build
# Usage: ./push.sh [--repo namespace/image] [--image local-name] [--no-latest] [--yes]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Prefer IMAGE_NAME from .env (written by build.sh); fallback to Docker Hub name
IMAGE_FROM_ENV=$(awk -F '=' '/^\s*IMAGE_NAME\s*=/{gsub(/\r/,"",$2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$ENV_FILE" | tail -n1)
DEFAULT_IMAGE="${IMAGE_FROM_ENV:-ghcr.io/bguspl/student-env}"
LOCAL_IMAGE="$DEFAULT_IMAGE"
REMOTE_REPO="$DEFAULT_IMAGE"
PUSH_LATEST=true
ASSUME_YES=false

usage() {
  cat <<-USAGE
Usage: $(basename "$0") [--repo namespace/image] [--image local-name] [--no-latest] [--yes]

Options:
  --repo <name>     Target repository (default: $DEFAULT_IMAGE)
  --image <name>    Local image name to read from (default: $DEFAULT_IMAGE)
  --no-latest       Skip pushing the 'latest' tag
  --yes             Skip confirmation prompt
  -h, --help        Show this help message
USAGE
}

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || { echo "--repo requires an argument" >&2; exit 2; }
      REMOTE_REPO="$2"; shift 2 ;;
    --image)
      [[ $# -ge 2 ]] || { echo "--image requires an argument" >&2; exit 2; }
      LOCAL_IMAGE="$2"; shift 2 ;;
    --no-latest)
      PUSH_LATEST=false; shift ;;
    --yes)
      ASSUME_YES=true; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2 ;;
  esac
done

if [[ ! -f "$ENV_FILE" ]]; then
  echo ".env not found at: $ENV_FILE" >&2
  exit 2
fi

VERSION=$(awk -F '=' '/^\s*VERSION\s*=/{gsub(/\r/,"",$2); gsub(/\s+/,"",$2); print $2}' "$ENV_FILE" | tail -n1)
if [[ -z "$VERSION" ]]; then
  echo "VERSION not set in $ENV_FILE" >&2
  exit 2
fi

SOURCE_REF="$LOCAL_IMAGE:$VERSION"
TARGET_REF="$REMOTE_REPO:$VERSION"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found in PATH. Install Docker or make sure it's available." >&2
  exit 3
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon not reachable. Start Docker Desktop or your daemon before pushing." >&2
  exit 5
fi

if ! docker image inspect "$SOURCE_REF" >/dev/null 2>&1; then
  echo "Local image '$SOURCE_REF' not found. Build the image first (e.g., ./build.sh)." >&2
  exit 4
fi

echo "Preparing to push image version: $VERSION"
echo "  Local image:  $SOURCE_REF"
echo "  Remote image: $TARGET_REF"
if $PUSH_LATEST; then
  echo "  Also pushing: $REMOTE_REPO:latest"
fi

if ! $ASSUME_YES; then
  read -r -p "Proceed with docker push? [y/N] " answer || true
  case "$answer" in
    [Yy]|[Yy][Ee][Ss]) : ;;
    *) echo "Aborted by user."; exit 0 ;;
  esac
fi

# Retag if the remote repo differs from the local name
if [[ "$REMOTE_REPO" != "$LOCAL_IMAGE" ]]; then
  docker tag "$SOURCE_REF" "$TARGET_REF"
fi

docker push "$TARGET_REF"

if $PUSH_LATEST; then
  docker tag "$SOURCE_REF" "$REMOTE_REPO:latest"
  docker push "$REMOTE_REPO:latest"
fi

echo "Push complete."
