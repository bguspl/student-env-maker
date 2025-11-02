#!/usr/bin/env bash
set -euo pipefail

# Build multi-arch (amd64 + arm64) Docker images using QEMU and push to GHCR.
# This script builds both architectures locally using buildx + QEMU emulation,
# then pushes the multi-arch manifest to the registry.
# Usage: ./push.sh [--bump] [--no-latest] [--yes]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Prefer IMAGE_NAME from .env (written by build.sh); fallback to GHCR
IMAGE_FROM_ENV=$(awk -F '=' '/^\s*IMAGE_NAME\s*=/{gsub(/\r/,"",$2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$ENV_FILE" | tail -n1)
IMAGE_NAME="${IMAGE_FROM_ENV:-ghcr.io/bguspl/student-env}"
PUSH_LATEST=true
ASSUME_YES=false
BUMP=false

usage() {
  cat <<-USAGE
Usage: $(basename "$0") [--bump] [--no-latest] [--yes]

Builds multi-arch (amd64 + arm64) Docker images using QEMU and pushes to GHCR.

Options:
  --bump            Bump version before building (increments VERSION in .env)
  --no-latest       Skip pushing the 'latest' tag
  --yes             Skip confirmation prompts
  -h, --help        Show this help message

Environment:
  IMAGE_NAME from .env (default: ghcr.io/bguspl/student-env)
  VERSION from .env

Note: Requires 'gh' CLI for authentication (run 'gh auth login' first).
      ARM64 build uses QEMU emulation (~10-15 min build time).
USAGE
}

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --bump)
      BUMP=true; shift ;;
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
  echo ".env not found; initializing with VERSION=0.1" >&2
  echo "VERSION=0.1" > "$ENV_FILE"
  echo "IMAGE_NAME=$IMAGE_NAME" >> "$ENV_FILE"
fi

# Read VERSION from .env
CURRENT_VERSION=$(awk -F '=' '/^\s*VERSION\s*=/{gsub(/\r/,"",$2); gsub(/\s+/,"",$2); print $2}' "$ENV_FILE" | tail -n1)
if [[ -z "$CURRENT_VERSION" ]]; then
  echo "VERSION not found in .env; initializing to 0.1" >&2
  CURRENT_VERSION="0.1"
  echo "VERSION=$CURRENT_VERSION" > "$ENV_FILE"
  echo "IMAGE_NAME=$IMAGE_NAME" >> "$ENV_FILE"
fi

# Bump version if requested
TARGET_VERSION="$CURRENT_VERSION"
if $BUMP; then
  IFS='.' read -ra parts <<< "$CURRENT_VERSION"
  last_idx=$((${#parts[@]} - 1))
  if [[ ${parts[$last_idx]} =~ ^[0-9]+$ ]]; then
    parts[$last_idx]=$((parts[$last_idx] + 1))
    TARGET_VERSION="${parts[0]}"
    for i in "${parts[@]:1}"; do
      TARGET_VERSION+=".${i}"
    done
  else
    TARGET_VERSION=$(awk -v v="$CURRENT_VERSION" 'BEGIN{printf "%.1f", v+0.1}')
  fi
  echo "Bumping version: $CURRENT_VERSION → $TARGET_VERSION"
  # Update .env
  if grep -qE "^\s*VERSION\s*=" "$ENV_FILE"; then
    sed -i "s|^\s*VERSION\s*=.*|VERSION=$TARGET_VERSION|" "$ENV_FILE"
  else
    echo "VERSION=$TARGET_VERSION" >> "$ENV_FILE"
  fi
else
  echo "Using version: $TARGET_VERSION"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found in PATH. Install Docker or make sure it's available." >&2
  exit 3
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon not reachable. Start Docker Desktop or your daemon before building." >&2
  exit 5
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found. Install it from https://cli.github.com/ and run 'gh auth login'." >&2
  exit 6
fi

# Check gh auth
if ! gh auth status >/dev/null 2>&1; then
  echo "Not authenticated with gh. Run: gh auth login" >&2
  exit 7
fi

echo "Preparing to build and push multi-arch images (amd64 + arm64 via QEMU)"
echo "  Image name: $IMAGE_NAME"
echo "  Version:    $TARGET_VERSION"
if $PUSH_LATEST; then
  echo "  Tags:       $IMAGE_NAME:$TARGET_VERSION, $IMAGE_NAME:latest"
else
  echo "  Tags:       $IMAGE_NAME:$TARGET_VERSION"
fi
echo ""
echo "Note: ARM64 build uses QEMU emulation (~10-15 min build time expected)"

if ! $ASSUME_YES; then
  read -r -p "Proceed with multi-arch build and push to GHCR? [y/N] " answer || true
  case "$answer" in
    [Yy]|[Yy][Ee][Ss]) : ;;
    *) echo "Aborted by user."; exit 0 ;;
  esac
fi

# Login to GHCR using gh token
echo "Logging in to ghcr.io..."
gh auth token | docker login ghcr.io -u "$(gh api user -q .login)" --password-stdin

# Ensure buildx builder with QEMU support exists
if ! docker buildx inspect multiarch-builder >/dev/null 2>&1; then
  echo "Creating buildx builder with QEMU support..."
  docker buildx create --name multiarch-builder --driver docker-container --use
  docker buildx inspect --bootstrap
fi

# Build and push multi-arch image
TAGS="-t $IMAGE_NAME:$TARGET_VERSION"
if $PUSH_LATEST; then
  TAGS="$TAGS -t $IMAGE_NAME:latest"
fi

echo ""
echo "Building multi-arch image (this will take 10-15 minutes for ARM64 via QEMU)..."
docker buildx build --platform linux/amd64,linux/arm64 \
  $TAGS \
  --push \
  --cache-from type=registry,ref=$IMAGE_NAME:buildcache \
  --cache-to type=registry,ref=$IMAGE_NAME:buildcache,mode=max \
  "$SCRIPT_DIR"

echo ""
echo "✅ Multi-arch build and push complete!"
echo "Verifying multi-arch manifest..."
docker buildx imagetools inspect "$IMAGE_NAME:$TARGET_VERSION"

echo ""
echo "Images pushed:"
echo "  • $IMAGE_NAME:$TARGET_VERSION"
if $PUSH_LATEST; then
  echo "  • $IMAGE_NAME:latest"
fi
