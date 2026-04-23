# ConfigSync

ConfigSync is a minimalist, cloud-agnostic dotfile and directory orchestrator. It leverages `rclone` to synchronize your environment across multiple machines using symbolic links.

> [!NOTE]
> ConfigSync operates on a simple philosophy: files are moved to a central "Cloud Vault" and replaced locally by symbolic links. A central registry (`sync-map.conf`) tracks these items, allowing instant replication of your environment on any machine.

## Features

- **Cloud Agnostic:** Works seamlessly with any provider supported by `rclone` (Google Drive, Dropbox, S3, WebDAV).
- **Background Persistence:** Includes an automated Systemd service to keep your cloud drive mounted across reboots.
- **Incremental Synchronization:** Safely bring in new configurations from other machines without overwriting existing local files.
- **Minimalist Design:** Written in modular, efficient Bash with zero heavy dependencies.

## Quick Start

Get up and running by executing the interactive installer:

```bash
bash install.sh
```

The installer handles the entire setup process:
- Verifies or installs `rclone`.
- Guides you through configuring your cloud remote and mount point.
- Sets up a Systemd user service for background mounting.
- Integrates the `csync` command into your local environment (`PATH`).

## Usage

Once installed, use the `csync` CLI to manage your dotfiles.

### 1. Sync a New Item

Move a file or directory to the cloud vault and replace the local version with a symbolic link.

```bash
csync add ~/.bashrc
```

### 2. Pull Updates

Scan the sync map in your cloud and create symbolic links for any items that exist in the vault but are missing on your current machine.

```bash
csync pull
```

> [!IMPORTANT]
> The `pull` command is non-destructive. It will never overwrite or touch existing local files.

### 3. Initialize a New Machine

When setting up a fresh machine, this command recreates all symbolic links defined in the sync map and sets up a bridge to your cloud shell configurations.

```bash
csync init
```

> [!WARNING]
> Running `init` on an existing machine will back up local files before replacing them with symlinks from the vault to prevent data loss.

## Configuration

ConfigSync resolves its configuration in the following order of precedence:

1. **Environment Variables:** `CSYNC_CLOUD_DIR` and `CSYNC_MOUNT_POINT`.
2. **Configuration File:** `~/.config/csync/config`.
3. **Default Fallback:** `~/GoogleDrive/csync_vault`.

### Example Configuration

`~/.config/csync/config`

```bash
CSYNC_REMOTE_NAME="MyGoogleDrive"
CSYNC_MOUNT_POINT="/home/user/Cloud"
CSYNC_CLOUD_DIR="/home/user/Cloud/csync_vault"
```

## Structure

- `csync`: Unified CLI entrypoint.
- `src/`: Modular source files containing the core logic.
- `install.sh`: Interactive installation and setup wizard.
