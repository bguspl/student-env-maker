#!/usr/bin/env bash
set -euo pipefail

# Generate examples.zip for students
# Can be called directly or from main build.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
IMAGE_NAME="ghcr.io/bguspl/student-env"

usage() {
  cat <<-USAGE
Usage: $(basename "$0")

Generate examples.zip with versioned devcontainer.json for students.

Options:
  -h, --help    Show this help message

Note: Verifies that devcontainer.json uses ':latest' tag in the repository.
      Automatically replaces ':latest' with current version in the zip file.
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

echo "Generating examples.zip with version: $VERSION"

DEVCONTAINER_JSON="$REPO_ROOT/examples/.devcontainer/devcontainer.json"

# Check that devcontainer.json exists and uses "latest"
if [[ ! -f "$DEVCONTAINER_JSON" ]]; then
  echo "❌ $DEVCONTAINER_JSON not found" >&2
  exit 8
fi

if ! grep -q '"image".*:latest"' "$DEVCONTAINER_JSON"; then
  echo -e "\n❌ ERROR: examples/.devcontainer/devcontainer.json must use ':latest' tag\n" >&2
  echo "   Found:" >&2
  grep '"image"' "$DEVCONTAINER_JSON" | sed 's/^/   /' >&2
  echo -e "\n   Expected:" >&2
  echo "   \"image\": \"$IMAGE_NAME:latest\"" >&2
  echo -e "\n   DO NOT manually change 'latest' to a version number in the repository." >&2
  echo "   Keep it as 'latest' for local development and testing." >&2
  echo -e "   This script automatically replaces it with $VERSION when creating the zip.\n" >&2
  exit 9
fi

EXAMPLES_DIR="$REPO_ROOT/examples"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Creating temporary copy..."
cp -r "$EXAMPLES_DIR" "$TEMP_DIR/examples"

# Replace "latest" with version number in the temporary copy
TEMP_DEVCONTAINER="$TEMP_DIR/examples/.devcontainer/devcontainer.json"
sed -i "s|:latest\"|:$VERSION\"|g" "$TEMP_DEVCONTAINER"

echo "Version replacement verified:"
grep '"image"' "$TEMP_DEVCONTAINER" | sed 's/^/   /'

# Create zip
OUTPUT_ZIP="$REPO_ROOT/examples.zip"
echo -e "\nCreating $OUTPUT_ZIP..."
cd "$TEMP_DIR"
zip -r "$OUTPUT_ZIP" examples/ -x "*.git*" "*.DS_Store" "__pycache__/*" "*.pyc" > /dev/null

echo -e "\n✅ Generated: examples.zip"
echo "   Version in zip: $VERSION"
echo "   Version in repo: latest (for local testing)"
