# Building and Publishing Multi-Arch Docker Images (Maintainers)

This guide explains how to build and publish the student environment image locally using Docker Buildx with QEMU emulation. It's intended for the course staff.

## Quick Start

```bash
# Build and push multi-arch (amd64 + arm64) images to GHCR
./push.sh --yes

# Or bump version and push
./push.sh --bump --yes
```

## How It Works

### Local Multi-Arch Builds

The `push.sh` script:
1. Reads VERSION from `.env` (or bumps it if `--bump` is used)
2. Authenticates to GHCR using `gh` CLI
3. Uses Docker Buildx with QEMU to build both `linux/amd64` and `linux/arm64` images
4. Pushes the multi-arch manifest to GitHub Container Registry (GHCR)

**Build times:**
- AMD64: ~2-3 minutes (native)
- ARM64: ~10-15 minutes (QEMU emulation)

### What Gets Built

- Platforms: `linux/amd64` and `linux/arm64`
- Registry: GitHub Container Registry (GHCR)
- Tags:
  - `ghcr.io/<owner>/student-env:<version>` (version read from `.env`)
  - `ghcr.io/<owner>/student-env:latest`
- Build Cache: Stored in GHCR as `ghcr.io/<owner>/student-env:buildcache`

Note: `<owner>` is your GitHub org (e.g., `bguspl`) or username.

## Prerequisites

1. **Docker Desktop** (with WSL integration if on Windows) or Docker Engine
2. **GitHub CLI** (`gh`): Install from https://cli.github.com/
3. **Authenticated**: Run `gh auth login` and grant the required scopes

## First Time Setup

```bash
# 1) Install gh CLI (if not already)
# Visit https://cli.github.com/

# 2) Authenticate with GitHub
gh auth login
# Choose: GitHub.com, HTTPS, authenticate in browser
# Grant required scopes when prompted

# 3) Ensure Docker is running
docker info

# 4) Build and push
./push.sh --yes
```

After first push: Make the GHCR package public so students can pull without auth:
1. Go to: https://github.com/orgs/<owner>/packages (e.g., https://github.com/orgs/bguspl/packages)
2. Find `student-env`
3. Package settings → Visibility → Public

## Version Management

To bump the version and publish:

```bash
./push.sh --bump --yes
```

This will:
- Increment the last component of VERSION in `.env` (e.g., 0.3 → 0.4)
- Build both architectures
- Push to GHCR with the new version tag and `:latest`

## Local Testing (single-arch, fast)

For quick local testing without pushing:

```bash
# Build single-arch image using build.sh
bash build.sh --yes

# Test it
docker run --rm -it ghcr.io/bguspl/student-env:$(awk -F '=' '/^\s*VERSION\s*=/{gsub(/\r/,"",$2); gsub(/\s+/,"",$2); print $2}' .env) bash
```

## Troubleshooting

- **"gh CLI not found"**: Install from https://cli.github.com/
- **"Not authenticated with gh"**: Run `gh auth login` and complete browser auth
- **"Docker daemon not reachable"**: Start Docker Desktop or your Docker daemon
- **ARM64 build slow**: Expected — QEMU emulation adds ~10-15 min build time
- **"multiarch-builder not found"**: The script will create it automatically on first run

## Monitoring Builds

Watch the terminal output during `./push.sh`:
- AMD64 build completes first (~2-3 min)
- ARM64 build follows (~10-15 min via QEMU)
- Final step verifies the multi-arch manifest

To verify the published image:

```bash
docker buildx imagetools inspect ghcr.io/bguspl/student-env:latest
```
