# How to Inspect Changes and Backups with `mosy diff`

This guide explains how to inspect file differences between local configuration files, Cloud Vault replicas, timestamped safety backups, and alternative synchronization profiles using `mosy diff`.

---

## Overview

During synchronization, configuration changes occur across multiple dimensions:
- Local files modified prior to cloud synchronization.
- Timestamped safety backups (`.bak_YYYYMMDD_HHMMSS`) generated before replacing conflicting local files.
- Profile-specific configurations across isolated environments (e.g. `work` vs `personal`).

`mosy diff` provides unified, colorized difference views without requiring manual file path lookups.

---

## Step 1: Inspect Changes on Managed Files

### Diff a Specific Managed Item

To compare a managed file against its Cloud Vault version or recent safety backup:

```bash
mosy diff ~/.bashrc
```

If the item is a symbolic link pointing directly to the cloud vault, `mosy diff` checks for existing timestamped backup files (`.bak_*`) and displays the difference against the most recent backup snapshot.

### Diff All Managed Dotfiles

Running `mosy diff` without a specific path iterates through all mapped files in `sync-map.conf`:

```bash
mosy diff
```

---

## Step 2: Compare Against Safety Backups (`-b`, `--backup`)

MountSync automatically generates timestamped backups before overwriting conflicting local files. You can compare your current active file against these backups.

### Auto-Detect Most Recent Backup

When you specify `-b` without an argument, MountSync automatically locates the most recent `.bak_*` backup:

```bash
mosy diff ~/.config/nvim/init.lua -b
```

### Target a Specific Backup Snapshot

You can supply an explicit timestamp or full backup file path:

```bash
# Using a specific timestamp identifier
mosy diff ~/.bashrc -b 20260815_120000

# Using a full backup path
mosy diff ~/.bashrc -b ~/.bashrc.bak_20260815_120000
```

---

## Step 3: Compare Across Synchronization Profiles (`-c`, `--compare-profile`)

When maintaining multiple profiles (such as `work` and `personal`), you can inspect configuration divergence between profiles:

```bash
# Compare local work Neovim config against personal profile Neovim config
mosy -p work diff ~/.config/nvim/init.lua -c personal
```

Output example:

```text
=== Diff: Profile 'work' vs Profile 'personal' for .config/nvim/init.lua ===
--- work:.config/nvim/init.lua
+++ personal:.config/nvim/init.lua
@@ -12,4 +12,4 @@
-vim.g.company_email = "employee@corp.example"
+vim.g.personal_email = "dev@example.org"
```

---

## Step 4: Filter Diffs by Tag and Group

You can narrow change inspections across subsets of dotfiles using filtering flags:

```bash
# Inspect diffs only for items in the 'dotfiles' group
mosy diff -g dotfiles

# Inspect diffs only for items tagged with 'editor' in the 'work' profile
mosy -p work diff -t editor
```

---

## Step 5: Detect Unlinked / Divergent Local Files

If a local file was replaced by a regular physical file (for example, by an external installer breaking the symlink), `mosy diff` detects the discrepancy and compares the local physical file directly with the cloud vault copy:

```bash
mosy diff ~/.bashrc
```

Output example:

```text
=== Diff: Local physical file vs Cloud Vault (.bashrc) ===
--- vault:.bashrc
+++ local:.bashrc
@@ -40,3 +40,5 @@
+alias dev="cd ~/projects"
```

---

## Step 6: View Backup History (`mosy history`)

To view all safety backups created for a dotfile in reverse chronological order:

```bash
# View backup history for a specific dotfile
mosy history ~/.bashrc

# View history for all managed dotfiles
mosy history

# Output history as JSON for scripts
mosy history --json
```

Output example:
```text
Backup History for ~/.bashrc:
  [1] 2026-08-25 16:30:15 (1.2 KB)  /home/user/.bashrc.bak_20260825_163015
  [2] 2026-08-20 10:00:00 (1.1 KB)  /home/user/.bashrc.bak_20260820_100000
```

---

## Step 7: Restore Snapshots with `mosy rollback`

To restore a previous backup snapshot to the local file and cloud vault:

```bash
# Interactively select a snapshot to restore
mosy rollback ~/.bashrc

# Restore a specific snapshot by index (1 = latest)
mosy rollback ~/.bashrc 1

# Restore a specific snapshot by timestamp identifier
mosy rollback ~/.bashrc 20260820_100000

---

## Step 8: Create On-Demand Snapshots (`mosy backup` / `mosy snapshot`)

Before making major manual edits to your configuration, you can create timestamped safety snapshots:

```bash
# Create snapshot for a specific dotfile
mosy backup ~/.bashrc

# Using the snapshot alias
mosy snapshot ~/.config/nvim/init.lua

# Create snapshots for all managed dotfiles in the active profile
mosy backup

# Filter batch snapshots by tags or groups
mosy backup -t work -g shell
```

---

## Step 9: Backup Housekeeping (`mosy clean`)

To prevent obsolete snapshots from accumulating and consuming disk space, use `mosy clean`:

```bash
# Preview snapshots that would be removed without deleting anything
mosy clean --older-than 30d --dry-run

# Purge backups older than 30 days for all managed dotfiles
mosy clean --older-than 30d

# Purge backups for a specific dotfile without confirmation prompt
mosy clean ~/.bashrc --older-than 7d --force
```

> [!NOTE]
> `mosy clean` only removes timestamped snapshot copies (`.bak_*`, `.backup_*`). Active symlinks and physical files are never touched.

---

## Related Documentation

- [CLI Reference](../reference/cli.md): Full syntax reference for `mosy diff`, `mosy history`, `mosy rollback`, `mosy backup`, and `mosy clean`.
- [Profiles Guide](profiles.md): Multi-profile configuration workflows.
- [Tags and Groups Guide](tags-and-groups.md): Filtering items by tags and groups.
- [Architecture & Design](../explanation/architecture.md): Timestamped backup strategies.
- [Documentation Portal](../README.md): Return to the main project documentation index.
