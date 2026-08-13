# MountSync

![Tests](https://github.com/GabrielTeixeiral0l/MountSync/actions/workflows/tests.yml/badge.svg)
![License](https://img.shields.io/github/license/GabrielTeixeiral0l/MountSync?color=blue)
![Bash](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnu-bash&logoColor=white)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

MountSync is a minimalist, cloud-agnostic dotfile and directory orchestrator. It leverages `rclone` to synchronize your environment across multiple machines using symbolic links.

> [!NOTE]
> MountSync operates on a simple philosophy: files are moved to a central "Cloud Vault" and replaced locally by symbolic links. A central registry (`sync-map.conf`) tracks these items, allowing instant replication of your environment on any machine.

## Prerequisites

Before installing MountSync, ensure your system meets the following requirements:

- **Operating System:** Linux (with `systemd` for automated mounting).
- **Shell:** `bash` (version 4.0 or higher recommended).
- **Cloud Engine:** `rclone` installed and configured with at least one remote.
- **Dependencies:** `fuse3` (required for rclone mounts).

## Features

- **Cloud Agnostic:** Works seamlessly with any provider supported by `rclone` (Google Drive, Dropbox, S3, WebDAV).
- **Background Persistence:** Includes an automated Systemd service to keep your cloud drive mounted across reboots.
- **Incremental Synchronization:** Safely bring in new configurations from other machines without overwriting existing local files.
- **Tags & Groups:** Categorize managed items to selectively synchronize, initialize, list, or check status across different environments.
- **Minimalist Design:** Written in modular, efficient Bash with zero heavy dependencies.

## Quick Start

Get up and running by executing the interactive installer directly from your terminal:

```bash
curl -sL https://raw.githubusercontent.com/GabrielTeixeiral0l/MountSync/main/install.sh | bash
```

The installer handles the entire setup process:
- Verifies or installs `rclone`.
- Guides you through configuring your cloud remote and mount point.
- Sets up a Systemd user service for background mounting.
- Integrates the `mosy` command into your local environment (`PATH`).

## Usage

Once installed, use the `mosy` CLI to manage your dotfiles.

### 1. Sync a New Item (`add`)

Move a file or directory to the cloud vault and replace the local version with a symbolic link. You can assign optional tags (`--tag` / `-t`) and groups (`--group` / `-g`).

```bash
# Basic usage
mosy add ~/.bashrc

# Sync with tags and groups
mosy add ~/.bashrc --tag shell,main --group dotfiles
mosy add ~/.config/nvim -t dev,editor -g config
```

### 2. Pull Updates (`pull`)

Scan the sync map in your cloud and create symbolic links for any items that exist in the vault but are missing on your current machine.

```bash
# Pull all missing items
mosy pull

# Filter pull by tag or group
mosy pull --tag work
mosy pull -g dev
```

> [!IMPORTANT]
> The `pull` command is non-destructive. It will never overwrite or touch existing local files.

### 3. Initialize a New Machine (`init`)

When setting up a fresh machine, this command recreates all symbolic links defined in the sync map. You can selectively initialize environments using tags or groups.

```bash
# Initialize all items
mosy init

# Initialize only items with specific tags or groups
mosy init --tag work --group dev
```

> [!WARNING]
> Running `init` on an existing machine will back up local files before replacing them with symlinks from the vault to prevent data loss.

### 4. List Managed Items (`list`)

List all files and directories currently managed by MountSync along with their associated tags and groups.

```bash
# List all managed items
mosy list

# Filter listed items by tag or group
mosy list --tag shell
mosy list -g config
```

### 5. Check System & File Integrity (`status`)

Check mount point status, background service health, and verify symlink integrity for managed files.

```bash
# Check status of all items
mosy status

# Check status filtered by tag or group
mosy status --tag work -g dev
```

### Tags and Groups Filtering

MountSync allows you to categorize configurations for flexible environment management:

- **Groups (`--group` / `-g`):** Represent **high-level categories** or functional types (e.g., `dotfiles`, `config`, `scripts`). Use groups to organize items by what they are.
- **Tags (`--tag` / `-t`):** Represent **contextual identifiers** for specific environments or machines (e.g., `work`, `personal`, `shell`, `dev`). Use tags to filter items by where or when they should be synced.

#### Example Scenario

```bash
# Categorize a work Neovim config (Group: config | Tags: work, editor)
mosy add ~/.config/nvim -g config -t work,editor

# Categorize a personal shell config (Group: dotfiles | Tags: personal, shell)
mosy add ~/.bashrc -g dotfiles -t personal,shell

# On a work machine, initialize only work-related items:
mosy init --tag work

# On a server, pull only shell dotfiles:
mosy pull --group dotfiles --tag shell
```

When filtering with `--tag` or `--group` in `init`, `pull`, `list`, or `status`, MountSync matches items that contain at least one of the specified tags or groups.


## Architecture

MountSync is designed with a modular, "core-and-command" architecture:

1. **Unified Entrypoint (`mosy`)**: A thin wrapper that routes subcommands.
2. **Core Logic (`src/core.sh`)**: Handles configuration loading, mount verification, and the `sync-map.conf` iterator.
3. **Modular Commands (`src/commands/*.sh`)**: Each sub-command (add, pull, init, etc.) is an independent script, making it easy to audit and extend.

## Troubleshooting

### Cloud drive is not mounted
If you see an error about the cloud drive not being mounted:
1. Check if the mount service is running: `systemctl --user status mosy-mount.service`
2. Manually verify the mount point: `mountpoint /your/mount/path`
3. Ensure your rclone remote name in `~/.config/mosy/config` matches your `rclone config`.

### Symlink conflicts
MountSync will never overwrite a real file during `pull`. If a conflict occurs, it will skip the item and warn you. You must manually move the local file if you want to replace it with the cloud version.

## Configuration

MountSync resolves its configuration in the following order of precedence:

1. **Environment Variables:** `MOSY_CLOUD_DIR` and `MOSY_MOUNT_POINT`.
2. **Configuration File:** `~/.config/mosy/config`.
3. **Default Fallback:** `~/GoogleDrive/mosy_vault`.

### Example Configuration

`~/.config/mosy/config`

```bash
MOSY_REMOTE_NAME="MyGoogleDrive"
MOSY_MOUNT_POINT="/home/user/Cloud"
MOSY_CLOUD_DIR="/home/user/Cloud/mosy_vault"
```

## Structure

- `mosy`: Unified CLI entrypoint.
- `src/`: Modular source files containing the core logic.
- `install.sh`: Interactive installation and setup wizard.

## Support / Donations

If MountSync helps you stay synced and organized, consider supporting the project:

- **Bitcoin (BTC):** `bc1qcxkrqtqmpal3fdauakk36ykl9ukurd072j4rfj`
