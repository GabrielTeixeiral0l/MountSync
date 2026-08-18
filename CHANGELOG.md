# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-08-18

### Added
- Granular directory synchronization: `mosy add <directory>` now synchronizes individual valid files while preserving the root folder as a real local directory.
- End-to-End Multi-Machine testing suite (`tests/e2e_multi_machine.bats`) covering multi-environment workflows, bidirectional live sync, conflict backups, and independent removals.
- Real application integration test suite (`tests/real_app_system.bats`) verifying CLI tool execution, installation order precedence, and config discovery.
- Nested secrets test suite (`tests/nested_secrets_e2e.bats`) verifying deeply nested ignored secrets and caches.
- Dedicated unit and regression test coverage across settings precedence, edge cases, logging, and map iteration (`tests/`).

### Fixed
- **Zero Data Loss**: Removed destructive `clean_ignored_files` routine (`rm -rf`) to prevent accidental deletion of local ignored files (`.git`, `node_modules`, `.env`).
- **Ancestor Ignore Discovery**: Updated `is_ignored` to traverse up directory trees to `$HOME`, properly detecting `.mosyignore` files located in parent or root project directories.
- **FUSE / rclone Compatibility**: Replaced in-place `sed -i` on `sync-map.conf` with `update_map_remove_entry` (stream truncation), preventing `Input/output error` caused by atomic rename syscalls on FUSE mounts.

### Refactored
- Streamlined `mosy remove` symlink reversion by replacing intermediate `.new` file swap dances with direct replacement (`rm "$link" && cp -r "$source" "$link"`).
- Removed unused `CLOUD_PATH` variable in `src/commands/remove.sh`.
- Cleaned up internal comments to focus strictly on architectural decisions.
- Centralized `--tag` and `--group` CLI argument parsing across commands into a reusable `parse_filter_flags` helper in `src/core.sh`.
- Streamlined configuration loading and environment precedence in `load_settings` without reflection arrays.
- Simplified `.mosyignore` line whitespace trimming in `src/ignore.sh` using native Bash parameter expansion.

## [1.1.0] - 2026-08-15

### Added
- Multiple profiles support via `-p` / `--profile` flag and `MOSY_PROFILE` environment variable.
- Categorization and conditional filtering using Tags and Groups across `add`, `init`, `pull`, `list`, and `status` commands.
- File and directory ignore support via global (`~/.config/mosy/.mosyignore`) and local `.mosyignore` files, with automatic expunging during `add`.
- Global `--dry-run` flag support to simulate execution without modifying the filesystem.
- Comprehensive documentation suite covering Tutorials, How-To Guides, Reference, and Architecture.

### Changed
- Restructured `docs/` directory into dedicated modular documentation files.

### Refactored
- Simplified tag and group filtering logic in `foreach_mapping`.
- Optimized mount point checking in `is_mounted`.
- Streamlined environment variable preservation in `load_settings`.

## [1.0.1] - 2026-07-30

### Refactored
- Consolidated subcommand routing mechanism in `mosy` CLI using dynamic function dispatch (`cmd_${1}`).
- Standardized command entry point naming conventions across `src/commands/`.
- Reduced main executable codebase footprint by removing redundant `case` routing boilerplate.

## [1.0.0] - 2026-04-25

### Added
- Core synchronization logic using `rclone` and symbolic links.
- CLI subcommands: `add`, `init`, `pull`, `list`, `status`, `remove`, `config`, `version`, `update`, `uninstall`.
- Interactive installer script (`install.sh`) with `systemd` user service setup.
- BATS testing suite integration with Docker setup.
