# Student Environment Image Maker

This repository builds and publishes the course’s student environment Docker image and maintains the embedded student starter workspace under `examples/` (as a submodule).

- Image: `ghcr.io/<owner>/student-env` (e.g., `ghcr.io/bguspl/student-env`)
- Architectures: `linux/amd64` and `linux/arm64` (built by GitHub Actions)
- Tooling: C/C++ (gcc-13, clang, cmake), Java (Temurin 21 + maven), Python 3.12, SQLite

Maintainers: see `BUILD.md` for multi-arch builds, versioning, and troubleshooting.

## Local build (single-arch, for testing)

```bash
# Build with existing version (WSL recommended)
bash build.sh --yes

# Bump version and build (updates VERSION in .env)
bash build.sh --bump --yes
```

Note: Multi-arch releases are built on GitHub Actions (local QEMU is intentionally not supported on Ubuntu 22.04 arm64).

Use compose directly (uses `.env` written by the build script):

```bash
docker compose build --pull --progress=plain app
```

## Smoke test

Start an interactive container and run the example smoke-test script included in the image:

```bash
# run an interactive container (mount workspace if desired)
VER=$(awk -F '=' '/^\s*VERSION\s*=/{gsub(/\r/,"",$2); gsub(/\s+/,"",$2); print $2}' .env | tail -n1)
docker run --rm -it ghcr.io/bguspl/student-env:$VER bash

# inside container (as user 'spl'):
cd ~/examples
bash run-examples.sh
```

## Release (multi-arch via GitHub Actions)

Push to GitHub to trigger the automated multi-arch build:

```bash
# Bump version and push
bash build.sh --bump
git add .env
git commit -m "Bump version to $(awk -F '=' '/^\s*VERSION\s*=/{gsub(/\r/,"",$2); gsub(/\s+/,"",$2); print $2}' .env)"
git push
```

GitHub Actions will automatically build for both amd64 and arm64 and push to GHCR. See `BUILD.md` for details.

## Student template (submodule)

- `examples/` behaves like a student starter repository. Update files here as needed (add assignments, starter code, etc.).
- The Dev Container definition inside `examples/.devcontainer/` is generated from `devcontainer.json.template` using `scripts/generate-devcontainer.sh`.
- `build.sh` automatically writes `.env` so the image tag always matches the version in that file.

Regenerate manually (for example after editing the template):

```bash
bash scripts/generate-devcontainer.sh

# or target a different registry/repo
IMAGE_NAME=ghcr.io/bguspl/student-env bash scripts/generate-devcontainer.sh
```

### Submodule setup

The `examples/` folder is a Git submodule so it can evolve independently of the image builder. 

After cloning the main repo, run:

```bash
git submodule update --init --recursive
```

If your Git blocks the local file protocol for submodules, you might need to allow it just for this clone:

```bash
git -c protocol.file.allow=always submodule update --init --recursive
```

To update to the latest student template commit in the submodule:

```bash
cd examples
git pull origin master   # or main, depending on the submodule default branch
cd ..
git add examples
git commit -m "Update examples submodule"
```

Student-facing onboarding lives in the student template repository. This repository is intended for the course staff.
