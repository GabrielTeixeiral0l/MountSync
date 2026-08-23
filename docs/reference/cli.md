# CLI Reference (`mosy`)

This reference manual provides exhaustive details on the `mosy` command-line interface, including global flags and all 13 subcommands. `mosy` is the command-line utility for MountSync, enabling user-space cloud vault synchronization using symbolic links and rclone virtual file system mounts.

---

## Global Syntax

```text
mosy [-p|--profile PROFILE] SUBCOMMAND [options] [arguments]
```

---

## Global Flags

Global flags must be specified before the subcommand.

### `-p`, `--profile`

* **Purpose**: Specifies the target synchronization profile for the command execution. If omitted, MountSync uses the `default` profile.
* **Syntax**: `-p PROFILE` or `--profile PROFILE`
* **Arguments**: `PROFILE` - The string name of the profile (e.g., `work`, `personal`, `default`).
* **Environment Variable Equivalent**: `MOSY_PROFILE`
* **Output Example**:
  ```text
  $ mosy -p work list
  Items managed by MountSync:
  - .config/nvim [tags: work] [groups: config]
  ```

---

## Subcommands Reference

| Command | Syntax | Description |
| :--- | :--- | :--- |
| [`add`](#1-add) | `mosy add <path> [options]` | Add a file or directory to cloud vault with granular symlinking and secret scanning |
| [`init`](#2-init) | `mosy init [options]` | Recreate all managed symlinks on local machine from `sync-map.conf` |
| [`pull`](#3-pull) | `mosy pull [options]` | Link missing cloud items without overwriting existing local files |
| [`list`](#4-list) | `mosy list [options]` | List all managed dotfiles with associated tags and groups |
| [`status`](#5-status) | `mosy status [options]` | Show cloud mount health, systemd service state, and symlink integrity |
| [`doctor`](#6-doctor) | `mosy doctor [--fix]` | Run system diagnostics and automatically remediate broken links and services |
| [`info`](#7-info) | `mosy info [--json]` | Display environment overview dashboard and managed dotfile metrics |
| [`diff`](#8-diff) | `mosy diff [path] [options]` | Inspect differences against safety backups, physical vault copies, or profiles |
| [`remove`](#9-remove) | `mosy remove <path>` | Stop syncing an item and revert symlink back to a standalone local file |
| [`config`](#10-config) | `mosy config [set <k> <v>]` | View current settings or update configuration key-value pairs |
| [`version`](#11-version) | `mosy version` | Display installed version and check GitHub for latest updates |
| [`update`](#12-update) | `mosy update` | Update MountSync to the latest version |
| [`uninstall`](#13-uninstall) | `mosy uninstall` | Interactive wizard to revert links and cleanly remove MountSync |

---

### 1. `add`

* **Purpose**: Adds a local file or directory to MountSync management. For directories, it performs granular synchronization by preserving the local physical directory structure, moving only non-ignored files into the cloud vault and symlinking them individually. All ignored files (such as `.git`, `.env`, `node_modules`, or rules in `.mosyignore`) remain safely on the local disk without deletion. The item is appended to `sync-map.conf`.
* **Syntax**:
  ```text
  mosy [-p PROFILE] add FILE_OR_DIRECTORY [-t|--tag TAGS] [-g|--group GROUPS] [--scan-secrets|--scan] [--no-scan] [-f|--force]
  ```
* **Arguments**:
  * `FILE_OR_DIRECTORY`: Path to a file or directory inside the user's home directory (`$HOME`). Relative paths are automatically resolved relative to `$HOME`.
* **Options/Flags**:
  * `-t, --tag TAGS`: Comma-separated list of tags to associate with the item (e.g., `work,dev`).
  * `-g, --group GROUPS`: Comma-separated list of groups to associate with the item (e.g., `dotfiles,configs`).
  * `--scan-secrets`, `--scan`: Enable pre-vaulting regex inspection for unencrypted credentials, tokens, and private keys.
  * `--no-scan`: Bypass secret scanning even if `MOSY_SCAN_SECRETS=true` is enabled in configuration.
  * `-f, --force`: Bypass interactive secret confirmation prompts and force synchronization.
* **Output Example**:
  ```text
  $ mosy add ~/.bashrc --tag shell,main --group dotfiles
  Syncing .bashrc...
  Success! .bashrc is now synced.
  ```
* **Exit Codes**:
  * `0`: Success, or item is already a symbolic link.
  * `1`: Failure (cloud drive not mounted, target missing, target outside `$HOME`, secret detected in non-interactive mode or rejected by user, or backup/move failure).

---

### 2. `init`

* **Purpose**: Configures the local machine by reading `sync-map.conf` from the cloud vault and establishing symbolic links for all managed items.
* **Syntax**:
  ```text
  mosy [-p PROFILE] init [-t|--tag TAGS] [-g|--group GROUPS]
  ```
* **Arguments**: None.
* **Options/Flags**:
  * `-t, --tag TAGS`: Filters processing to only items containing at least one of the specified tags.
  * `-g, --group GROUPS`: Filters processing to only items containing at least one of the specified groups.
* **Output Example**:
  ```text
  $ mosy init --tag dev
  Configuring PC from sync map...
  Creating link for .config/nvim...
  PC configured successfully!
  ```
* **Exit Codes**:
  * `0`: Success (including when `sync-map.conf` is missing or no entries match filters).
  * `1`: Failure (cloud drive not mounted).

---

### 3. `pull`

* **Purpose**: Performs a non-destructive check against `sync-map.conf` and creates symbolic links for managed items present in the cloud vault that are not yet linked or existing on the local machine.
* **Syntax**:
  ```text
  mosy [-p PROFILE] pull [-t|--tag TAGS] [-g|--group GROUPS]
  ```
* **Arguments**: None.
* **Options/Flags**:
  * `-t, --tag TAGS`: Filters processing to only items matching the given tags.
  * `-g, --group GROUPS`: Filters processing to only items matching the given groups.
* **Output Example**:
  ```text
  $ mosy pull -g dotfiles
  Linked .tmux.conf
  ```
* **Exit Codes**:
  * `0`: Success.
  * `1`: Failure (cloud drive not mounted).

---

### 4. `list`

* **Purpose**: Lists all files and directories currently managed under the active profile's `sync-map.conf`, along with their configured tags and groups.
* **Syntax**:
  ```text
  mosy [-p PROFILE] list [-t|--tag TAGS] [-g|--group GROUPS]
  ```
* **Arguments**: None.
* **Options/Flags**:
  * `-t, --tag TAGS`: Shows only items matching the specified tags.
  * `-g, --group GROUPS`: Shows only items matching the specified groups.
* **Output Example**:
  ```text
  $ mosy list
  Items managed by MountSync:
  - .bashrc [tags: shell] [groups: dotfiles]
  - .config/nvim [tags: dev] [groups: config]
  ```
* **Exit Codes**:
  * `0`: Success.

---

### 5. `status`

* **Purpose**: Evaluates and displays the status of the cloud mount point, the systemd user service (`mosy-mount.service`), and file integrity across all managed items.
* **Syntax**:
  ```text
  mosy [-p PROFILE] status [-t|--tag TAGS] [-g|--group GROUPS]
  ```
* **Arguments**: None.
* **Options/Flags**:
  * `-t, --tag TAGS`: Filters integrity checks by tags.
  * `-g, --group GROUPS`: Filters integrity checks by groups.
* **Output Example**:
  ```text
  $ mosy status
  --- System Status ---
  Mount Point (/home/user/GoogleDrive): MOUNTED
  Systemd Service (mosy-mount): ACTIVE

  --- File Integrity ---
  [OK] .bashrc
  [WARN] .config/nvim (Missing link: cloud source exists)

  --- Summary ---
  Total: 2
  OK: 1
  Warnings: 1
  Errors: 0
  ```
* **Exit Codes**:
  * `0`: Success.

---

### 6. `doctor`

* **Purpose**: Performs a deep diagnostic audit of the entire MountSync infrastructure, dependencies, mount points, background services, cloud connectivity, token authentication, vault storage permissions, and symlink integrity. When invoked with `--fix`, automatically remediates resolvable issues safely and non-destructively.
* **Syntax**:
  ```text
  mosy [-p PROFILE] doctor [--fix]
  ```
* **Arguments**: None.
* **Options/Flags**:
  * `--fix, -f`: Attempts automatic safe remediation of detected issues (e.g. creating missing mount directories, starting inactive systemd services, recreating valid missing symlinks, and correcting configuration permissions).
* **Output Example**:
  * Diagnostic check:
    ```text
    $ mosy doctor
    --- Dependencies & Environment ---
    [OK] rclone: found (/usr/bin/rclone)
    [OK] mountpoint: found
    [OK] POSIX utilities: all essential tools present
    [OK] Service manager: systemctl (systemd)
    [OK] Configuration directory: ~/.config/mosy

    --- Mount Point & Services ---
    [OK] Systemd service (mosy-mount): ACTIVE
    [OK] Mount Point (/home/user/GoogleDrive): MOUNTED
    [OK] rclone process: RUNNING

    --- Cloud Connectivity & Storage ---
    [OK] Cloud connectivity (gdrive:): REACHABLE & AUTHENTICATED
    [OK] Vault storage (/home/user/GoogleDrive/mosy_vault): READ/WRITE
    [OK] Storage free space: 42G available

    --- Mapping & Symlink Integrity ---
    [OK] .bashrc
    [OK] .config/nvim

    --- Doctor Summary ---
    Total checks: 12
    OK: 12
    Warnings: 0
    Errors: 0
    ```
* **Exit Codes**:
  * `0`: Success (all checks passed or all errors remediated).
  * `1`: One or more diagnostic errors detected (or remediation failed).

---

### 7. `info`

* **Purpose**: Displays a comprehensive environment overview dashboard containing system facts, active MountSync configuration, cloud mount and background service health, and managed item statistics. Supports `--json` for machine-readable output and status bar integrations.
* **Syntax**:
  ```text
  mosy [-p PROFILE] info [--json|-j]
  ```
* **Arguments**: None.
* **Options/Flags**:
  * `--json, -j`: Output full environment overview and metrics formatted as JSON.
* **Output Example**:
  * Default human-readable output:
    ```text
    $ mosy info
    === MountSync Environment Overview ===

    --- System ---
    Hostname:          archlinux
    OS:                Linux 6.6.10-arch1-1 (x86_64)
    Architecture:      x86_64

    --- Configuration ---
    Active Profile:    default
    Cloud Remote:      gdrive:
    Mount Point:       /home/user/GoogleDrive [MOUNTED]
    Service Status:    ACTIVE
    Vault Path:        /home/user/GoogleDrive/mosy_vault
    Sync Map:          /home/user/GoogleDrive/mosy_vault/sync-map.conf
    VFS Cache Mode:    writes

    --- Managed Items ---
    Total Managed:     4
    Valid Links:       3
    Broken Links:      0
    Missing Links:     1
    Unique Tags:       2
    Unique Groups:     1
    ```
  * JSON output:
    ```text
    $ mosy info --json
    {
      "system": {
        "hostname": "archlinux",
        "os": "Linux",
        "os_details": "Linux 6.6.10-arch1-1 (x86_64)",
        "kernel": "6.6.10-arch1-1",
        "architecture": "x86_64"
      },
      "configuration": {
        "profile": "default",
        "remote_name": "gdrive:",
        "mount_point": "/home/user/GoogleDrive",
        "mount_status": "MOUNTED",
        "is_mounted": true,
        "service_status": "active",
        "vault_path": "/home/user/GoogleDrive/mosy_vault",
        "sync_map_file": "/home/user/GoogleDrive/mosy_vault/sync-map.conf",
        "vfs_cache": "writes"
      },
      "metrics": {
        "total_managed": 4,
        "valid_links": 3,
        "broken_links": 0,
        "missing_links": 1,
        "lost_items": 0,
        "unique_tags": 2,
        "unique_groups": 1
      }
    }
    ```
* **Exit Codes**:
  * `0`: Success (including when mount point is unmounted or sync map is empty).

---

### 8. `diff`

* **Purpose**: Inspects differences between managed dotfiles and their safety backups (`.bak_*`), physical unlinked local files and cloud vault counterparts, or cross-profile file versions. Automatically utilizes colored output (`diff --color=always`, `delta`, or ANSI color wrapper).
* **Syntax**:
  ```text
  mosy [-p PROFILE] diff [PATH] [-b|--backup [TIMESTAMP]] [-c|--compare-profile PROFILE] [-t|--tag TAGS] [-g|--group GROUPS]
  ```
* **Arguments**:
  * `PATH`: (Optional) File or directory path to inspect. If omitted, diffs all managed items matching active filters.
* **Options/Flags**:
  * `-b, --backup [TIMESTAMP]`: Compare against a specific timestamped backup snapshot, or latest `.bak_*` if timestamp omitted.
  * `-c, --compare-profile, --profile-target PROFILE`: Compare the active profile's file against another profile.
  * `-t, --tag TAGS`: Filter items by tags when diffing all items.
  * `-g, --group GROUPS`: Filter items by groups when diffing all items.
* **Output Example**:
  * Diff against latest safety backup:
    ```text
    $ mosy diff ~/.bashrc
    === Diff: Backup (.bashrc.bak_20260821_120000) vs Current (.bashrc) ===
    --- .bashrc.bak_20260821_120000
    +++ current:.bashrc
    @@ -10,3 +10,4 @@
     alias ll='ls -la'
    +export EDITOR=nvim
    ```
  * Cross-profile diff:
    ```text
    $ mosy -p work diff ~/.gitconfig --compare-profile default
    === Diff: Profile 'work' vs Profile 'default' for .gitconfig ===
    --- work:.gitconfig
    +++ default:.gitconfig
    @@ -1,4 +1,4 @@
     [user]
    -    email = dev@company.com
    +    email = dev@personal.me
    ```
* **Exit Codes**:
  * `0`: Success (including when differences are found or no backups exist).
  * `1`: Failure (target file or requested backup not found).

---

### 9. `remove`

* **Purpose**: Removes an item from MountSync management by restoring the target as a standalone local file/directory copied back from the cloud vault, removing its entry from `sync-map.conf`. The original cloud vault copy remains preserved.
* **Syntax**:
  ```text
  mosy [-p PROFILE] remove PATH
  ```
* **Arguments**:
  * `PATH`: The file or directory path to unmanage.
* **Options/Flags**: None.
* **Output Example**:
  ```text
  $ mosy remove ~/.bashrc
  Reverting .bashrc to local file...
  Success! .bashrc is now a local file.
  Note: The cloud copy remains in the vault for your other devices.
  ```
* **Exit Codes**:
  * `0`: Success (or cleanup of a broken link).
  * `1`: Failure (missing path argument, target is not a symlink managed by MountSync, or copy failure).

---

### 10. `config`

* **Purpose**: Views all MountSync configuration settings or updates a specific configuration key in `~/.config/mosy/config`.
* **Syntax**:
  * View configuration:
    ```text
    mosy config
    ```
  * Set key-value pair:
    ```text
    mosy config set KEY VALUE
    ```
* **Arguments**:
  * `set`: Subcommand action to modify a setting.
  * `KEY`: Configuration parameter name. Valid keys: `MOSY_REMOTE_NAME`, `MOSY_MOUNT_POINT`, `MOSY_VFS_CACHE`, `MOSY_CLOUD_DIR`, `MOSY_BACKUP_EXT`, `MOSY_LOG_LEVEL`, `MOSY_DRY_RUN`, `MOSY_SCAN_SECRETS`.
  * `VALUE`: New value for the configuration key.
* **Options/Flags**: None.
* **Output Example**:
  * View config:
    ```text
    $ mosy config
    --- Mosy Configuration ---

    [Remote]
    MOSY_REMOTE_NAME     "gdrive:"    # The rclone remote name (e.g., gdrive:).
    MOSY_MOUNT_POINT     "/home/user/GoogleDrive"    # Local mount path. (Default: /home/user/GoogleDrive)
    MOSY_VFS_CACHE       "writes"    # rclone VFS cache mode (e.g., writes, full, off). (Default: writes)
    MOSY_CLOUD_DIR       "/home/user/GoogleDrive/mosy_vault"    # Root folder inside mount. (Default: ${MOSY_MOUNT_POINT}/mosy_vault)

    [Behavior]
    MOSY_BACKUP_EXT      ".bak"    # Extension for conflict backups. (Default: .bak)
    MOSY_LOG_LEVEL       "INFO"    # Verbosity: INFO, DEBUG, SILENT (Default: INFO)
    MOSY_DRY_RUN         "false"    # If true, simulate actions without changes. (Default: false)
    MOSY_SCAN_SECRETS    "false"    # Scan for secrets on add. (Default: false)
    ```
  * Set config:
    ```text
    $ mosy config set MOSY_LOG_LEVEL DEBUG
    Configured MOSY_LOG_LEVEL="DEBUG"
    ```
* **Exit Codes**:
  * `0`: Success.
  * `1`: Failure (invalid syntax, unsupported key, or invalid value).

---

### 11. `version`

* **Purpose**: Displays the installed version of MountSync and queries the GitHub API to check for available updates.
* **Syntax**:
  ```text
  mosy version
  ```
* **Arguments**: None.
* **Options/Flags**: None.
* **Output Example**:
  ```text
  $ mosy version
  MountSync v1.2.0
  You are running the latest version.
  ```
* **Exit Codes**:
  * `0`: Success.

---

### 12. `update`

* **Purpose**: Updates MountSync to the latest version by pulling the main branch from GitHub and executing the update installer with automatic rollback on failure.
* **Syntax**:
  ```text
  mosy update
  ```
* **Arguments**: None.
* **Options/Flags**: None.
* **Output Example**:
  ```text
  $ mosy update
  Updating MountSync...
  Update complete!
  ```
* **Exit Codes**:
  * `0`: Success.
  * `1`: Failure (installation repository directory missing or git pull/install error).

---

### 13. `uninstall`

* **Purpose**: Interactive uninstallation wizard that prompts to revert managed items to local files, unmount the cloud drive, disable and remove the systemd user service, and delete binary and completion files.
* **Syntax**:
  ```text
  mosy uninstall
  ```
* **Arguments**: None.
* **Options/Flags**: None.
* **Output Example**:
  ```text
  $ mosy uninstall
  === MountSync Uninstall ===
  Do you want to revert all synced files to local files? (y/N) n
  The installation folder (/home/user/.mountsync) and binary will be removed. Confirm? (y/N) y
  Cleaning up system integration...
  Do you want to unmount the cloud drive (/home/user/GoogleDrive) now? (y/N) y
  Stopping service and unmounting...
  Disabling service and removing files...
  MountSync uninstalled successfully. Goodbye!
  ```
* **Exit Codes**:
  * `0`: Success or cancellation.

---

## Related Documents

* [Quickstart Tutorial](../tutorials/quickstart.md)
* [Multiple Profiles Guide](../how-to/profiles.md)
* [Tags and Groups Guide](../how-to/tags-and-groups.md)
* [Ignore Patterns Guide](../how-to/mosyignore.md)
* [Diagnostics & Auto-Remediation Guide](../how-to/doctor-and-diagnostics.md)
* [Diff and Backups Inspection Guide](../how-to/diff-and-backups.md)
* [Secret Leak Prevention Guide](../how-to/secrets-prevention.md)
* [Multi-Machine Synchronization Guide](../how-to/multi-machine-sync.md)
* [Configuration Reference](configuration.md)
* [Architecture & Design](../explanation/architecture.md)
* [Documentation Portal](../README.md)
