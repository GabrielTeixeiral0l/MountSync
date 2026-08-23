# How to Diagnose and Repair System Issues with `mosy doctor`

This guide explains how to run system diagnostics, inspect background services, and perform automated self-healing of broken symlinks and mounts using `mosy doctor`.

---

## Overview

MountSync depends on external components to maintain synchronized state:
- Local FUSE mount point (`$MOSY_MOUNT_POINT`)
- Background service manager (`systemd` on Linux or `launchd` on macOS)
- Cloud storage connectivity through `rclone`
- File system permissions and valid symbolic links

When file links break, mounts fail to start, or remote credentials expire, `mosy doctor` identifies root causes and provides automated remediation with `--fix`.

---

## Step 1: Run System Diagnostics

To perform a read-only health audit of your MountSync environment, execute:

```bash
mosy doctor
```

Targeting a custom profile is supported via the `-p` / `--profile` global flag:

```bash
mosy -p work doctor
```

### Diagnostic Categories Evaluated

The diagnostic engine evaluates six core functional categories:

| Category | Checks Performed | Severity if Failed |
| :--- | :--- | :--- |
| **Dependencies & Environment** | Validates presence of `rclone`, `mountpoint`, and POSIX tools (`find`, `ln`, `readlink`, `grep`, `sed`, `awk`). Checks service manager availability (`systemctl` or `launchctl`) and `~/.config/mosy` directory permissions (0700). | Critical / Error |
| **Mount Point & Services** | Checks whether the cloud drive is actively mounted at `MOSY_MOUNT_POINT`. Checks background service status (`mosy-mount.service` on Linux or `com.mountsync.rclone` on macOS). | Error / Warning |
| **Remote Connectivity** | Runs `rclone about <remote>:` to verify remote responsiveness, authentication token validity, and cloud storage reachability. | Warning |
| **Vault Storage** | Inspects read and write permissions on `MOSY_CLOUD_DIR`. Checks for minimum free disk space (at least 50 MB required for staging operations). | Error / Warning |
| **Configuration Files** | Validates existence and readable permissions of `~/.config/mosy/config`, `~/.config/mosy/.mosyignore`, and custom secrets configuration (`~/.config/mosy/secrets.conf`). | Warning |
| **Symlink Integrity** | Scans every mapping in `sync-map.conf`. Checks for valid links, broken/dangling targets, and files that have reverted to unlinked physical copies. | Error / Warning |

---

## Step 2: Understand Diagnostic Output

The output categorizes findings using standard severity indicators:

- `[OK]`: Component is healthy and operating within parameters.
- `[WARN]`: Non-critical condition (e.g. optional service manager missing, optional config file absent).
- `[ERR]`: Critical failure preventing normal synchronization (e.g. mount inactive, missing required binary).
- `[FIXED]`: Issue resolved automatically during `--fix` execution.

### Example Diagnostic Report

```text
=== MountSync System Diagnostics (Profile: default) ===

--- Dependencies & Environment ---
[OK] rclone: found (/usr/bin/rclone)
[OK] mountpoint: found
[OK] POSIX utilities: all essential tools present
[OK] Service manager: systemctl (systemd)
[OK] Configuration directory: ~/.config/mosy

--- Mount Point & Services ---
[OK] Mount point exists: /home/user/GoogleDrive
[OK] Cloud drive: MOUNTED (/home/user/GoogleDrive)
[OK] Service mosy-mount.service: active (running)

--- Remote Storage Connectivity ---
[OK] Remote 'gdrive:': connected and responding

--- Vault Storage ---
[OK] Vault directory exists: /home/user/GoogleDrive/mosy_vault
[OK] Vault write permissions: OK
[OK] Vault free space: 42 GB available

--- Configuration Files ---
[OK] Configuration file: ~/.config/mosy/config (valid)
[OK] Sync map file: /home/user/GoogleDrive/mosy_vault/sync-map.conf (2 items)

--- Managed Symlink Integrity ---
[OK] .bashrc -> /home/user/GoogleDrive/mosy_vault/.bashrc
[OK] .config/nvim -> /home/user/GoogleDrive/mosy_vault/.config/nvim

==================================================
Summary: 14 checks | 14 OK | 0 Warnings | 0 Errors
Status: System is healthy.
```

---

## Step 3: Automatically Remediate Issues with `--fix`

When issues are detected, execute `mosy doctor --fix` (or short flag `-f`):

```bash
mosy doctor --fix
```

### Actions Performed by Auto-Remediation

1. **Configuration Directory**: Creates `~/.config/mosy` with secure `0700` permissions if missing.
2. **Mount Point Directory**: Creates the local mount directory if missing.
3. **Background Mount Service**: Attempts to restart inactive `systemd` or `launchd` mount services.
4. **Vault Directory**: Recreates missing vault root and profile directories.
5. **Dangling Symlinks**: Non-destructively recreates missing or broken symbolic links for files present in the cloud vault.

### Example Remediation Report

```text
=== MountSync System Diagnostics (Profile: default) [REMEDIATION MODE] ===

--- Mount Point & Services ---
[FIXED] Created mount point directory: /home/user/GoogleDrive
[FIXED] Restarted service mosy-mount.service

--- Managed Symlink Integrity ---
[FIXED] Recreated symlink for .bashrc -> /home/user/GoogleDrive/mosy_vault/.bashrc

==================================================
Summary: 14 checks | 14 OK | 0 Warnings | 0 Errors | 3 Fixed
Status: System is healthy.
```

---

## Exit Codes & Automation

`mosy doctor` returns standardized exit codes suitable for CI/CD pipelines, login scripts, or desktop status hooks:

- `0`: System is healthy (0 errors detected, warnings may be present).
- `1`: One or more critical errors were detected.

---

## Related Documentation

- [CLI Reference](../reference/cli.md): Complete parameter reference for `mosy doctor`.
- [Configuration Reference](../reference/configuration.md): Configuration variables and service settings.
- [Architecture & Design](../explanation/architecture.md): Service manager and FUSE integration details.
- [Documentation Portal](../README.md): Return to the main project documentation index.
