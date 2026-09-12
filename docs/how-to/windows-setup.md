# Windows Setup and Configuration Guide

This guide covers installing, configuring, and operating MountSync (`mosy`) natively on Windows 10 and 11.

---

## Prerequisites

Before installing MountSync on Windows, ensure the following components are available:

1. **Git for Windows (Git Bash)**:
   Required for shell execution and POSIX utilities. Download and install from [git-scm.com](https://git-scm.com) or install via winget:
   ```powershell
   winget install --id Git.Git -e --source winget
   ```

2. **WinFsp (Windows File System Proxy)**:
   Required by Rclone to mount cloud storage as a virtual filesystem on Windows. If WinFsp is not installed, the MountSync PowerShell installer will offer to install it automatically via winget. You can also install it manually:
   ```powershell
   winget install --id WinFsp.WinFsp -e --source winget
   ```

3. **Windows Developer Mode (Recommended)**:
   In Windows, creating symbolic links normally requires elevated Administrator privileges unless Developer Mode is enabled. Enabling Developer Mode allows standard user accounts to create symlinks seamlessly.
   - Open **Windows Settings** (`Win + I`).
   - Navigate to **System > For developers** (or **Update & Security > For developers** on Windows 10).
   - Toggle **Developer Mode** to **On**.

---

## Installation

MountSync provides a native PowerShell installer designed for Windows environments.

### One-Line Installation (PowerShell)

Open PowerShell and execute:

```powershell
irm https://raw.githubusercontent.com/GabrielTeixeiral0l/MountSync/main/install.ps1 | iex
```

### Git Bash Alternative

If you prefer installing directly from within Git Bash:

```bash
curl -sL https://raw.githubusercontent.com/GabrielTeixeiral0l/MountSync/main/install.sh | bash
```

### What the Installer Configures

The installer performs the following steps automatically:
- Checks for and offers to install `rclone` and `WinFsp` via winget if missing.
- Installs MountSync scripts to `%USERPROFILE%\.local\bin`.
- Adds `%USERPROFILE%\.local\bin` to your Windows User `PATH` environment variable.
- Creates the local configuration directory at `%USERPROFILE%\.config\mosy`.
- Generates a background mount runner (`mount-runner.cmd` and `mount-runner.vbs`) to start the Rclone mount without showing a console window.
- Registers tab autocompletions for **PowerShell** (`$PROFILE`) and **Git Bash** (`~/.bashrc`).

---

## Cloud Storage Setup

1. If you haven't configured an Rclone remote yet, open Command Prompt or PowerShell and run:
   ```cmd
   rclone config
   ```
   Follow the interactive prompts to create a new remote (e.g., `gdrive` for Google Drive).

2. MountSync reads its remote configuration from `%USERPROFILE%\.config\mosy\config`. Verify that `MOSY_REMOTE_NAME` matches your Rclone remote:
   ```cmd
   mosy config set MOSY_REMOTE_NAME gdrive
   ```

3. Verify system health and connectivity:
   ```cmd
   mosy doctor
   ```

---

## Cross-Platform Application Presets

Windows applications often use different configuration directory paths than Linux and macOS. MountSync provides application presets to map these paths effortlessly.

### Using `mosy link --app <preset>`

| Preset | Windows Local Path | Canonical Cloud Target |
| :--- | :--- | :--- |
| `vscode` | `AppData/Roaming/Code/User/settings.json` | `.config/Code/User/settings.json` |
| `nvim` | `AppData/Local/nvim` | `.config/nvim` |
| `starship` | `.config/starship.toml` | `.config/starship.toml` |
| `git` | `.gitconfig` | `.gitconfig` |
| `windows-terminal` | `AppData/Local/Packages/.../settings.json` | `.config/windows-terminal/settings.json` |

### Examples

Link VS Code settings to match your Linux/macOS configuration:
```powershell
mosy link --app vscode
```

Link Neovim configuration:
```powershell
mosy link --app nvim
```

Link with custom tags or groups:
```powershell
mosy link --app vscode -t windows -g editors
```

---

## Background Mount Management

MountSync on Windows runs `rclone mount` as a silent background process using VBScript and Windows native process tracking (`tasklist.exe` / `taskkill.exe`).

### Checking Service Status

```powershell
mosy status
```

Output confirms whether the background mount service is `ACTIVE` and files are properly synchronized.

### Stopping and Restarting the Mount

To stop the mount service:
```powershell
mosy doctor --fix
```
Or kill any stale rclone mount processes directly:
```cmd
taskkill /F /IM rclone.exe
```

---

## Troubleshooting

### 1. "failed to mount FUSE fs: mountpoint path already exists"
WinFsp requires the mount point directory not to exist as a normal directory prior to mounting. MountSync automatically detects and clears empty collision directories. If you encounter this issue manually, delete the empty directory:
```powershell
Remove-Item -Path "$HOME\GoogleDrive" -Force
```
Then rerun `mosy doctor --fix`.

### 2. "Windows symlink privilege: restricted"
This warning occurs when Developer Mode is disabled and the terminal is not running as Administrator.
- Open **Settings > System > For developers**.
- Turn on **Developer Mode**.
- Restart your terminal.

### 3. Command "mosy" Not Found
If PowerShell or CMD does not recognize `mosy` immediately after installation:
- Close and reopen your terminal to reload the updated `PATH` environment variable.
- Alternatively, check that `%USERPROFILE%\.local\bin` exists in your User PATH settings.

### 4. Git Bash Completions Not Working
The installer adds a completion hook into `~/.bashrc`. If completions do not trigger:
- Ensure your `~/.bashrc` contains the MountSync completion block:
  ```bash
  # MountSync Bash Completion
  if [ -f "$HOME/.config/mosy/completions/mosy.bash" ]; then
      . "$HOME/.config/mosy/completions/mosy.bash"
  fi
  ```
- Reload your shell: `source ~/.bashrc`.
