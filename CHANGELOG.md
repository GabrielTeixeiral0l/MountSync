# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub Actions CI for automated BATS testing.
- Professional Issue Forms and Pull Request templates.
- Comprehensive contributing guidelines and code of conduct.
- Professional Shields.io badges to README.
- Architecture and Troubleshooting sections to documentation.

### Fixed
- TTY redirection issues in `install.sh` for non-interactive environments.
- Permission issues in BATS tests when running in Docker volumes.
- Missing BATS helper libraries in the repository.

## [1.0.0] - 2026-04-25

### Added
- Core synchronization logic using `rclone` and symbolic links.
- CLI commands: `add`, `init`, `pull`, `list`, `status`, `remove`, `uninstall`.
- Interactive installer with `systemd` mount service support.
- BATS testing suite with Docker integration.
