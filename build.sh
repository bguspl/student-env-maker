#!/usr/bin/env bash
set -euo pipefail

# Build the Docker image (designed for WSL) and optionally bump the version.
# Usage: ./build.sh [--bump] [--yes]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use files relative to the script directory so the script behaves the same when invoked from any cwd
ENV_FILE="$SCRIPT_DIR/.env"
IMAGE_NAME=${IMAGE_NAME:-}

BUMP=false
ASSUME_YES=false

usage() {
  cat <<-USAGE
Usage: $(basename "$0") [--bump] [--yes]

Options:
  --bump        Increment the version before building the image
  --yes         Skip confirmation prompt
  -h, --help    Show this help

Environment variables:
  IMAGE_NAME    Image name (defaults to .env or ghcr.io/<owner>/student-env)

Note: This builds a single-architecture image for local testing.
      For multi-arch builds (amd64 + arm64), use GitHub Actions.
USAGE
}

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --bump) BUMP=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

# Ensure .env exists with a VERSION entry; if not, initialize it
if [[ ! -f "$ENV_FILE" ]]; then
  echo "VERSION=0.1" > "$ENV_FILE"
fi

# Read key from .env (ignoring comments and whitespace)
read_env() { awk -F '=' -v key="$1" '$1==key { gsub(/\r/,"",$2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }' "$ENV_FILE" | tail -n1; }
# Read VERSION from .env
CURRENT_VERSION=$(read_env VERSION)
if [[ -z "${CURRENT_VERSION:-}" ]]; then
  echo "VERSION not found in .env; initializing to 0.1" >&2
  CURRENT_VERSION="0.1"
  printf "VERSION=%s\n" "$CURRENT_VERSION" > "$ENV_FILE"
fi
if ! [[ $CURRENT_VERSION =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo "Current version '$CURRENT_VERSION' from .env doesn't look numeric. Expect formats like '0.1' or '1.2.3'." >&2
  exit 2
fi

# Possibly bump the last numeric component of a semantic version.
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
    # fallback to previous behaviour for unexpected formats
    TARGET_VERSION=$(awk -v v="$CURRENT_VERSION" 'BEGIN{printf "%.1f", v+0.1}')
  fi
fi

if $BUMP; then
  echo "Current version: $CURRENT_VERSION"
  echo "Bumped version:  $TARGET_VERSION"
else
  echo "Using version:   $TARGET_VERSION"
fi

if ! $ASSUME_YES; then
  if $BUMP; then
    prompt="Proceed to update '.env' (VERSION=$TARGET_VERSION) and build Docker image? [y/N] "
  else
    prompt="Proceed to build Docker image using version '$TARGET_VERSION' from .env? [y/N] "
  fi
  read -r -p "$prompt" answer || true
  case "$answer" in
    [Yy]|[Yy][Ee][Ss]) : ;;
    *) echo "Aborted by user."; exit 0 ;;
  esac
fi

# Update or add a key=value in .env
update_env_kv() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^\s*${key}\s*=" "$file"; then
    sed -i "s|^\s*${key}\s*=.*|${key}=${value}|" "$file"
  else
    printf "\n%s=%s\n" "$key" "$value" >> "$file"
  fi
}

if $BUMP; then
  update_env_kv "$ENV_FILE" VERSION "$TARGET_VERSION"
  echo "Updated $ENV_FILE (VERSION=$TARGET_VERSION)"
else
  # Ensure .env has the computed TARGET_VERSION (no-op if equal)
  update_env_kv "$ENV_FILE" VERSION "$TARGET_VERSION"
  echo "Wrote $ENV_FILE"
fi

# Ensure IMAGE_NAME is set in .env; prefer existing, else compute GHCR default
if [[ -z "${IMAGE_NAME:-}" ]]; then
  IMAGE_NAME_FROM_ENV=$(read_env IMAGE_NAME || true)
  if [[ -n "$IMAGE_NAME_FROM_ENV" ]]; then
    IMAGE_NAME="$IMAGE_NAME_FROM_ENV"
  else
    GIT_ORIGIN=$(git -C "$SCRIPT_DIR" config --get remote.origin.url 2>/dev/null || true)
    OWNER=$(echo "$GIT_ORIGIN" | sed -E 's#.*github.com[:/]([^/]+)/.*#\1#' | tr '[:upper:]' '[:lower:]')
    if [[ -z "$OWNER" ]]; then
      OWNER="${USER:-$(whoami 2>/dev/null || echo unknown)}"
    fi
  IMAGE_NAME="ghcr.io/${OWNER}/student-env"
  fi
fi
update_env_kv "$ENV_FILE" IMAGE_NAME "$IMAGE_NAME"
echo "Using IMAGE_NAME=$IMAGE_NAME"

# Note: If 'examples' is a git submodule, avoid mutating it automatically here.
# To pin the student devcontainer to this version, run:
#   IMAGE_NAME=ghcr.io/OWNER/student-env bash scripts/generate-devcontainer.sh
# inside the submodule and commit there, then update the submodule pointer.

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found in PATH. Install Docker or make sure it's available in WSL." >&2
  exit 3
fi

# Verify Docker daemon is reachable before attempting compose operations.
if ! docker info >/dev/null 2>&1; then
  cat <<-MSG >&2
Docker appears to be installed, but the Docker daemon is not reachable from this environment.

Common causes and fixes:
  - Docker Desktop (Windows) is not running. Start Docker Desktop and ensure WSL integration is enabled for your distro.
  - You're inside a WSL distro that does not run the Docker daemon. Start it (for example: 'sudo service docker start').
  - If you expect to use the Windows Docker daemon from WSL, ensure WSL integration is enabled in Docker Desktop settings.

Quick checks you can run now:
  - 'docker info'  (should print daemon info)
  - 'ps aux | grep dockerd'  (look for the dockerd process)

Exiting because compose needs a reachable Docker daemon.
MSG
  exit 3
fi

# Prefer 'docker compose' (modern) but fall back to 'docker-compose'
COMPOSE_CMD=()
COMPOSE_GLOBAL_ARGS=()
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
  COMPOSE_GLOBAL_ARGS=(--project-directory "$SCRIPT_DIR" --progress plain -f "$SCRIPT_DIR/docker-compose.yml")
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
  COMPOSE_GLOBAL_ARGS=(--project-directory "$SCRIPT_DIR" -f "$SCRIPT_DIR/docker-compose.yml")
else
  echo "Neither 'docker compose' nor 'docker-compose' found in PATH." >&2
  exit 4
fi

echo "Building Docker image via compose (version: ${TARGET_VERSION})"
"${COMPOSE_CMD[@]}" "${COMPOSE_GLOBAL_ARGS[@]}" build --pull app

# Ensure latest tag exists
IMAGE_FULL="${IMAGE_NAME}:${TARGET_VERSION}"
if docker image inspect "$IMAGE_FULL" >/dev/null 2>&1; then
  docker tag "$IMAGE_FULL" "${IMAGE_NAME}:latest" || true
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "✅ Build complete!"
  echo "═══════════════════════════════════════════════════════════"
  echo "Docker image built and tagged:"
  echo "  • $IMAGE_FULL"
  echo "  • ${IMAGE_NAME}:latest"
  echo ""
else
  echo "Warning: Expected image $IMAGE_FULL not found after compose build." >&2
fi

exit 0
