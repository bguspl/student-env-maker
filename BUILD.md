# CI/CD: Multi-Arch Docker Builds (Maintainers)

This guide explains how this repository builds and publishes the student environment image using GitHub Actions. It’s intended for the course staff.

## How It Works

### Automatic Builds

The workflow runs automatically when you push changes to:
- `Dockerfile`
- `examples/**` (any file in examples)
- `.env` (version is read from here)
- `.github/workflows/docker-build.yml`

### Manual Builds

Note: Local manual multi-arch builds on an amd64 host are not supported in this project. The required arm64 emulation (QEMU) on Ubuntu 22.04 is unstable and can crash during libc post-install steps. Use GitHub Actions (which runs native arm64 and amd64) for all multi-arch releases. You can still build a single-architecture image locally with `bash build.sh` for quick testing.

### What Gets Built

- Platforms: `linux/amd64` and `linux/arm64`
- Registry: GitHub Container Registry (GHCR)
- Tags:
  - `ghcr.io/<owner>/student-env:<version>` (version read from `.env`)
  - `ghcr.io/<owner>/student-env:latest`
- Build Cache: Stored in GHCR as `ghcr.io/<owner>/student-env:buildcache`

Note: `<owner>` is your GitHub org (e.g., `bguspl`) or username.

Why GitHub Actions? Multi-arch builds using local QEMU emulation are unreliable on Ubuntu 22.04 arm64 (libc segfaults). GitHub Actions uses native arm64 runners, making builds faster and reliable.

## First Time Setup

```bash
# 1) Commit the workflow and Dockerfile changes
git add .github/workflows/docker-build.yml Dockerfile docs/ci.md .env
git commit -m "Add GitHub Actions for native multi-arch builds using .env version"

# 2) Push to GitHub
git push origin master

# 3) Monitor the workflow in the Actions tab
```

After First Push: Make the GHCR package public so students can pull without auth:
1. Go to: https://github.com/orgs/bguspl/packages
2. Find `student-env`
3. Package settings → Visibility → Public

## Version Management

To bump the version and trigger a release:

```bash
bash build.sh --bump
git add .env
git commit -m "Bump version to $(awk -F '=' '/^\s*VERSION\s*=/{gsub(/\r/,"",$2); gsub(/\s+/,"",$2); print $2}' .env)"
git push
```

The GitHub Action will read `.env` and tag the images accordingly.

## Troubleshooting

- "no basic auth credentials": ensure workflow has `permissions: packages: write` or set repo Settings → Actions → Workflow permissions → Read and write permissions.
- "submodule not found": the workflow initializes submodules; verify `examples` exists and is reachable.
- Slow first build: cache warms up after the initial run; subsequent builds are faster.

## Monitoring Builds

- Actions tab (e.g., https://github.com/bguspl/student-env-maker/actions)
- Check the "Build and push" step logs and the final manifest inspection.
