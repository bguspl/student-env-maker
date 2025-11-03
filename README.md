# Student Environment Image Maker

This repository builds and publishes the course's student environment Docker image and maintains the student starter workspace under `examples/`.

- Image: `ghcr.io/bguspl/student-env`
- Architectures: `linux/amd64` and `linux/arm64`
- Tooling: C/C++ (gcc-13, clang, cmake), Java (Temurin 21 + maven), Python 3.12, SQLite

## Quick Start

```bash
# Build multi-arch image
bash build.sh -b

# Build and push to GHCR
bash build.sh -b -p

# Generate examples.zip for students
bash build.sh -g

# Do everything (prompts for each step)
bash build.sh -a

# Do everything without prompts
bash build.sh -a -y
```

For all available options: `bash build.sh -h`

## Modular Scripts

Individual scripts in `scripts/` can be run independently:

```bash
# Build container image
bash scripts/build-container.sh

# Push to GitHub Container Registry
bash scripts/push-to-ghcr.sh

# Generate examples.zip
bash scripts/generate-examples.sh
```

Each script supports `--help` for detailed usage.

## Smoke Test

Test the image locally:

```bash
# Run an interactive container
docker run --rm -it ghcr.io/bguspl/student-env:latest bash

# Inside container (as user 'spl'):
cd ~/examples
bash run.sh
```

## Student Template

The `examples/` folder contains the starter workspace that students will download.

**⚠️ IMPORTANT:** The `examples/.devcontainer/devcontainer.json` file must always use the `:latest` tag for the image:

```json
"image": "ghcr.io/bguspl/student-env:latest"
```

**DO NOT** manually change `latest` to a version number. Keep it as `latest` for:
- Local development and testing
- Easy updates when rebuilding the image

When you run `bash build.sh --generate`, the script will automatically:
1. Verify the devcontainer uses `:latest`
2. Create a temporary copy
3. Replace `:latest` with the actual version number
4. Package it into `examples.zip` for students

This way, the repository always uses `:latest` for convenience, but students get a pinned version in the zip file.

## Prerequisites

- Docker Desktop with WSL integration (Windows) or Docker Engine (Linux/Mac)
- GitHub CLI (`gh`) - Install from https://cli.github.com/
- Authenticated with GitHub: `gh auth login`

## Build Options

Run `bash build.sh` without options to see all available commands:

```bash
bash build.sh
```

See `BUILD.md` for detailed build information and troubleshooting.
