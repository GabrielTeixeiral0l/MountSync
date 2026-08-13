# Ignore Patterns Guide (`.mosyignore`)

MountSync provides a flexible file filtering mechanism using `.mosyignore` files. This feature prevents unwanted files, temporary build artifacts, dependency directories, and sensitive logs from being synced to your Cloud Vault or linked during setup.

---

## Overview

When managing complex configuration directories (such as `~/.config/nvim`, project folders, or system setups), certain files and subdirectories should not be stored in the cloud. Examples include:

* Dependencies and packages (e.g., `node_modules`).
* Version control metadata (e.g., `.git`).
* System-generated metadata (e.g., `.DS_Store`).
* Log files and temporary caches (e.g., `*.log`, `*.tmp`).

MountSync automatically filters these files during `add`, `init`, and `pull` operations based on global or local ignore rules.

---

## Supported Locations

MountSync checks for ignore rules in two locations:

| Location | Path | Scope | Description |
| :--- | :--- | :--- | :--- |
| **Global** | `~/.config/mosy/.mosyignore` | System-wide | Applies to all `mosy` commands and managed directories. If this file does not exist, MountSync falls back to built-in default patterns. |
| **Local** | `<directory>/.mosyignore` | Directory-specific | Placed directly inside a target directory (e.g., `~/.config/nvim/.mosyignore`). Customizes ignore rules for that specific folder when using `mosy add`. |

---

## Default Ignore Patterns

If no global `~/.config/mosy/.mosyignore` file exists, MountSync uses the following built-in default patterns:

```text
.git
.git/*
node_modules
node_modules/*
.DS_Store
*.tmp
*.log
```

If a global `~/.config/mosy/.mosyignore` file is present, its patterns take precedence over the default list. When adding a directory containing a local `.mosyignore` file, the local rules are appended to the active patterns.

---

## Syntax and Formatting Rules

The `.mosyignore` file follows simple pattern-matching syntax:

* **Comments:** Lines starting with `#` are ignored.
* **Blank lines:** Empty lines or lines containing only whitespace are skipped.
* **Wildcards:** Standard shell pattern wildcards (such as `*`) are supported.
* **Directories:** Trailing slashes in patterns (e.g., `cache/`) are trimmed and matched against directory names.

### Example `.mosyignore` File

```text
# Global or local MountSync ignore file
.git
.git/*
node_modules
node_modules/*
.DS_Store
*.tmp
*.log
*.swp
*.bak
dist/
build/
.cache
```

---

## How Ignore Rules Work Across Subcommands

### 1. Automatic Expunging during `mosy add`

When you execute `mosy add <directory>` on a folder:

1. MountSync checks if the directory contains a local `.mosyignore` file and loads global/local rules.
2. Before moving the directory into the Cloud Vault, MountSync scans the directory recursively (`clean_ignored_files`).
3. Any file or directory matching an active ignore pattern is automatically **expunged (deleted)** from the local directory.
4. The cleaned directory is then moved to the Cloud Vault and symlinked back to your home directory.

> [!WARNING]
> **Expunging Action:** Automatic deletion during `mosy add` permanently removes ignored files (e.g., `node_modules` or `.git`) from the local directory before vault migration. Ensure you do not list essential files in `.mosyignore`.

### 2. Skipping Ignored Items during `mosy init`

When running `mosy init` on a new or existing machine:

1. MountSync iterates through the entries in `sync-map.conf`.
2. For each cloud item, `mosy init` checks whether the item path matches any active ignore rule using `is_ignored`.
3. If an item matches an ignore rule, MountSync displays `Skipping ignored item: <path>` and skips creating a symbolic link for that item.

### 3. Non-Destructive Skipping during `mosy pull`

When executing `mosy pull` to pull missing items:

1. MountSync evaluates unlinked items listed in `sync-map.conf`.
2. If an unlinked cloud item matches an active ignore pattern, MountSync skips creating the symlink and logs `Skipping ignored item: <path>`.

---

## Related Guides

* [CLI Reference](CLI_REFERENCE.md): View detailed subcommand descriptions and options.
* [Configuration Reference](CONFIGURATION.md): Learn about environment configuration.
* [Multiple Profiles Guide](PROFILES.md): Manage isolated configuration sets.
* [Tags and Groups](TAGS_AND_GROUPS.md): Categorize and filter items.
* [Main README](../README.md): Return to the main page.
