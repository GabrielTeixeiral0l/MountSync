# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-09-01

### Added
- System diagnostics and health inspection command (`mosy doctor`) covering dependencies, mount status, systemd/launchd services, remote connectivity, vault permissions, and symlink integrity.
- Automated self-healing and remediation mode (`mosy doctor --fix` / `-f`) for non-destructive link recreation, mount directory creation, and service restarts.
- Proactive Secret Leak Prevention on `mosy add` (`src/secrets.sh`) inspecting files for unencrypted private keys (RSA, OpenSSH, EC, DSA, PGP), cloud API tokens (AWS, GitHub, Slack, Stripe), and sensitive filename patterns (`.env*`, `id_rsa`, `*.pem`, `credentials.json`).
- Interactive safety prompts for single files (`[y/N]`) and directory additions (`[y]es / [s]kip (keep local) / [n]o`).
- Configurable via `MOSY_SCAN_SECRETS` (defaults to `false`), on-demand scanning with `mosy add --scan-secrets` / `--scan`, `--no-scan` bypass, and `--force` / `-f` override.
- User-extensible secret patterns file support (`~/.config/mosy/secrets.conf`).
- Environment overview dashboard command (`mosy info`) reporting system facts (OS, kernel, arch, hostname), configuration details, cloud mount health, and managed dotfile metrics.
- Machine-readable JSON output format support via `mosy info --json` / `-j`.
- Change inspection command (`mosy diff`) supporting colored visual diffs against local `.bak_*` safety backups, physical unlinked local files vs cloud vault copies, and cross-profile comparisons (`-c` / `--compare-profile`).
- High-Churn, Database & Lockfile Safety Guard (`src/safety.sh`) protecting against FUSE lock contention and database corruption by detecting embedded databases (`*.sqlite`, `*.db`, `*.duckdb`, `*.kdbx`, `*.ldb`, `*.rdb`), runtime locks/sockets (`*.lock`, `*.sock`, `*.pid`, `*.ipc`), and volatile caches/logs.
- Smart auto-ignore presets for SQLite WAL/journal files (`*.sqlite-wal`, `*.sqlite-shm`, `*.db-wal`, `*.db-shm`, `*.db-journal`) and lock/socket files in default ignore list.
- Safety audit check and interactive remediation in `mosy doctor` and `mosy doctor --fix` detecting and safely unmanaging volatile databases mounted over FUSE.
- Configurable via `MOSY_SAFETY_GUARD` (defaults to `true`), with `--guard`, `--no-guard`, and `--force` / `-f` CLI overrides.
- Backup history inspection command (`mosy history`) listing timestamped snapshots (`.bak_YYYYMMDD_HHMMSS`) in reverse chronological order with formatted dates, file sizes, and machine-readable `--json` format.
- Snapshot rollback command (`mosy rollback`) safely restoring previous snapshots to local files and cloud vault with automatic pre-rollback safety backup generation.
- On-demand backup command (`mosy backup`) and alias (`mosy snapshot`) to manually create timestamped snapshots for single files, directories, or batch managed items before editing.
- Instant config editor command (`mosy edit`) locating managed dotfiles via exact path or fuzzy substring search, automatically generating pre-edit safety snapshots before launching `$EDITOR`.
- Dotfile inspector command (`mosy which`) checking whether local paths are managed, resolving active profile, vault target, symlink health status, tags, groups, snapshot count, and machine-readable `--json` format.
- Backup housekeeping command (`mosy clean`) purging obsolete backup snapshots with duration filters (`--older-than`), simulation mode (`--dry-run`), and tag/group filtering.
- Visual hierarchy tree command (`mosy tree`) rendering ASCII/Unicode directory tree with real-time symlink health badges, alternate grouping (`--by-group`), multi-profile support (`--all-profiles`), and JSON output (`--json`).
- Machine-readable status and bar integration (`mosy status --json` / `-j`) and quiet health check (`mosy status --quiet` / `-q`) returning semantic exit codes for Waybar, Polybar, tmux, and automation scripts.
- Shell completions for `doctor`, `info`, `diff`, `history`, `rollback`, `backup`, `snapshot`, `edit`, `which`, `clean`, `tree`, and `status` in Bash and Zsh.
- Comprehensive BATS test suites across all commands with local and Docker verification.
- Restructured documentation portal into full Diataxis framework (`docs/README.md`, tutorials, how-to guides, reference manuals, and architecture explanations).

### Fixed
- Improved text file detection portability in `mosy edit` using POSIX null-byte count fallback and symlink traversal.

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
