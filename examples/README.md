# SPL Course Student Env

Welcome! This is your starter workspace for the SPL course. It includes a pre-configured development environment with all the tools you need.

## What's included

- **C/C++**: GCC 13, Clang, CMake
- **Java**: Temurin JDK 21 + Maven
- **Python**: 3.12 with pip and venv
- **SQLite**: client and development libraries
- **VS Code extensions**: C/C++, Java, Python, SQLite tools

## Getting started

### Prerequisites

1. Install [VS Code](https://code.visualstudio.com/)
2. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
3. Install Docker:
   - **Windows**: Follow the course setup guide to install Docker in WSL (or use [Docker Desktop](https://www.docker.com/products/docker-desktop) if you prefer)
   - **Mac**: Install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop)

### Open this workspace

1. Open this folder in VS Code
2. When prompted, click **Reopen in Container** (or press F1 → "Dev Containers: Reopen in Container")
3. VS Code will download the course image and start the container (first time takes a few minutes)

Once the container starts, you'll have a full development environment ready to use!

## Try the examples

Run the smoke test to verify everything works:

```bash
bash run.sh
```

This will compile and run:
- `Hello.java` (Java)
- `hello.cpp` (C++)
- `hello.py` (Python)

## Working on assignments

- Create your project files in this workspace
- The container automatically mounts this folder, so your files persist when you close VS Code
- Use the integrated terminal (Ctrl+`) for commands

## Troubleshooting

- **Container won't start?**
  - Windows: Make sure Docker is running (in WSL: `docker info` should work; with Docker Desktop: check the system tray)
  - Mac: Make sure Docker Desktop is running
- **Permission errors?** You're running as the `spl` user inside the container (non-root)
- **Need to rebuild?** F1 → "Dev Containers: Rebuild Container"

For setup help on Windows, see the course setup guide.
