# Tags and Groups Guide

MountSync provides a flexible **Tags** and **Groups** system to categorize and filter managed items. This allows you to selectively synchronize dotfiles and directories depending on the machine, working environment, or file role.

---

## Conceptual Difference

To maintain a clear organization, MountSync distinguishes between **Groups** and **Tags**:

| Concept | CLI Flag | What it represents | Question it answers | Example Values |
| :--- | :--- | :--- | :--- | :--- |
| **Groups** | `-g`, `--group` | **Functional category / Item type** | *What is this item?* | `dotfiles`, `config`, `scripts`, `bin` |
| **Tags** | `-t`, `--tag` | **Context or environment identifiers** | *Where/when should it be used?* | `work`, `personal`, `shell`, `dev`, `server` |

---

## Map File Format (`sync-map.conf`)

Each item added to MountSync is registered in the profile map (`sync-map.conf`) using pipe-separated fields (`|`):

```text
relative_local|relative_cloud|tags|groups
```

### Example `sync-map.conf` File

```text
.bashrc|.bashrc|shell,main|dotfiles
.config/nvim|.config/nvim|dev,editor|config
.gitconfig|.gitconfig|main|dotfiles
.tmux.conf|.tmux.conf|server,shell|config
```

---

## How Filtering Works

Filtering by Tags and Groups can be applied to the `init`, `pull`, `list`, and `status` subcommands.

### Matching Rules:
1. **Comma-Separated Lists**: You can specify multiple tags or groups (e.g., `--tag work,dev`). MountSync matches if the item contains **at least one** of the specified tags/groups (internal `OR` logic).
2. **Combining Tags and Groups**: If you specify **both** `--tag` and `--group` in the same command, the item must satisfy criteria for both filters (internal `AND` logic between filters).

---

## Practical Examples by Subcommand

### 1. Adding Items with Metadata (`mosy add`)
When adding a file or directory, assign tags and groups for easier tracking:

```bash
# Add Neovim configuration
mosy add ~/.config/nvim -g config -t work,dev,editor

# Add .bashrc
mosy add ~/.bashrc --group dotfiles --tag shell,main
```

### 2. Non-Destructive Synchronization (`mosy pull`)
Fetch only relevant items from the cloud for the current machine:

```bash
# Pull only development configurations
mosy pull --tag dev

# Pull only dotfiles from the 'dotfiles' group
mosy pull -g dotfiles
```

### 3. Selective Machine Initialization (`mosy init`)
Provision a new machine applying only elements suitable for its usage profile:

```bash
# Provision a work machine
mosy init --tag work

# Provision a server (only scripts and shell configs)
mosy init --group scripts,config --tag server
```

### 4. Listing Filtered Items (`mosy list`)
View managed files filtered by category or context:

```bash
# List all dotfiles
mosy list --group dotfiles

# List items tagged with 'work'
mosy list -t work
```

Example output:
```text
Items managed by MountSync:
- .bashrc [tags: shell,main] [groups: dotfiles]
- .config/nvim [tags: dev,editor] [groups: config]
```

### 5. Checking Filtered Integrity (`mosy status`)
Validate link status for a specific category:

```bash
# Check integrity of development items at work
mosy status --tag work,dev --group config
```

---

## Related Guides

* [Multiple Profiles Guide](PROFILES.md): Learn how to isolate your maps by profile.
* [Configuration Reference](CONFIGURATION.md): Adjust environment variables and preferences.
* [CLI Reference](CLI_REFERENCE.md): Consult all available commands and flags.
* [Main README](../README.md): Return to the main page.
