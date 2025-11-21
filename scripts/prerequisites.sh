#!/usr/bin/env bash
set -euo pipefail

ASSUME_YES=false

usage() {
  cat <<-'USAGE'
Usage: prerequisites.sh [--yes]

Check and install required tooling for building/publishing the student environment image.

Options:
  -y, --yes    Automatically install anything the script knows how to set up
  -h, --help   Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac

done

BLOCKERS=()
WARNINGS=()
FIXABLE_LABELS=()
FIXABLE_ACTIONS=()
INSTALL_ATTEMPTED=false
DOCKER_PRESENT=false

print_status() {
  printf '%s\n' "$1"
}

confirm() {
  local prompt="$1"
  local default_yes="${2:-true}"
  if $ASSUME_YES; then
    return 0
  fi
  local suffix answer
  if [[ "$default_yes" == "true" ]]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi
  read -r -p "$prompt $suffix " answer || true
  if [[ "$default_yes" == "true" ]]; then
    case "$answer" in
      [Nn]|[Nn][Oo]) return 1 ;;
      *) return 0 ;;
    esac
  else
    case "$answer" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

record_blocker() {
  BLOCKERS+=("$1")
}

record_warning() {
  WARNINGS+=("$1")
}

queue_install() {
  local action="$1"
  local label="$2"
  FIXABLE_ACTIONS+=("$action")
  FIXABLE_LABELS+=("$label")
}

apt_install() {
  local label="$1"
  shift
  local packages=("$@")
  echo "Installing $label via apt (${packages[*]})..."
  if ! command -v sudo >/dev/null 2>&1; then
    echo "❌ sudo not available to install $label" >&2
    return 1
  fi
  if ! sudo apt-get update; then
    echo "❌ apt-get update failed for $label" >&2
    return 1
  fi
  if ! sudo apt-get install -y "${packages[@]}"; then
    echo "❌ apt-get install failed for $label" >&2
    return 1
  fi
  return 0
}

install_curl() {
  apt_install "curl" curl
}

install_docker_suite() {
  if apt_install "Docker Engine" docker.io docker-buildx-plugin docker-compose-plugin; then
    sudo systemctl enable --now docker >/dev/null 2>&1 || true
    return 0
  fi
  return 1
}

install_gh_cli() {
  apt_install "GitHub CLI" gh
}

install_buildx_plugin() {
  if ! command -v docker >/dev/null 2>&1; then
    return 1
  fi
  local buildx_version="${BUILDX_VERSION:-v0.16.2}"
  local os arch asset_name download_url tmp_file plugin_dir plugin_path
  os=$(uname -s)
  arch=$(uname -m)
  case "$os" in
    Linux|Darwin) os=${os,,} ;;
    *) echo "❌ Unsupported OS for automatic buildx install: $os" >&2; return 1 ;;
  esac
  case "$arch" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "❌ Unsupported architecture for automatic buildx install: $arch" >&2; return 1 ;;
  esac
  if ! command -v curl >/dev/null 2>&1; then
    echo "❌ curl is required to install docker-buildx" >&2
    return 1
  fi
  asset_name="buildx-${buildx_version}.${os}-${arch}"
  download_url="https://github.com/docker/buildx/releases/download/${buildx_version}/${asset_name}"
  plugin_dir="${HOME}/.docker/cli-plugins"
  plugin_path="${plugin_dir}/docker-buildx"
  echo "Installing docker buildx plugin (${buildx_version}, ${os}-${arch})..."
  mkdir -p "$plugin_dir"
  tmp_file=$(mktemp)
  if ! curl -fsSL "$download_url" -o "$tmp_file"; then
    rm -f "$tmp_file"
    echo "❌ Failed to download ${download_url}" >&2
    return 1
  fi
  if ! install -m 0755 "$tmp_file" "$plugin_path"; then
    rm -f "$tmp_file"
    echo "❌ Failed to install buildx plugin to $plugin_path" >&2
    return 1
  fi
  rm -f "$tmp_file"
  if ! docker buildx version >/dev/null 2>&1; then
    echo "❌ docker buildx plugin installation failed" >&2
    return 1
  fi
  echo "✅ docker buildx plugin installed"
}

check_curl() {
  if command -v curl >/dev/null 2>&1; then
    local version
    version=$(curl --version 2>/dev/null | head -n1 | tr -d '\r')
    print_status "✅ curl: ${version:-unknown}"
  else
    print_status "❌ curl not found"
    queue_install install_curl "curl"
  fi
}

check_docker_cli() {
  DOCKER_PRESENT=false
  if ! command -v docker >/dev/null 2>&1; then
    print_status "❌ docker CLI not found"
    queue_install install_docker_suite "docker engine + CLI"
    return
  fi

  local client_version
  if ! client_version=$(docker --version 2>/dev/null | head -n1 | tr -d '\r'); then
    print_status "❌ docker CLI detected but unusable"
    queue_install install_docker_suite "docker engine + CLI"
    return
  fi
  print_status "✅ docker CLI: ${client_version:-unknown}"
  DOCKER_PRESENT=true

  if ! docker info >/dev/null 2>&1; then
    print_status "❌ docker daemon not reachable"
    record_blocker "Start Docker Desktop / docker service so 'docker info' succeeds"
    return
  fi

  local server_version
  server_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
  print_status "   docker server: ${server_version}"
}

check_gh_cli() {
  if ! command -v gh >/dev/null 2>&1; then
    print_status "❌ gh CLI not found"
    queue_install install_gh_cli "GitHub CLI"
    return
  fi

  local gh_version
  if ! gh_version=$(gh --version 2>/dev/null | head -n1 | tr -d '\r'); then
    print_status "❌ gh CLI detected but unusable"
    record_blocker "Reinstall GitHub CLI"
    return
  fi
  print_status "✅ gh CLI: ${gh_version:-unknown}"
}

check_gh_auth() {
  if ! command -v gh >/dev/null 2>&1; then
    return
  fi
  if gh auth status >/dev/null 2>&1; then
    print_status "✅ gh auth: logged in"
  else
    print_status "❌ gh auth status failed"
    record_blocker "Run 'gh auth login' so the build scripts can access GHCR"
  fi
}

check_buildx() {
  if ! $DOCKER_PRESENT; then
    return
  fi
  if docker buildx version >/dev/null 2>&1; then
    local buildx_version
    buildx_version=$(docker buildx version 2>/dev/null | head -n1 | tr -d '\r')
    print_status "✅ docker buildx: ${buildx_version:-available}"
  else
    print_status "❌ docker buildx plugin not found"
    queue_install install_buildx_plugin "docker buildx plugin"
  fi
}

perform_checks() {
  BLOCKERS=()
  WARNINGS=()
  FIXABLE_LABELS=()
  FIXABLE_ACTIONS=()
  check_curl
  check_docker_cli
  check_gh_cli
  check_gh_auth
  check_buildx
}

maybe_install_missing() {
  if ((${#FIXABLE_ACTIONS[@]} == 0)); then
    return 1
  fi
  echo -e "\nMissing prerequisites that can be installed automatically:"
  for label in "${FIXABLE_LABELS[@]}"; do
    echo "  - $label"
  done
  if confirm "Install the missing prerequisites now?"; then
    INSTALL_ATTEMPTED=true
    for idx in "${!FIXABLE_ACTIONS[@]}"; do
      local action="${FIXABLE_ACTIONS[$idx]}"
      local label="${FIXABLE_LABELS[$idx]}"
      if ! "$action"; then
        record_blocker "Automatic installation failed for $label"
      fi
    done
    return 0
  else
    record_blocker "Auto-installation declined for: ${FIXABLE_LABELS[*]}"
    return 1
  fi
}

summarize() {
  if ((${#BLOCKERS[@]} > 0)); then
    printf '\n❌ Missing prerequisites:\n'
    for item in "${BLOCKERS[@]}"; do
      printf '  - %s\n' "$item"
    done
    exit 1
  fi

  if ((${#WARNINGS[@]} > 0)); then
    printf '\n⚠ Warnings:\n'
    for item in "${WARNINGS[@]}"; do
      printf '  - %s\n' "$item"
    done
  fi

  printf '\n✅ All prerequisites satisfied.\n'
}

perform_checks
if maybe_install_missing; then
  perform_checks
  if ((${#FIXABLE_ACTIONS[@]} > 0)); then
    for label in "${FIXABLE_LABELS[@]}"; do
      record_blocker "$label is still missing after automatic installation"
    done
    FIXABLE_ACTIONS=()
    FIXABLE_LABELS=()
  fi
fi
summarize
