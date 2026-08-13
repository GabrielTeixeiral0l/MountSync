# How to Exclude Files with `.mosyignore`

This guide explains how to prevent build artifacts, dependency folders, log files, and temporary cache directories from syncing to your Cloud Vault or creating unwanted symlinks using ignore patterns in MountSync.

---

## Overview

When syncing tool configurations or project folders (such as `~/.config/nvim`, dev projects, or custom scripts), directories often accumulate files that should remain local-only. Common examples include:

* Dependency caches (for example, `node_modules`).
* Version control metadata (for example, `.git`).
* Build outputs and artifacts (for example, `dist/`, `build/`, `*.o`).
* Temporary files and log output (for example, `*.log`, `*.tmp`, `*.swp`).

MountSync uses `.mosyignore` files to filter out unwanted items automatically when executing `mosy add`, `mosy init`, and `mosy pull`.

---

## Step 1: Understand Ignore Scope and Locations

MountSync supports two levels of ignore files:

| Scope | Location | Description |
| :--- | :--- | :--- |
| **Global** | `~/.config/mosy/.mosyignore` | System-wide rules applied to all `mosy` operations. If this file does not exist, MountSync uses built-in default rules. |
| **Local** | `DIRECTORY/.mosyignore` | Directory-specific rules placed inside the targeted folder (for example, `~/.config/nvim/.mosyignore`). Customizes behavior for that specific directory during `mosy add`. |

### Default Fallback Patterns

When no global `~/.config/mosy/.mosyignore` file is present, MountSync defaults to the following patterns:

```text
.git
.git/*
node_modules
node_modules/*
.DS_Store
*.tmp
*.log
```

If a global ignore file exists, its rules override the built-in defaults. When adding a directory that contains a local `.mosyignore` file, the local rules are appended to the active pattern set.

---

## Step 2: Create a `.mosyignore` File

Create a global file at `~/.config/mosy/.mosyignore` for system-wide exclusions or a local `.mosyignore` file inside your project directory.

### Ignore Syntax Rules

* **Comments:** Lines starting with `#` are ignored as comments.
* **Empty Lines:** Blank lines or lines containing whitespace are skipped.
* **Wildcards:** Standard shell wildcards such as `*` are supported.
* **Directory Slashes:** Trailing slashes (for example, `cache/`) are stripped and matched against directory names.

### Comprehensive Example `.mosyignore`

```text
# General version control and system files
.git
.git/*
.DS_Store
Thumbs.db

# Dependencies and packages
node_modules
node_modules/*
vendor/
.venv/

# Build artifacts and compiled outputs
dist/
build/
*.o
*.so
*.pyc

# Logs and temporary files
*.log
*.tmp
*.swp
*.bak
.cache/
```

---

## Step 3: Understand Subcommand Ignore Behavior

The ignore rules interact differently with MountSync subcommands.

### Automatic Expunging during `mosy add`

When you add a directory using `mosy add DIRECTORY`:

1. MountSync checks for local `.mosyignore` files and loads both global and local ignore patterns.
2. MountSync scans the directory recursively (`clean_ignored_files`) before moving it to the Cloud Vault.
3. Every file or subdirectory matching an active ignore pattern is **expunged (deleted)** from the local filesystem prior to vault migration.
4. The cleaned directory is moved to the vault and linked back to your home directory.
> [!WARNING]
> **Permanent Deletion:** `mosy add` permanently expunges matching files (such as `node_modules` or `.git`) from local disk before transferring the directory to the Cloud Vault. Verify your ignore patterns to avoid losing critical files.

### Symlink Skipping during `mosy init`

When you add a directory using `mosy add DIRECTORY`:

1. MountSync checks for `DIRECTORY/.mosyignore` (local rules) and `~/.config/mosy/.mosyignore` (global rules).
2. All files matching active patterns are permanently expunged from the local directory before it is moved to the cloud vault.
3. This guarantees that build artifacts (`node_modules`, `.cache`) are never uploaded or synced to cloud storage.

---

### Behavior During `mosy init` and `mosy pull`

When executing `mosy init` or `mosy pull` on another machine:

1. MountSync reads `sync-map.conf` to discover cloud vault items.
2. Unlinked cloud items matching an active ignore pattern are skipped without altering local files, logging: `Skipping ignored item: PATH`.

---

## Related Guides

* [CLI Reference](CLI_REFERENCE.md): Detailed information on `mosy add`, `mosy init`, and `mosy pull` command flags.
* [Configuration Guide](CONFIGURATION.md): Learn how global configuration paths are structured.
* [Profiles Guide](PROFILES.md): Manage isolated configuration profiles with MountSync.
* [Tags and Groups Guide](TAGS_AND_GROUPS.md): Filter items when executing MountSync commands.
* [Main Documentation](../README.md): Return to the main project page.
