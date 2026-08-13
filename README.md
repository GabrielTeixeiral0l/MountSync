# MountSync

![Tests](https://github.com/GabrielTeixeiral0l/MountSync/actions/workflows/tests.yml/badge.svg)
![License](https://img.shields.io/github/license/GabrielTeixeiral0l/MountSync?color=blue)
![Bash](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnu-bash&logoColor=white)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

MountSync (`mosy`) is a minimalist, cloud-agnostic orchestrator for dotfiles and directory synchronization. It leverages [`rclone`](https://rclone.org/) to keep your development environment and system configurations synchronized across multiple machines using symbolic links (`symlinks`).

Original files are moved to a centralized Cloud Vault and replaced locally with symbolic links. A central registry (`sync-map.conf`) maps these items, enabling instant and safe replication on any machine.

---

## Quick Start

### Installation

Run the interactive installation script directly in your terminal:

```bash
curl -sL https://raw.githubusercontent.com/GabrielTeixeiral0l/MountSync/main/install.sh | bash
```

### 30-Second Example

Add your local `.bashrc` file to MountSync with a group and tag, then check the system status:

```bash
# Add ~/.bashrc to MountSync vault under the 'dotfiles' group and 'shell' tag
mosy add ~/.bashrc -g dotfiles -t shell

# Verify the status of managed items and background mount service
mosy status
```

---

## Documentation (Diátaxis Framework)

MountSync documentation is structured according to the Diátaxis framework, dividing learning and reference materials into four distinct quadrants:

| Quadrant | Purpose | Document Links |
| :--- | :--- | :--- |
| **Tutorial** | Learning-oriented step-by-step introduction for beginners | [Quickstart Tutorial](docs/TUTORIAL_QUICKSTART.md) |
| **How-to Guides** | Task-oriented recipes solving practical real-world problems | [Multiple Profiles Guide](docs/PROFILES.md)<br>[Tags & Groups Guide](docs/TAGS_AND_GROUPS.md)<br>[Ignore Patterns Guide](docs/MOSYIGNORE.md) |
| **Reference** | Information-oriented technical descriptions of CLI and configuration | [CLI Reference](docs/CLI_REFERENCE.md)<br>[Configuration Reference](docs/CONFIGURATION.md) |
| **Explanation** | Understanding-oriented background context and architecture design | [Architecture Explanation](docs/EXPLANATION_ARCHITECTURE.md) |

---

## Command Summary Table

| Command | Example Syntax | Description | Reference Link |
| :--- | :--- | :--- | :--- |
| **`add`** | `mosy add ~/.bashrc -g dotfiles -t main` | Adds an item to the vault and replaces the local file with a symlink. | [Details](docs/CLI_REFERENCE.md#add) |
| **`init`** | `mosy init --tag work` | Rebuilds local symlinks based on the synchronization map. | [Details](docs/CLI_REFERENCE.md#init) |
| **`pull`** | `mosy pull -g config` | Non-destructively pulls missing items from the cloud vault. | [Details](docs/CLI_REFERENCE.md#pull) |
| **`list`** | `mosy list --tag dev` | Lists all managed files along with their tags and groups. | [Details](docs/CLI_REFERENCE.md#list) |
| **`status`** | `mosy status` | Inspects cloud mount state, Systemd service status, and link validity. | [Details](docs/CLI_REFERENCE.md#status) |
| **`remove`** | `mosy remove ~/.bashrc` | Reverts symlink to a regular file and removes it from the sync map. | [Details](docs/CLI_REFERENCE.md#remove) |
| **`config`** | `mosy config set MOSY_LOG_LEVEL DEBUG` | Views or updates MountSync configuration settings. | [Details](docs/CONFIGURATION.md) |
| **`version`** | `mosy version` | Displays the installed version and checks for updates. | [Details](docs/CLI_REFERENCE.md#version) |
| **`update`** | `mosy update` | Updates MountSync to the latest released version. | [Details](docs/CLI_REFERENCE.md#update) |
| **`uninstall`** | `mosy uninstall` | Removes MountSync and optionally restores original files. | [Details](docs/CLI_REFERENCE.md#uninstall) |

---

## Architecture Overview

MountSync follows a clean core-and-command architecture designed for simplicity and reliability:

1. **Single Entry Point (`mosy`)**: A lightweight script that parses global flags (such as profile selection) and dispatches commands.
2. **Core Engine (`src/core.sh`)**: Manages configuration parsing, logging, mount status verification, and `sync-map.conf` processing.
3. **Modular Subcommands (`src/commands/*.sh`)**: Independent subcommands containing isolated execution logic for maintainability.

---

## Troubleshooting

### Cloud Drive Not Mounted
If MountSync reports that the cloud drive is not mounted:
1. Verify systemd service status: `systemctl --user status mosy-mount.service`
2. Check mount point directly: `mountpoint /path/to/mount`
3. Verify that your remote configuration in `~/.config/mosy/config` matches `rclone config`.

### Symlink Conflicts
MountSync does not overwrite existing local files during `pull` operations. If a conflict occurs, the file is skipped with a warning. Use `mosy init` (which generates timestamped backups) or resolve the local file manually.

---

## Support and Donations

* **Bitcoin (BTC):** `bc1qcxkrqtqmpal3fdauakk36ykl9ukurd072j4rfj`

---

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more details.
