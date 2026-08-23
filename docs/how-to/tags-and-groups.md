# How to Organize and Filter Items with Tags and Groups in MountSync

This guide explains how to use Tags and Groups to categorize, organize, and selectively synchronize files and directories across different environments and use cases.

---

## Conceptual Difference: Tags vs. Groups

MountSync categorizes items using two orthogonal dimensions:

* **Groups (`-g`, `--group`)**: Functional categories describing what an item is or its role (e.g., `dotfiles`, `config`, `scripts`, `bin`). An item belongs to functional groups based on its structural purpose.
* **Tags (`-t`, `--tag`)**: Contextual attributes describing where, when, or under what conditions an item should be applied (e.g., `work`, `personal`, `server`, `dev`, `shell`).

| Feature | Groups (`-g`, `--group`) | Tags (`-t`, `--tag`) |
| :--- | :--- | :--- |
| **Core Question** | *What is this item?* | *Where or when is this item used?* |
| **Perspective** | Structural / Functional category | Contextual / Environment label |
| **Example Values** | `dotfiles`, `config`, `scripts`, `databases` | `work`, `personal`, `server`, `linux`, `macos` |

---

## The Map File Format (`sync-map.conf`)

Each managed item is recorded in the profile configuration map (`sync-map.conf`) located in your storage vault. MountSync uses a 4-field format separated by pipe characters (`|`):

```text
local_path|cloud_path|tags|groups
```

### Field Definitions

1. `local_path`: Relative or absolute path on the local filesystem.
2. `cloud_path`: Relative destination path inside the vault storage.
3. `tags`: Comma-separated list of contextual tag labels (optional).
4. `groups`: Comma-separated list of functional group labels (optional).

### Example Configuration

```text
.bashrc|.bashrc|work,personal,shell|dotfiles
.config/nvim|.config/nvim|work,dev,editor|config
.ssh/config_work|.ssh/config_work|work,server|config
scripts/deploy.sh|scripts/deploy.sh|work,server,dev|scripts
```

---

## How Filtering Works Across Subcommands

Filtering by `--tag` / `-t` and `--group` / `-g` is supported in the following subcommands: `add`, `init`, `pull`, `list`, `diff`, and `status`.

### Filter Evaluation Rules

1. **Multiple Values in a Single Flag (OR Logic)**: Passing comma-separated values to a flag (e.g., `--tag work,dev`) selects items that match **at least one** of the listed tags.
2. **Combining Tags and Groups (AND Logic)**: Passing both `--tag` and `--group` in the same command requires an item to satisfy **both** tag and group criteria simultaneously.

---

## Practical Recipes

### Recipe 1: Adding Items with Tags and Groups (`mosy add`)

Assign functional groups and contextual tags when adding items to MountSync:

```bash
# Add Neovim config categorized under 'config' group with 'work', 'dev', and 'editor' tags
mosy add ~/.config/nvim -g config -t work,dev,editor

# Add .bashrc under 'dotfiles' group with 'shell' and 'work' tags
mosy add ~/.bashrc --group dotfiles --tag shell,work

# Add deployment scripts under 'scripts' group with 'server' tag
mosy add ~/bin/deploy.sh -g scripts -t server
```

### Recipe 2: Synchronizing Only Work Dotfiles (`mosy pull`)

When setting up or updating a work computer, fetch only configuration files tagged for work:

```bash
# Pull items tagged as 'work' belonging to the 'dotfiles' group
mosy pull --tag work --group dotfiles

# Pull all work-related configurations regardless of group
mosy pull -t work
```

### Recipe 3: Selective Machine Initialization (`mosy init`)

Provision a fresh installation based on the machine's role:

```bash
# Initialize a machine with only server scripts and configurations
mosy init --group scripts,config --tag server

# Initialize a primary workstation with work dotfiles
mosy init -g dotfiles -t work
```

### Recipe 4: Checking Status of Server Configurations (`mosy status`)

Inspect the synchronization status and link health for server-related items before deploying:

```bash
# Check status of items tagged with 'server' inside the 'config' group
mosy status --tag server --group config

# Check status for all items tagged with 'server' or 'production'
mosy status -t server,production
```

### Recipe 5: Listing Filtered Managed Items (`mosy list`)

View specific subsets of managed items defined in your configuration:

```bash
# List all managed dotfiles
mosy list --group dotfiles

# List development tools tagged for work
mosy list -t work,dev -g config
```

---

## Related Documentation

* [Multiple Profiles Guide](profiles.md): Learn how to isolate map files by environment profiles.
* [Ignore Patterns Guide](mosyignore.md): Exclude unwanted files from synchronization.
* [Multi-Machine Sync Guide](multi-machine-sync.md): Replicate configurations across devices.
* [Configuration Reference](../reference/configuration.md): Environment variable specifications.
* [CLI Reference](../reference/cli.md): Full command-line interface documentation.
* [Documentation Portal](../README.md): Return to documentation index.
