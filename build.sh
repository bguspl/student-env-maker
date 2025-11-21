#!/usr/bin/env bash
set -euo pipefail

# Unified build script - coordinates build, push, and packaging tasks
# Usage: ./build.sh [OPTIONS]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DO_ALL=false
ASSUME_YES=false
DO_BUILD=false
DO_PUSH=false
DO_GENERATE=false
DO_BUMP=false
DO_CLEAN=false
DO_REBUILD=false

usage() {
  cat <<-USAGE
Usage: $(basename "$0") [OPTIONS]

Build, push, and package the student environment Docker image.

Options:
  -a, --all         Perform all steps (build, push, generate)
  -y, --yes         Skip confirmation prompts
  -b, --build       Build the Docker image (amd64 + arm64)
  -p, --push        Push the image to GHCR
  -g, --generate    Generate examples.zip for students
      --bump        Increment version number before operations
      --rebuild     Build without using cache
      --clean       Clean build cache (cannot combine with other options)
  -h, --help        Show this help message

Without options, prints this help message.

Examples:
  $(basename "$0") -b -y                  # Build image
  $(basename "$0") --bump -a -y           # Bump version, build, push, and generate zip
  $(basename "$0") --rebuild -y           # Rebuild from scratch without cache
  $(basename "$0") --clean -y             # Clean build cache
USAGE
}

# Parse arguments
if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    -a|--all) DO_BUILD=true; DO_PUSH=true; DO_GENERATE=true; DO_ALL=true; shift ;;
    -y|--yes) ASSUME_YES=true; shift ;;
    -b|--build) DO_BUILD=true; shift ;;
    -p|--push) DO_PUSH=true; shift ;;
    -g|--generate) DO_GENERATE=true; shift ;;
    --bump) DO_BUMP=true; shift ;;
    --rebuild) DO_REBUILD=true; shift ;;
    --clean) DO_CLEAN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 2 ;;
  esac
done

# Validate options
if $DO_CLEAN; then
  if $DO_BUILD || $DO_PUSH || $DO_GENERATE || $DO_BUMP || $DO_REBUILD; then
    echo "❌ --clean cannot be combined with other options" >&2
    exit 2
  fi
fi

# Helper: confirm action
# Usage: confirm "prompt text" [default_yes]
# If default_yes is "true", default is Y, otherwise default is N
confirm() {
  if $ASSUME_YES; then
    return 0
  fi
  local prompt="$1"
  local default_yes="${2:-true}"
  
  if [[ "$default_yes" == "true" ]]; then
    read -r -p "$prompt [Y/n] " answer || true
    case "$answer" in
      [Nn]|[Nn][Oo]) echo "Skipped."; return 1 ;;
      *) return 0 ;;
    esac
  else
    read -r -p "$prompt [y/N] " answer || true
    case "$answer" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      *) echo "Skipped."; return 1 ;;
    esac
  fi
}

if $ASSUME_YES; then
  export STUDENT_ENV_ASSUME_YES=true
else
  export STUDENT_ENV_ASSUME_YES=false
fi

NEEDS_PREREQS=false
if $DO_BUILD || $DO_PUSH || $DO_CLEAN; then
  NEEDS_PREREQS=true
fi

if $NEEDS_PREREQS; then
  PREREQ_ARGS=()
  if $ASSUME_YES; then
    PREREQ_ARGS+=(-y)
  fi
  bash "$SCRIPT_DIR/scripts/prerequisites.sh" "${PREREQ_ARGS[@]}"
  export STUDENT_ENV_PREREQS_OK=1
fi

# Handle --clean separately
if $DO_CLEAN; then
  echo "════════════════════════════════════════════════════════════"
  echo "CLEANING BUILD CACHE"
  echo "════════════════════════════════════════════════════════════"
  docker buildx prune -f
  echo -e "\n✅ Build cache cleaned!"
  exit 0
fi

# Show current version
ENV_FILE="$SCRIPT_DIR/.env"
CURRENT_VERSION=$(awk -F '=' '/^\s*VERSION\s*=/{gsub(/\r/,"",$2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$ENV_FILE" | tail -n1)

# Bump version if requested
if $DO_BUMP; then
  IFS='.' read -ra parts <<< "$CURRENT_VERSION"
  last_idx=$((${#parts[@]} - 1))
  if [[ ${parts[$last_idx]} =~ ^[0-9]+$ ]]; then
    parts[$last_idx]=$((parts[$last_idx] + 1))
    VERSION="${parts[0]}"
    for i in "${parts[@]:1}"; do
      VERSION+=".${i}"
    done
  else
    VERSION=$(awk -v v="$CURRENT_VERSION" 'BEGIN{printf "%.1f", v+0.1}')
  fi
  
  # Update .env
  if grep -qE "^\s*VERSION\s*=" "$ENV_FILE"; then
    sed -i "s|^\s*VERSION\s*=.*|VERSION=$VERSION|" "$ENV_FILE"
  else
    echo "VERSION=$VERSION" >> "$ENV_FILE"
  fi
  
  echo "Version bumped: $CURRENT_VERSION → $VERSION"
else
  VERSION="$CURRENT_VERSION"
  echo "Current version: $VERSION (use --bump to increment)"
fi

if $DO_BUILD; then
  echo -e "\n# BUILD"
  echo "════════════════════════════════════════════════════════════"
  echo "BUILDING DOCKER IMAGE"
  echo "════════════════════════════════════════════════════════════"
  # Only prompt if --all was used (and --yes wasn't)
  if ! $DO_ALL || confirm "Build multi-arch image ghcr.io/bguspl/student-env:$VERSION?"; then
    BUILD_ARGS=()
    if $DO_REBUILD; then
      BUILD_ARGS+=(--no-cache)
    fi
    if [ ${#BUILD_ARGS[@]} -eq 0 ]; then
      bash "$SCRIPT_DIR/scripts/build-container.sh"
    else
      bash "$SCRIPT_DIR/scripts/build-container.sh" "${BUILD_ARGS[@]}"
    fi
    echo ""
  fi
fi

# PUSH
if $DO_PUSH; then
  echo -e "\n# PUSH"
  echo "════════════════════════════════════════════════════════════"
  echo "PUSHING TO GHCR"
  echo "════════════════════════════════════════════════════════════"
  # Only prompt if --all was used (and --yes wasn't)
  if ! $DO_ALL || confirm "Push ghcr.io/bguspl/student-env:$VERSION and :latest to GitHub Container Registry?"; then
    bash "$SCRIPT_DIR/scripts/push-to-ghcr.sh"
    echo ""
  fi
fi

# GENERATE
if $DO_GENERATE; then
  echo -e "\n# GENERATE"
  echo "════════════════════════════════════════════════════════════"
  echo "GENERATING EXAMPLES.ZIP"
  echo "════════════════════════════════════════════════════════════"
  # Only prompt if --all was used (and --yes wasn't)
  if ! $DO_ALL || confirm "Generate examples.zip with version $VERSION?"; then
    bash "$SCRIPT_DIR/scripts/generate-examples.sh"
    echo ""
  fi
fi

if $DO_BUILD || $DO_PUSH || $DO_GENERATE; then
  echo "════════════════════════════════════════════════════════════"
  echo "✅ ALL DONE!"
  echo "════════════════════════════════════════════════════════════"
fi
