# ConfigSync

ConfigSync is a minimalist, cloud-agnostic dotfile and directory orchestrator that uses `rclone` to synchronize your environment across multiple machines using symbolic links.

## 🧠 How it Works

ConfigSync follows a simple and robust philosophy:
1. **Cloud Vault**: Your files and directories are moved to a central "Cloud Vault" (e.g., inside your Google Drive, Dropbox, or S3 bucket).
2. **Symbolic Links**: The original location of each item is replaced by a symbolic link pointing to the version in the vault.
3. **Sync Map**: A central registry file (`sync-map.conf`) is stored in your cloud, tracking every synced item. This allows other machines to recreate your entire environment instantly.

## 🚀 Quick Start

Get up and running by executing the interactive installer:
```bash
bash install.sh
```

The installer will:
- Verify or install `rclone`.
- Guide you through configuring your cloud remote and mount point.
- Set up a **Systemd user service** for background mounting and persistence.
- Integrate the `csync` command into your local environment.

## 🛠 Features

- **Cloud Agnostic**: Works with any provider supported by `rclone` (Google Drive, Dropbox, S3, WebDAV, etc.).
- **Background Persistence**: Includes an automated Systemd service to keep your cloud drive mounted across reboots.
- **Incremental Synchronization**: The `pull` command allows you to bring in new configurations from other machines without overwriting existing local files.
- **Minimalist Design**: Written in modular, efficient Bash with zero heavy dependencies.

## 💻 Usage

### 1. Sync a new item: `csync add <path>`
Moves a file or directory to the cloud vault and replaces the local version with a symbolic link.
```bash
csync add ~/.bashrc
```

### 2. Pull updates: `csync pull`
Scans the sync map in your cloud and creates symbolic links for any items that exist in the cloud but are missing on the current machine.
```bash
csync pull
```
*Note: This command is non-destructive and will never touch existing local files.*

### 3. Initialize a new machine: `csync init`
Used when setting up a fresh machine. It recreates all symbolic links defined in the sync map and sets up a bridge to your cloud shell configurations.
```bash
csync init
```

## ⚙️ Configuration

ConfigSync looks for configuration in the following order:
1. **Environment Variables**: `CSYNC_CLOUD_DIR` and `CSYNC_MOUNT_POINT`.
2. **Configuration File**: `~/.config/csync/config`.
3. **Default Fallback**: `~/GoogleDrive/config_sync`.

### Configuration File Example (`~/.config/csync/config`)
```bash
CSYNC_REMOTE_NAME="MyGoogleDrive"
CSYNC_MOUNT_POINT="/home/user/Cloud"
CSYNC_CLOUD_DIR="/home/user/Cloud/config_sync"
```

## 📁 Structure
- `csync`: Unified CLI entrypoint.
- `src/`: Modular source files containing the core logic.
- `install.sh`: Interactive installation and setup wizard.
