# Student Development Environment Setup

This guide will help you set up the development environment for SPL course assignments on **Windows 11** and **macOS**. We do not provide instructions for native Linux installations, but you may build the dev container yourself (request the latest Dockerfile from your instructor).

## How to Run Commands

Throughout this guide, you'll see code blocks like this:

```bash
example-command --option value
```

To run these commands, open a terminal on your system:

- **Windows:** Open Windows Terminal (uses PowerShell by default)
- **macOS:** Open Terminal (Applications → Utilities → Terminal)

Then type or paste the command and press Enter.

## Windows Installation

### Step 1: Install WSL 2 and Ubuntu

1. Ensure WSL 2 is enabled and up-to-date:
   ```PowerShell
   wsl --set-default-version 2
   wsl --update
   ```

2. **Restart your computer**

3. Install Ubuntu 22.04:
   ```PowerShell
   wsl --install -d Ubuntu-22.04
   ```
   
   Create a username (lowercase only) and password when prompted.

> **Note:** Your password won't appear on screen as you type (not even as `***`). This is normal security behavior in Linux.

   **If you see error `0x80370102`:** Virtualization is not enabled in BIOS. See [Troubleshooting](#troubleshooting).

### Step 2: Install Visual Studio Code

```PowerShell
winget install -e --id Microsoft.VisualStudioCode --source winget
```

**If `winget` fails**, repair it first (open Windows Terminal as Administrator and run):

```PowerShell
Install-Module -Name Microsoft.WinGet.Client -Force
Repair-WinGetPackageManager -AllUsers
```

Close and reopen your terminal after installation.

**Or** download and install from [https://code.visualstudio.com/](https://code.visualstudio.com/)

### Step 3: Install Dev Containers Extension

```bash
code --install-extension ms-vscode-remote.remote-containers
```

**Or** install from VS Code: `F1` → search "Dev Containers" → Install

### Step 4: Set Up Git (Run in WSL)

```bash
sudo apt install -y git
```

Configure Git:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

> **Note:** Use your GitHub user account email if you have one

### Step 5: Install Docker (choose one)

#### Option 1: Let VS Code Install Docker on WSL (Recommended)

You can skip this step and let VS Code install Docker on WSL for you in the next step.

#### Option 2: Install Docker Desktop

```bash
winget install -e --id=Docker.DockerDesktop --source winget
```

**Or** download and install Docker Desktop from [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)

After installation of Docker Desktop, run it, and enable WSL 2 integration in the settings.

### Step 6: Download the Examples

Download `examples.zip` from Moodle to your `Downloads` folder.

### Step 7: Move the Examples to WSL

Open Ubuntu from Start menu and run:

```bash
mv /mnt/c/Users/"$(powershell.exe '$env:USERNAME' | tr -d '\r')"/Downloads/examples.zip ~
```

> **Note:** This command reads your Windows username to locate the Downloads folder.

### Step 8: Install Unzip

In Ubuntu, run:

```bash
sudo apt update && sudo apt install unzip
```

### Step 9: Unzip and Open the Examples in VS Code

In Ubuntu, run:

```bash
cd ~
unzip examples.zip
code examples/
```

### Step 10: Reopen in Container

`F1` → "Reopen in Container" 

>  **Note:** If you did not install Docker in a previous step, let VS Code install it at this stage (VS Code will suggest it)

**Once the container starts, see `README.md` for next steps.**

---

## Mac Installation (arm64 arch.)

### Step 1: Install Visual Studio Code

```bash
brew install --cask visual-studio-code
```

**Or** download and install from [https://code.visualstudio.com/](https://code.visualstudio.com/)

### Step 2: Install Dev Containers Extension

In VS Code: `F1` → search "Dev Containers" → Install

### Step 3: Set Up Git

```bash
git --version
```

If not installed, macOS will prompt for Xcode Command Line Tools.

Configure Git:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

> **Note:** Use your GitHub user account email if you have one.

### Step 4: Install Docker

Download and install Docker Desktop from [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)

Open the `.dmg` file, drag Docker to Applications, launch it, and grant permissions.

Wait for Docker to start (whale icon in menu bar should be steady).

### Step 5: Download the Examples

Download `examples.zip` from Moodle to your `Downloads` folder.

### Step 6: Move and Unzip the Examples and Open in VS Code

```bash
cd ~
mv Downloads/examples.zip .
unzip examples.zip
code examples/
```

### Step 7: Reopen in Container

`F1` → "Reopen in Container"

**Once the container starts, see `README.md` for next steps.**

---

## Troubleshooting

### Virtualization Not Enabled (Windows)

**Error:** `WslRegisterDistribution failed with error: 0x80370102`

1. Restart and enter BIOS (press F2, F10, Del, or Esc during boot)
2. Find virtualization setting ("Intel VT-x", "AMD-V", "SVM Mode")
3. Enable it, save, and exit
4. Try WSL installation again

> Note: More info at https://aka.ms/enablevirtualization

### WSL 2 Not Working (Windows)

```PowerShell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

Restart and try again.

### Docker Permission Denied (Windows)

1. Ensure you ran `sudo usermod -aG docker $USER`
2. **Completely close** Ubuntu terminal
3. Reopen and test: `docker run hello-world`

### Docker Desktop Not Starting (macOS)

1. Check System Preferences → Security & Privacy for blocked items
2. Grant Full Disk Access: System Preferences → Security & Privacy → Privacy → Full Disk Access → Add Docker
3. Restart Docker Desktop

### Container Won't Start (Windows / macOS)

1. Verify Docker is running: `docker info`
2. Rebuild container: `Ctrl/Cmd+Shift+P` → "Dev Containers: Rebuild Container"

### Performance Issues (Windows)

Keep code in WSL filesystem (`~/examples`), not Windows (`/mnt/c/...`) for better performance.

### Performance Issues (macOS)

Increase Docker resources in Docker Desktop → Preferences → Resources → Advanced

---

## Getting Help

If issues persist:
1. Check course forum/Moodle
2. Ask your TA or instructor
3. Include: OS version, exact error message, what you tried

