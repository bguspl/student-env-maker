# Building and Publishing (Maintainers)

This guide explains the build process for maintainers.

## Quick Reference

```bash
# Build multi-arch image (amd64 + arm64)
bash build.sh -b

# Build and push to GHCR  
bash build.sh -b -p

# Generate examples.zip for students
bash build.sh -g

# Do everything (prompts for each step)
bash build.sh -a

# Do everything without prompts
bash build.sh -a -y

# Increment version and rebuild everything
bash build.sh --bump -a -y

# Rebuild from scratch without cache
bash build.sh --rebuild -b

# Clean build cache
bash build.sh --clean
```

Run `bash build.sh -h` to see all available options.

## Modular Scripts

The build system consists of modular scripts in `scripts/`:

### `scripts/build-container.sh`
Builds multi-architecture Docker images (amd64 + arm64).

```bash
bash scripts/build-container.sh [--no-cache]
```

- Uses Docker Buildx with QEMU for ARM64 emulation
- Tags images as `ghcr.io/bguspl/student-env:VERSION` and `:latest`
- Uses GHCR cache for faster builds (unless `--no-cache` is used)
- Requires GitHub CLI (`gh`) for authentication
- Build time: ~2-3 min (amd64), ARM64 can take up to ~15 min

### `scripts/push-to-ghcr.sh`
Pushes multi-arch images to GitHub Container Registry.

```bash
bash scripts/push-to-ghcr.sh
```

- Pushes both version tag and `:latest`
- Creates multi-arch manifest
- Requires GitHub CLI (`gh`) authentication
- Image must be built first

### `scripts/generate-examples.sh`
Creates `examples.zip` for students with versioned devcontainer.

```bash
bash scripts/generate-examples.sh
```

- Verifies devcontainer.json uses `:latest` in repository
- Automatically replaces `:latest` with current version in zip
- Keeps repository using `:latest` for local development

All scripts support `--help` for detailed usage.

## How It Works

The `build.sh` script coordinates build operations with these options:

### Command Options

- `-b, --build` - Build multi-arch Docker image (amd64 + arm64)
- `-p, --push` - Push image to GitHub Container Registry
- `-g, --generate` - Create examples.zip for students
- `-a, --all` - Perform all steps (prompts for each unless `-y` is used)
- `-y, --yes` - Skip confirmation prompts
- `--bump` - Increment version number before operations
- `--rebuild` - Build without using cache (fresh build)
- `--clean` - Clean Docker buildx cache
- `-h, --help` - Show help message

### Behavior

**Direct flags** (`-b`, `-p`, `-g`): Execute immediately without prompts

**`--all` flag**: Prompts for each step (build, push, generate) unless `-y` is used

**Examples:**
```bash
# Build only (no prompt)
bash build.sh -b

# Build and push (no prompts)
bash build.sh -b -p

# All steps with prompts for each
bash build.sh -a

# All steps without any prompts
bash build.sh -a -y
```

## Version Management

Version is stored in `.env`:

```
VERSION=1.0
```

### Incrementing Version

Use the `--bump` flag to automatically increment the version:

```bash
# Bump version and rebuild everything
bash build.sh --bump -a -y
```

Or manually edit `.env` and then build:

```bash
# After editing .env
bash build.sh -a -y
```

## Prerequisites

1. **Docker Desktop** (with WSL integration if on Windows) or Docker Engine
2. **GitHub CLI** (`gh`): Install from https://cli.github.com/
3. **Authenticated**: Run `gh auth login`

## Making the Package Public

After first push, make the GHCR package public so students can pull without auth:

1. Go to: https://github.com/orgs/bguspl/packages (or your org)
2. Find `student-env`
3. Package settings → Visibility → Public

## Troubleshooting

**"gh CLI not found"**  
Install from https://cli.github.com/

**"Not authenticated with gh"**  
Run `gh auth login` and complete browser authentication

**"Permission denied" or "write:packages scope required"**  
Your GitHub token needs the `write:packages` permission. Run `gh auth refresh -s write:packages` to add the required scope.

**"Docker daemon not reachable"**  
Start Docker Desktop or check your Docker daemon

**"ERROR [internal] booting buildkit"**

Accompanied by something like that:
> WARNING: No output specified with docker-container driver. Build result will only remain in the build cache. To push result image into registry use --push or to load image into docker use --load
ERROR: failed to build: Error response from daemon: invalid mount config for type "bind": bind source path does not exist: /run/desktop/mnt/host/wsl/docker-desktop-bind-mounts/Ubuntu-22.04/f969f076ad437ac0162d56bf356c2a910d8ddd313a6ac1d90246b6b64d06d59a

Run `docker buildx rm multiarch-builder` and run the build again.

**ARM64 build slow**  
Expected — QEMU emulation can take up to ~15 min build time

**"multiarch-builder not found"**  
The script creates it automatically on first run

## Monitoring Builds

Watch terminal output during build:
- AMD64 build completes first (~2-3 min)
- ARM64 build follows (can take up to ~15 min via QEMU)

To verify the published image:

```bash
docker buildx imagetools inspect ghcr.io/bguspl/student-env:latest
```

## Build Options Summary

```bash
bash build.sh -h  # Show all options
```

**Main Commands:**
- `-b, --build` - Build image
- `-p, --push` - Push to GHCR
- `-g, --generate` - Create examples.zip
- `-a, --all` - Do all (with prompts)
- `-y, --yes` - Skip prompts

**Additional Options:**
- `--bump` - Increment version
- `--rebuild` - Build without cache
- `--clean` - Clean build cache
