# How to Manage Profiles in MountSync

This guide explains how to isolate configurations into different profiles (such as work, personal, or server) using MountSync.

## Overview

MountSync allows you to maintain independent configuration profiles. Each profile owns its own sync configuration map and state within your storage vault, preventing configuration overlap between different contexts.

## Profile Storage and Directory Structure

Profiles are stored inside your cloud vault directory (`$MOSY_CLOUD_DIR`):

* **Default profile**: Uses `$MOSY_CLOUD_DIR/sync-map.conf`
* **Custom profiles**: Stored in `$MOSY_CLOUD_DIR/profiles/PROFILE_NAME/sync-map.conf`

```text
$MOSY_CLOUD_DIR/
├── sync-map.conf                # Default profile configuration
└── profiles/
    ├── work/
    │   └── sync-map.conf        # Work profile configuration
    ├── personal/
    │   └── sync-map.conf        # Personal profile configuration
    └── server/
        └── sync-map.conf        # Server profile configuration
```

## Profile Selection Methods

MountSync determines which profile to use based on the following precedence hierarchy:

1. **Global Flag (`-p` / `--profile`)**: Overrides all other settings.
2. **Environment Variable (`MOSY_PROFILE`)**: Used when no command-line flag is passed.
3. **Default**: Fallback profile when neither the flag nor the environment variable is set.

---

## Step-by-Step Instructions

### 1. Creating and Using a New Profile

To set up a profile named `work`, pass `-p work` or `--profile work` to MountSync commands:

```bash
mountsync -p work add /home/user/work-docs docs
```

This creates the configuration file at `$MOSY_CLOUD_DIR/profiles/work/sync-map.conf` and maps `/home/user/work-docs` under the target remote location `docs`.

### 2. Running Commands with a Profile Flag

You can target any profile explicitly for any MountSync command:

```bash
# List mapped folders in the 'work' profile
mountsync -p work list

# Synchronize files using the 'personal' profile
mountsync --profile personal sync

# Check status of the 'server' profile
mountsync -p server status
```

### 3. Setting a Profile via Environment Variable

If you work continuously within a specific environment (e.g., in a terminal session dedicated to work), set `MOSY_PROFILE`:

```bash
export MOSY_PROFILE=work
```

While `MOSY_PROFILE` is set, all MountSync commands automatically target the `work` profile without requiring the `-p` flag:

```bash
mountsync status
mountsync sync
```

### 4. Overriding Environment Variables with CLI Flags

Command-line flags take priority over environment variables. If `MOSY_PROFILE=work` is set in your shell, you can still execute a single command for another profile:

```bash
# Executed against 'personal' profile despite MOSY_PROFILE=work
mountsync -p personal status
```

### 5. Managing Profile Configurations

To inspect or edit a custom profile's configuration directly, open its corresponding file:

```bash
# Edit default profile
nano $MOSY_CLOUD_DIR/sync-map.conf

# Edit work profile
nano $MOSY_CLOUD_DIR/profiles/work/sync-map.conf
```
