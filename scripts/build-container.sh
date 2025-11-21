#!/usr/bin/env bash
set -euo pipefail

# Build multi-arch Docker image (amd64 + arm64)
# Can be called directly or from main build.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
IMAGE_NAME="ghcr.io/bguspl/student-env"

if [[ "${STUDENT_ENV_PREREQS_OK:-}" != "1" ]]; then
  PREREQ_ARGS=()
  if [[ "${STUDENT_ENV_ASSUME_YES:-false}" == "true" ]]; then
    PREREQ_ARGS+=(-y)
  fi
  bash "$REPO_ROOT/scripts/prerequisites.sh" "${PREREQ_ARGS[@]}"
fi

NO_CACHE=false

usage() {
  cat <<-USAGE
Usage: $(basename "$0") [--no-cache]

Build multi-arch Docker image (amd64 + arm64) using buildx and QEMU.

Options:
  --no-cache    Build without using cache (clean rebuild)
  -h, --help    Show this help message

Note: Requires 'gh' CLI for authentication and cache access.
      ARM64 build uses QEMU emulation (can take up to ~15 min).
USAGE
}

# Parse arguments
while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --no-cache) NO_CACHE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 2 ;;
  esac
done

# Read VERSION from .env
read_env() { awk -F '=' -v key="$1" '$1==key { gsub(/\r/,"",$2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }' "$ENV_FILE" | tail -n1; }
VERSION=$(read_env VERSION)

if [[ -z "$VERSION" ]]; then
  echo "❌ VERSION not found in .env" >&2
  exit 1
fi

echo "Building multi-arch image: $IMAGE_NAME:$VERSION"
echo -e "Note: ARM64 uses QEMU emulation (this can take up to ~15 min)\n"

# Check prerequisites
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker CLI not found" >&2
  exit 3
fi

if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon not reachable" >&2
  exit 5
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ gh CLI not found. Install from https://cli.github.com/" >&2
  exit 6
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "❌ Not authenticated with gh. Run: gh auth login" >&2
  exit 7
fi

# Login to GHCR for cache access
echo "Logging in to ghcr.io..."
gh auth token | docker login ghcr.io -u "$(gh api user -q .login)" --password-stdin

# Ensure buildx builder exists
if ! docker buildx inspect multiarch-builder >/dev/null 2>&1; then
  echo "Creating buildx builder with QEMU support..."
  docker buildx create --name multiarch-builder --driver docker-container --use
  docker buildx inspect --bootstrap
else
  docker buildx use multiarch-builder
fi

# Build multi-arch
BUILD_ARGS=(
  --platform linux/amd64,linux/arm64
  -t "$IMAGE_NAME:$VERSION"
  -t "$IMAGE_NAME:latest"
  --build-arg VERSION="$VERSION"
)

if $NO_CACHE; then
  echo "Building without cache..."
  BUILD_ARGS+=(--no-cache)
else
  BUILD_ARGS+=(
    --cache-from type=registry,ref="$IMAGE_NAME:buildcache"
    --cache-to type=registry,ref="$IMAGE_NAME:buildcache,mode=max"
  )
fi

docker buildx build "${BUILD_ARGS[@]}" "$REPO_ROOT"

echo -e "\n✅ Build complete!"
echo "   • $IMAGE_NAME:$VERSION"
echo "   • $IMAGE_NAME:latest"
