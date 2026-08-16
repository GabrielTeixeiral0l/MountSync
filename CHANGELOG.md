# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Refactored
- Centralized `--tag` and `--group` CLI argument parsing across commands into a reusable `parse_filter_flags` helper in `src/core.sh`.
- Streamlined configuration loading and environment precedence in `load_settings` without reflection arrays.
- Simplified `mosy remove` file and directory copy handling into an unconditional recursive copy (`cp -r`).
- Replaced subshell map manipulation in `mosy remove` with standard in-place `sed -i` deletion.
- Simplified `.mosyignore` line whitespace trimming in `src/ignore.sh`.

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
