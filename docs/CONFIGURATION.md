# Configuration Reference

This document details the configuration system of **MountSync**, setting precedence order, environment variable usage, and CLI options.

---

## Configuration File

MountSync settings are saved in:
```bash
~/.config/mosy/config
```

This file is a simple Bash script containing environment variable declarations.

---

## Precedence Order

MountSync resolves its configuration using the following priority order (highest to lowest):

1. **Global CLI Flags & Temporary Environment Variables** (e.g., `mosy -p work` or `MOSY_DRY_RUN=true mosy pull`).
2. **Local Configuration File** (`~/.config/mosy/config`).
3. **Default Values (Internal Fallbacks)**.

---

## Configuration Variables Table

| Key / Environment Variable | Description | Default Value | Valid Values |
| :--- | :--- | :--- | :--- |
| `MOSY_REMOTE_NAME` | Name of the configured `rclone` remote | *(No default, required)* | Remote name (e.g., `gdrive:`, `dropbox:`) |
| `MOSY_MOUNT_POINT` | Local mount point of the cloud drive | `${HOME}/GoogleDrive` | Any valid absolute path |
| `MOSY_CLOUD_DIR` | Root vault directory inside the cloud drive | `${MOSY_MOUNT_POINT}/mosy_vault` | Any valid absolute path |
| `MOSY_VFS_CACHE` | `rclone` VFS Cache mode | `writes` | `off`, `minimal`, `writes`, `full` |
| `MOSY_BACKUP_EXT` | Extension for conflict backup files | `.bak` | Any extension (e.g., `.bak`, `.old`) |
| `MOSY_LOG_LEVEL` | Verbosity level for CLI messages | `INFO` | `INFO`, `DEBUG`, `SILENT` |
| `MOSY_DRY_RUN` | Simulates actions without modifying files | `false` | `true`, `false` |
| `MOSY_PROFILE` | Active synchronization profile | `default` | Any valid profile name |

---

## Configuration Management via CLI (`mosy config`)

The `mosy config` subcommand allows viewing and changing configuration directly from the terminal.

### 1. View Current Configuration (`mosy config`)

```bash
mosy config
```

Example output:
```text
--- Mosy Configuration ---

[Remote]
MOSY_REMOTE_NAME     "gdrive:"    # The rclone remote name (e.g., gdrive:).
MOSY_MOUNT_POINT     "/home/user/GoogleDrive"    # Local mount path. (Default: /home/user/GoogleDrive)
MOSY_VFS_CACHE       "writes"    # rclone VFS cache mode (e.g., writes, full, off). (Default: writes)
MOSY_CLOUD_DIR       "/home/user/GoogleDrive/mosy_vault"    # Root folder inside mount. (Default: ${MOSY_MOUNT_POINT}/mosy_vault)

[Behavior]
MOSY_BACKUP_EXT      ".bak"    # Extension for conflict backups. (Default: .bak)
MOSY_LOG_LEVEL       "INFO"    # Verbosity: INFO, DEBUG, SILENT (Default: INFO)
MOSY_DRY_RUN        "false"    # If true, simulate actions without changes. (Default: false)
```

### 2. Set an Option (`mosy config set`)

```bash
mosy config set MOSY_REMOTE_NAME "mygdrive:"
mosy config set MOSY_LOG_LEVEL "DEBUG"
mosy config set MOSY_DRY_RUN "true"
```

> [!NOTE]
> The `config set` subcommand automatically validates allowed keys and their expected values.

---

## Example `~/.config/mosy/config` File

```bash
MOSY_REMOTE_NAME="gdrive:"
MOSY_MOUNT_POINT="/home/gabriel/GoogleDrive"
MOSY_CLOUD_DIR="/home/gabriel/GoogleDrive/mosy_vault"
MOSY_VFS_CACHE="writes"
MOSY_BACKUP_EXT=".bak"
MOSY_LOG_LEVEL="INFO"
MOSY_DRY_RUN="false"
```

---

## Related Guides

* [Multiple Profiles Guide](PROFILES.md): Learn about the `MOSY_PROFILE` variable and profiles.
* [Tags and Groups](TAGS_AND_GROUPS.md): Categorize managed items.
* [Ignore Patterns Guide](MOSYIGNORE.md): Configure global and local ignore patterns.
* [CLI Reference](CLI_REFERENCE.md): Detailed guide covering all subcommands.
* [Main README](../README.md): Return to the main page.
