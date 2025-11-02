#!/usr/bin/env bash
set -euo pipefail

# Generate examples/.devcontainer/devcontainer.json from template,
# inserting the current image name and version tag based on .env.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
TEMPLATE_FILE="$REPO_ROOT/examples/.devcontainer/devcontainer.json.template"
OUTPUT_FILE="$REPO_ROOT/examples/.devcontainer/devcontainer.json"

# Read VERSION from .env
if [[ ! -f "$ENV_FILE" ]]; then
  echo ".env not found: $ENV_FILE" >&2
  exit 1
fi

read_env() { awk -F '=' -v key="$1" '$1==key { gsub(/\r/,"",$2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }' "$ENV_FILE" | tail -n1; }
VERSION=$(read_env VERSION)
if [[ -z "${VERSION:-}" ]]; then
  echo "VERSION not set in $ENV_FILE" >&2
  exit 1
fi

# Determine IMAGE_NAME: prefer env var, then .env, then GHCR default derived from repo owner
IMAGE_NAME_ENV=${IMAGE_NAME:-}
if [[ -n "$IMAGE_NAME_ENV" ]]; then
  IMAGE_NAME="$IMAGE_NAME_ENV"
else
  IMAGE_NAME_FROM_ENV=$(read_env IMAGE_NAME || true)
  if [[ -n "$IMAGE_NAME_FROM_ENV" ]]; then
    IMAGE_NAME="$IMAGE_NAME_FROM_ENV"
  else
    GIT_ORIGIN=$(git -C "$REPO_ROOT" config --get remote.origin.url 2>/dev/null || true)
    OWNER=$(echo "$GIT_ORIGIN" | sed -E 's#.*github.com[:/]([^/]+)/.*#\1#' | tr '[:upper:]' '[:lower:]')
    if [[ -z "$OWNER" ]]; then
      OWNER="${USER:-$(whoami 2>/dev/null || echo unknown)}"
    fi
  IMAGE_NAME="ghcr.io/${OWNER}/student-env"
  fi
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Template not found: $TEMPLATE_FILE" >&2
  exit 1
fi

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

sed \
  -e "s|{{IMAGE_NAME}}|$IMAGE_NAME|g" \
  -e "s|{{IMAGE_TAG}}|$VERSION|g" \
  "$TEMPLATE_FILE" > "$tmpfile"

mv "$tmpfile" "$OUTPUT_FILE"

echo "Generated devcontainer: $OUTPUT_FILE -> $IMAGE_NAME:$VERSION"
