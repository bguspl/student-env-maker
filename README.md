# Student Environment Image Maker

This repository builds and publishes the course’s student environment Docker image and maintains the embedded student starter workspace under `examples/` (as a submodule).

- Image: `ghcr.io/<owner>/student-env` (e.g., `ghcr.io/bguspl/student-env`)
- Architectures: `linux/amd64` and `linux/arm64` (built locally with QEMU)
- Tooling: C/C++ (gcc-13, clang, cmake), Java (Temurin 21 + maven), Python 3.12, SQLite

Maintainers: see `BUILD.md` for multi-arch builds, versioning, and troubleshooting.

## Local build (single-arch, for testing)

```bash
# Build with existing version (WSL recommended)
bash build.sh --yes

# Bump version and build (updates VERSION in .env)
bash build.sh --bump --yes
```

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

## Build and push multi-arch images to GHCR

For production releases (amd64 + arm64):

```bash
# Build and push multi-arch images
./push.sh --yes

# Or bump version and push
./push.sh --bump --yes
```

This uses Docker Buildx with QEMU emulation to build both architectures locally and pushes to GitHub Container Registry. See `BUILD.md` for details.

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
