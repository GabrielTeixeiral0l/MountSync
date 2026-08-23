# How to Manage Profiles in MountSync

This guide explains how to isolate configurations into different profiles (such as `work`, `personal`, or `server`) using MountSync.

---

## Overview

MountSync allows you to maintain independent configuration profiles. Each profile owns its own synchronization manifest (`sync-map.conf`) and vault storage subfolder, preventing configuration overlap between different operating environments.

---

## Profile Directory Structure

Profiles are stored inside your cloud vault directory (`$MOSY_CLOUD_DIR`):

* **Default profile**: Uses `$MOSY_CLOUD_DIR/sync-map.conf`
* **Custom profiles**: Stored in `$MOSY_CLOUD_DIR/profiles/<profile_name>/sync-map.conf`

```text
$MOSY_CLOUD_DIR/
├── sync-map.conf                # Default profile configuration map
├── .bashrc                      # Default profile files
└── profiles/
    ├── work/
    │   ├── sync-map.conf        # Work profile configuration map
    │   └── .gitconfig           # Work profile files
    ├── personal/
    │   └── sync-map.conf        # Personal profile configuration map
    └── server/
        └── sync-map.conf        # Server profile configuration map
```

---

## Profile Selection Hierarchy

MountSync determines which profile to target using a strict precedence order:

1. **Global CLI Flag (`-p` / `--profile`)**: Overrides all environment variables and configuration defaults.
2. **Environment Variable (`MOSY_PROFILE`)**: Used when no CLI flag is supplied.
3. **Configuration File (`MOSY_PROFILE` in `~/.config/mosy/config`)**: Profile identifier specified in settings.
4. **Default (`default`)**: Fallback profile when no flag, environment variable, or configuration value is set.

---

## Step-by-Step Instructions

### 1. Creating and Using a New Profile

To register files under a profile named `work`, pass `-p work` or `--profile work` to `mosy add`:

```bash
mosy -p work add ~/.gitconfig -t work -g configs
```

This creates the profile directory at `$MOSY_CLOUD_DIR/profiles/work/`, registers `~/.gitconfig` in `$MOSY_CLOUD_DIR/profiles/work/sync-map.conf`, and creates the symlink.

---

### 2. Running Commands with a Profile Flag

You can target any profile explicitly for any MountSync subcommand:

```bash
# List items in the 'work' profile
mosy -p work list

# Initialize local machine from 'personal' profile
mosy --profile personal init

# Check status of 'server' profile
mosy -p server status

# Run system diagnostics for 'work' profile
mosy -p work doctor
```

---

### 3. Setting a Profile via Environment Variable

If you work continuously within a specific environment (for example, in a work-dedicated shell session), set `MOSY_PROFILE`:

```bash
export MOSY_PROFILE=work
```

While `MOSY_PROFILE` is set, all MountSync commands automatically target the `work` profile without requiring the `-p` flag:

```bash
mosy status
mosy list
mosy pull
```

---

### 4. Overriding Environment Variables with CLI Flags

Command-line flags take priority over environment variables. If `MOSY_PROFILE=work` is exported in your shell, you can still execute commands against other profiles:

```bash
# Executed against 'personal' profile despite MOSY_PROFILE=work
mosy -p personal status
```

---

### 5. Inspecting Profile Divergence (`mosy diff -c`)

To compare differences between an active profile and another profile:

```bash
mosy -p work diff ~/.config/nvim/init.lua -c personal
```

---

### 6. Managing Profile Configuration Maps

To inspect or edit a custom profile's configuration map directly, open its corresponding file:

```bash
# Default profile map
cat $MOSY_CLOUD_DIR/sync-map.conf

# Work profile map
cat $MOSY_CLOUD_DIR/profiles/work/sync-map.conf
```

---

## Related Guides

* [Tags and Groups Guide](tags-and-groups.md): Filter items within profiles.
* [Multi-Machine Sync Guide](multi-machine-sync.md): Synchronize profiles across devices.
* [CLI Reference](../reference/cli.md): Complete command-line manual.
* [Configuration Reference](../reference/configuration.md): Environment variables and settings.
* [Documentation Portal](../README.md): Return to documentation index.
