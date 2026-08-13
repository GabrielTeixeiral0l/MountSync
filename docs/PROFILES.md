# Multiple Profiles Guide

MountSync supports **Multiple Profiles**, allowing you to separate and manage different sets of dotfiles and configurations within the same cloud Vault.

---

## Overview

By default, MountSync operates on the `default` profile. However, as your computer ecosystem grows (work laptop, personal PC, VPS servers, etc.), you may need to isolate certain files without mixing synchronization maps.

With the **Profiles** feature, you can maintain isolated vaults for each context while sharing the same `rclone` mount point.

---

## How It Works

### Setting the Active Profile

The active profile can be selected via:
1. **Global flag `-p` or `--profile <name>`** in the CLI command:
   ```bash
   mosy -p work add ~/.config/nvim
   ```
2. **Environment Variable `MOSY_PROFILE`**:
   ```bash
   export MOSY_PROFILE=work
   mosy status
   ```

---

## Cloud Vault Directory Structure

The sync map (`sync-map.conf`) and stored files depend on the selected profile:

* **Default Profile (`default`)**:
  * Directories/Files: `$MOSY_CLOUD_DIR/`
  * Map File: `$MOSY_CLOUD_DIR/sync-map.conf`
* **Named Profile (e.g., `work`, `personal`, `server`)**:
  * Directories/Files: `$MOSY_CLOUD_DIR/profiles/<name>/`
  * Map File: `$MOSY_CLOUD_DIR/profiles/<name>/sync-map.conf`

### Visual Directory Layout of the Vault

```text
$MOSY_CLOUD_DIR/                           # Example: ~/GoogleDrive/mosy_vault
├── sync-map.conf                          # Map for 'default' profile
├── .bashrc                                # Synchronized file (default)
├── .gitconfig                             # Synchronized file (default)
└── profiles/                              # Directory containing additional profiles
    ├── work/
    │   ├── sync-map.conf                  # Map for 'work' profile
    │   ├── .config/
    │   │   └── nvim/                      # Neovim for work profile
    │   └── .ssh/
    │       └── config_work                # Corporate SSH config
    ├── personal/
    │   ├── sync-map.conf                  # Map for 'personal' profile
    │   └── .config/
    │       └── mpv/                       # Personal MPV settings
    └── server/
        ├── sync-map.conf                  # Map for 'server' profile
        └── .tmux.conf                     # Lightweight config for servers
```

---

## Usage Examples

### 1. Adding items to a specific profile
```bash
# Add Neovim configuration to the 'work' profile
mosy -p work add ~/.config/nvim

# Add .tmux.conf to the 'server' profile
mosy --profile server add ~/.tmux.conf
```

### 2. Initializing a machine with a profile
```bash
# On a company computer, apply only the work profile:
mosy -p work init

# On a remote VPS, apply the server profile:
mosy -p server init
```

### 3. Listing and checking profile status
```bash
# List managed items in the 'work' profile
mosy -p work list

# Check symlink integrity for the 'personal' profile
mosy -p personal status
```

---

## Common Use Cases

1. **Work vs. Personal**: Keep configuration keys, corporate credentials, or company dotfiles in the `work` profile without cluttering your `personal` environment.
2. **Headless Servers / VPS**: Create a minimal `server` profile containing only `.bashrc`, `.tmux.conf`, and diagnostic scripts, avoiding synchronization of heavy GUI configurations.
3. **Testing / Sandbox Environment**: Test new editor or shell configurations in a `testing` profile without affecting your main setup.

---

## Related Guides

* [Tags and Groups](TAGS_AND_GROUPS.md): Combine profiles with Tags and Groups for advanced filtering.
* [Ignore Patterns Guide](MOSYIGNORE.md): Filter build artifacts and unneeded files across profiles.
* [Configuration Reference](CONFIGURATION.md): Learn how to configure environment variables and preferences.
* [CLI Reference](CLI_REFERENCE.md): View the complete list of subcommands and flags.
* [Main README](../README.md): Return to the main page.
