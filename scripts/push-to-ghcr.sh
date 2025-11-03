#!/usr/bin/env bash
set -euo pipefail

# Push multi-arch Docker image to GHCR
# Can be called directly or from main build.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
IMAGE_NAME="ghcr.io/bguspl/student-env"

usage() {
  cat <<-USAGE
Usage: $(basename "$0")

Push multi-arch Docker image to GitHub Container Registry.

Options:
  -h, --help    Show this help message

Note: Requires 'gh' CLI for authentication.
      Image must be built first using build-container.sh.
USAGE
}

# Parse arguments
while [[ ${#} -gt 0 ]]; do
  case "$1" in
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

echo "Pushing $IMAGE_NAME:$VERSION and :latest to GHCR..."

# Check prerequisites
if ! command -v gh >/dev/null 2>&1; then
  echo "❌ gh CLI not found. Install from https://cli.github.com/" >&2
  exit 6
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "❌ Not authenticated with gh. Run: gh auth login" >&2
  exit 7
fi

# Login to GHCR
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

# Push multi-arch
docker buildx build --platform linux/amd64,linux/arm64 \
  -t "$IMAGE_NAME:$VERSION" \
  -t "$IMAGE_NAME:latest" \
  --cache-from type=registry,ref="$IMAGE_NAME:buildcache" \
  --build-arg VERSION="$VERSION" \
  --push \
  "$REPO_ROOT"

echo -e "\n✅ Push complete!"
echo "   • $IMAGE_NAME:$VERSION"
echo "   • $IMAGE_NAME:latest"
echo ""

echo "Verifying multi-arch manifest..."
docker buildx imagetools inspect "$IMAGE_NAME:$VERSION"
