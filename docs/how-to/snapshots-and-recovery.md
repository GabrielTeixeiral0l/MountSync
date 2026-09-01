# How to Manage Snapshots, History and Recovery

This guide explains how to create on-demand safety snapshots, inspect historical revisions, edit configurations with automatic pre-edit backups, restore previous file versions, and clean up obsolete backup files using MountSync.

---

## Overview

MountSync enforces a non-destructive lifecycle policy for all dotfiles and configurations. Every modification, initialization conflict, rollback, or editor session automatically generates timestamped backup snapshots in the format:

```text
<original_name>.bak_YYYYMMDD_HHMMSS
```

If a custom extension is configured via `MOSY_BACKUP_EXT`, snapshots use that extension (e.g. `.backup_YYYYMMDD_HHMMSS`).

---

## Step 1: Create On-Demand Snapshots (`mosy backup`)

Before performing manual edits, major system updates, or experimental configuration changes, you can create timestamped snapshots.

### Snapshot a Single Managed Item

```bash
mosy backup ~/.bashrc
```

Output:
```text
Created safety backup: /home/user/.bashrc.bak_20260901_113000
```

### Snapshot All Managed Dotfiles in Batch

Running `mosy backup` without specifying a path creates snapshots across all items registered in `sync-map.conf`:

```bash
mosy backup
```

### Snapshot with Filters

You can limit batch snapshot creation to specific groups or tags:

```bash
mosy backup -g dotfiles -t shell
```

> [!NOTE]
> The `mosy snapshot` command is a built-in alias for `mosy backup`.

---

## Step 2: Edit Dotfiles with Automatic Pre-Edit Backups (`mosy edit`)

`mosy edit` opens managed files directly in your `$EDITOR` or `$VISUAL`, automatically generating a safety backup prior to launching the editor.

### Edit by Exact Path or Partial Query

```bash
# Open by exact file path
mosy edit ~/.bashrc

# Open by fuzzy substring matching
mosy edit nvim
```

If multiple files match a partial query, an interactive menu allows selecting the target file.

### Skip Pre-Edit Backup

If you want to make a quick change without generating an extra snapshot:

```bash
mosy edit ~/.bashrc --no-backup
```

---

## Step 3: Inspect Backup History (`mosy history`)

To view available backup snapshots for a specific file:

```bash
mosy history ~/.bashrc
```

Output:
```text
Backup History for ~/.bashrc:
  [1] 2026-09-01 11:30:00 (1.2 KB)  /home/user/.bashrc.bak_20260901_113000
  [2] 2026-08-25 16:00:00 (1.1 KB)  /home/user/.bashrc.bak_20260825_160000
  [3] 2026-08-20 09:15:00 (950 B)   /home/user/.bashrc.bak_20260820_091500
```

### Global History Across All Files

To list all backup snapshots currently stored in your environment:

```bash
mosy history
```

### Machine-Readable JSON History

```bash
mosy history ~/.bashrc --json
```

---

## Step 4: Restore a Snapshot (`mosy rollback`)

`mosy rollback` safely restores a previous snapshot to both your local file and the cloud vault, automatically creating a safety backup of your current state before applying the change.

### Interactive Rollback

Running `mosy rollback` with only the file path presents an interactive numbered selection:

```bash
mosy rollback ~/.bashrc
```

Prompt:
```text
Available backup snapshots for ~/.bashrc:
  [1] 2026-09-01 11:30:00 (1.2 KB)  /home/user/.bashrc.bak_20260901_113000
  [2] 2026-08-25 16:00:00 (1.1 KB)  /home/user/.bashrc.bak_20260825_160000
Select a snapshot to restore [1-2] (or 'q' to cancel): 1
```

### Direct Rollback by Timestamp or Index

```bash
# Restore by explicit timestamp
mosy rollback ~/.bashrc 20260825_160000

# Restore the most recent snapshot in non-interactive mode
mosy rollback ~/.bashrc 1
```

---

## Step 5: Clean Obsolete Backups (`mosy clean`)

Over time, backup snapshots accumulate on disk. `mosy clean` purges outdated `.bak_*` files while guaranteeing that active dotfiles, cloud vault contents, and symlinks are never touched.

### Simulate Deletion (`--dry-run` / `-n`)

Always test backup purging with dry-run mode before actual removal:

```bash
mosy clean --older-than 30d --dry-run
```

Output:
```text
[DRY RUN] Would remove: /home/user/.bashrc.bak_20260715_100000 (1.1 KB, 47 days old)
Summary: 1 snapshots would be purged (1.1 KB freed).
```

### Purge Backups Older Than a Given Duration

Duration formats supported: `30d` (days), `24h` (hours), `60m` (minutes).

```bash
# Purge backups older than 14 days
mosy clean --older-than 14d

# Purge backups for a specific item without interactive confirmation
mosy clean ~/.bashrc --older-than 7d --force
```

### Batch Clean Across Mapped Items

```bash
mosy clean -g dotfiles --older-than 30d
```

---

## Summary of Commands

| Task | Command Syntax |
| :--- | :--- |
| Create manual snapshot | `mosy backup <path>` or `mosy snapshot [path]` |
| Edit with pre-edit snapshot | `mosy edit <query>` |
| View snapshot history | `mosy history <path>` |
| Restore snapshot | `mosy rollback <path> [timestamp]` |
| Clean obsolete backups | `mosy clean --older-than <duration>` |
| Inspect link management | `mosy which <path>` |
| View hierarchy tree | `mosy tree` |
