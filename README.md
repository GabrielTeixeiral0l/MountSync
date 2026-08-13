# MountSync

![Tests](https://github.com/GabrielTeixeiral0l/MountSync/actions/workflows/tests.yml/badge.svg)
![License](https://img.shields.io/github/license/GabrielTeixeiral0l/MountSync?color=blue)
![Bash](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnu-bash&logoColor=white)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

MountSync (`mosy`) is a minimalist, cloud-agnostic orchestrator for dotfiles and directory synchronization. It leverages [`rclone`](https://rclone.org/) to keep your development environment and system synchronized across multiple machines using symbolic links (`symlinks`).

> [!NOTE]
> **Operating Philosophy:** Original files are moved to a centralized *Cloud Vault* and replaced locally with symbolic links. A central registry (`sync-map.conf`) maps these items, enabling instant and safe replication on any machine.

---

## Prerequisites

Before installing MountSync, ensure your system meets the following requirements:

* **Operating System:** Linux (with `systemd` for automatic background mounting).
* **Shell:** `bash` (version 4.0 or higher).
* **Cloud Engine:** `rclone` installed and configured with at least one remote (Google Drive, Dropbox, S3, WebDAV, etc.).
* **Dependencies:** `fuse3` (required for rclone mounts).

---

## Quick Start

Run the interactive installation script directly in your terminal:

```bash
curl -sL https://raw.githubusercontent.com/GabrielTeixeiral0l/MountSync/main/install.sh | bash
```

The installer handles the entire setup process:
1. Verifies and installs required dependencies.
2. Guides you through configuring the `rclone` remote and local mount point.
3. Sets up the Systemd service (`mosy-mount.service`) to keep the drive mounted on boot.
4. Integrates the `mosy` command into your `PATH` and configures shell auto-completion.

---

## Key Features

* **Cloud Agnostic:** Works with any provider supported by `rclone` (Google Drive, Dropbox, S3, WebDAV, Nextcloud, etc.).
* **Multiple Profiles:** Support for isolated profiles (e.g., `work`, `personal`, `server`), allowing separate maps and vaults for each context.
* **Tags & Groups:** Categorize your configurations to selectively synchronize, initialize, list, or check status.
* **Non-Destructive Incremental Sync:** The `pull` command fetches missing files from the cloud without overwriting or altering existing local files.
* **Dry-Run Mode:** Test commands without modifying the filesystem.
* **Security & Backups:** Automatic timestamped backups created upon file conflicts.
* **Background Persistence:** Integrated Systemd service to manage automatic drive mounting.

---

## Detailed Documentation

For in-depth guides on each feature of MountSync, consult the articles in the [`docs/`](docs/) directory:

| Guide | Description |
| :--- | :--- |
| **[Multiple Profiles Guide](docs/PROFILES.md)** | How to use `-p / --profile`, vault directory structure (`profiles/<name>`), and use cases (`work`, `personal`, `server`). |
| **[Tags and Groups](docs/TAGS_AND_GROUPS.md)** | Conceptual difference between Tags and Groups, `sync-map.conf` format, and filtering with `add`, `init`, `pull`, `list`, and `status`. |
| **[Configuration Reference](docs/CONFIGURATION.md)** | Details on `~/.config/mosy/config`, `mosy config` subcommand, environment variables, and precedence order. |
| **[Full CLI Reference](docs/CLI_REFERENCE.md)** | Detailed manual covering all subcommands, arguments, options, and global flags of `mosy`. |

---

## Command Summary Table

| Command | Example Syntax | Description | Guide |
| :--- | :--- | :--- | :--- |
| **`add`** | `mosy add ~/.bashrc -g dotfiles -t main` | Adds an item to the vault and creates a local symlink. | [Details](docs/CLI_REFERENCE.md#add) |
| **`init`** | `mosy init --tag work` | Rebuilds symlinks on the machine based on the sync map. | [Details](docs/CLI_REFERENCE.md#init) |
| **`pull`** | `mosy pull -g config` | Non-destructively pulls missing items from the cloud. | [Details](docs/CLI_REFERENCE.md#pull) |
| **`list`** | `mosy list --tag dev` | Lists managed files with tags and groups. | [Details](docs/CLI_REFERENCE.md#list) |
| **`status`** | `mosy status` | Checks mount status, systemd service, and symlinks. | [Details](docs/CLI_REFERENCE.md#status) |
| **`remove`** | `mosy remove ~/.bashrc` | Reverts symlink to local file and removes from map. | [Details](docs/CLI_REFERENCE.md#remove) |
| **`config`** | `mosy config set MOSY_LOG_LEVEL DEBUG` | Views or modifies MountSync settings. | [Details](docs/CONFIGURATION.md) |
| **`version`** | `mosy version` | Displays installed version and checks for updates. | [Details](docs/CLI_REFERENCE.md#version) |
| **`update`** | `mosy update` | Updates MountSync to the latest version. | [Details](docs/CLI_REFERENCE.md#update) |
| **`uninstall`** | `mosy uninstall` | Uninstalls MountSync and optionally restores files. | [Details](docs/CLI_REFERENCE.md#uninstall) |

---

## Architecture

MountSync is built with a modular "core-and-command" architecture:

1. **Single Entry Point (`mosy`)**: Lightweight wrapper that validates global flags (e.g., `-p / --profile`) and routes requests to subcommands.
2. **Core Logic (`src/core.sh`)**: Handles configuration loading, mount checking, logging, and the `sync-map.conf` iterator.
3. **Modular Commands (`src/commands/*.sh`)**: Each subcommand is an independent script, simplifying maintenance and code audits.

---

## Troubleshooting

### Cloud Drive is Not Mounted
If you encounter an error stating that the cloud drive is not mounted:
1. Check if the Systemd service is active: `systemctl --user status mosy-mount.service`
2. Test the mount point manually: `mountpoint /your/mount/path`
3. Confirm that the remote name in `~/.config/mosy/config` matches the remote name in `rclone config`.

### Symlink Conflicts
MountSync **never** overwrites actual local files during a `pull` execution. If a conflict occurs, the item is skipped and a warning is displayed. If you wish to replace the local copy with the cloud version, use `mosy init` (which creates an automatic backup) or move the local file manually.

---

## Support and Donations

If MountSync helps keep your environments synchronized and organized, consider supporting the project:

* **Bitcoin (BTC):** `bc1qcxkrqtqmpal3fdauakk36ykl9ukurd072j4rfj`

---

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
