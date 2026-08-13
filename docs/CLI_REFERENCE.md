# CLI Reference (`mosy`)

Complete documentation of all global flags and subcommands available in the **MountSync** (`mosy`) command-line interface.

---

## General Syntax

```bash
mosy [-p|--profile <name>] <subcommand> [options]
```

---

## Global Flags

| Flag | Argument | Description | Example |
| :--- | :--- | :--- | :--- |
| `-p`, `--profile` | `<name>` | Sets the active synchronization profile for the command execution. | `mosy -p work list` |

---

## Subcommands

### `add`
Synchronizes a new local file or directory to the cloud vault and replaces the original with a symbolic link.

* **Syntax:** `mosy add <path> [--tag <tags>] [--group <groups>]`
* **Options:**
  * `-t`, `--tag <tags>`: Comma-separated list of tags.
  * `-g`, `--group <groups>`: Comma-separated list of groups.
* **Behavior:**
  * The item must reside within the user home directory (`$HOME`).
  * If the file already exists in the cloud vault, a backup copy of the local version is created before replacing it with the symlink.
  * Registers the entry in the `sync-map.conf` file.
* **Example:**
  ```bash
  mosy add ~/.config/nvim -g config -t work,dev
  ```

---

### `init`
Initializes a machine by recreating all symbolic links defined in `sync-map.conf`.

* **Syntax:** `mosy init [--tag <tags>] [--group <groups>]`
* **Options:**
  * `-t`, `--tag <tags>`: Filters items by the specified tags.
  * `-g`, `--group <groups>`: Filters items by the specified groups.
* **Behavior:**
  * If a local file already exists and is a regular file (not a symlink), MountSync automatically backs it up to `<file>.bak_<timestamp>` before creating the link.
  * If the symbolic link already exists, it is replaced.
* **Example:**
  ```bash
  mosy init --tag work --group config
  ```

---

### `pull`
Non-destructive incremental synchronization of missing items.

* **Syntax:** `mosy pull [--tag <tags>] [--group <groups>]`
* **Options:**
  * `-t`, `--tag <tags>`: Filters items by the specified tags.
  * `-g`, `--group <groups>`: Filters items by the specified groups.
* **Behavior:**
  * Iterates through `sync-map.conf` and creates symbolic links only for items that exist in the cloud but not on the local machine.
  * **Non-destructive:** If the file already exists locally (as a file or symlink), `pull` does not modify it.
* **Example:**
  ```bash
  mosy pull -t shell
  ```

---

### `list`
Lists all files and directories managed by MountSync under the selected profile.

* **Syntax:** `mosy list [--tag <tags>] [--group <groups>]`
* **Options:**
  * `-t`, `--tag <tags>`: Lists only items with the specified tags.
  * `-g`, `--group <groups>`: Lists only items with the specified groups.
* **Example:**
  ```bash
  mosy list -g dotfiles
  ```

---

### `status`
Checks system integrity and managed file status.

* **Syntax:** `mosy status [--tag <tags>] [--group <groups>]`
* **Options:**
  * `-t`, `--tag <tags>`: Filters status check by tags.
  * `-g`, `--group <groups>`: Filters status check by groups.
* **Behavior:**
  * Checks if the cloud drive is mounted (`is_mounted`).
  * Checks the status of the Systemd service (`mosy-mount.service`).
  * Validates each symbolic link:
    * `[OK]`: Symbolic link points correctly to the cloud vault.
    * `[WARN]`: File exists in the cloud vault but local symlink is missing.
    * `[ERR]`: Broken link or pointing to incorrect target.
* **Example:**
  ```bash
  mosy status
  ```

---

### `remove`
Removes an item from MountSync management.

* **Syntax:** `mosy remove <path>`
* **Behavior:**
  * Replaces the local symbolic link with a real copy of the file/directory from the cloud vault.
  * Removes the item entry from `sync-map.conf`.
  * **Note:** The copy in the cloud vault remains intact so other synchronized computers are not affected.
* **Example:**
  ```bash
  mosy remove ~/.bashrc
  ```

---

### `config`
Views or modifies configuration settings.

* **Syntax:** `mosy config [set <KEY> <VALUE>]`
* **Subcommands:**
  * Without arguments: Lists all variables and explanatory comments.
  * `set <KEY> <VALUE>`: Sets the value of a configuration key in `~/.config/mosy/config`.
* **Example:**
  ```bash
  mosy config
  mosy config set MOSY_LOG_LEVEL "DEBUG"
  ```

---

### `version`
Displays the currently installed version and checks for updates on GitHub.

* **Syntax:** `mosy version`
* **Example:**
  ```bash
  mosy version
  ```

---

### `update`
Updates MountSync to the latest version available in the repository.

* **Syntax:** `mosy update`
* **Behavior:**
  * Performs `git pull` on the MountSync repository and executes the update wizard.
  * In case of failure, automatically rolls back to the previous commit.
* **Example:**
  ```bash
  mosy update
  ```

---

### `uninstall`
MountSync uninstallation wizard.

* **Syntax:** `mosy uninstall`
* **Behavior:**
  * Interactively prompts whether to revert all managed symbolic links back to real local files.
  * Disables and removes the Systemd service `mosy-mount.service`.
  * Removes the `mosy` binary and shell completion settings (`.bashrc` / `.zshrc`).
* **Example:**
  ```bash
  mosy uninstall
  ```

---

## Related Guides

* [Multiple Profiles Guide](PROFILES.md): Learn how to use the `-p / --profile` argument.
* [Tags and Groups](TAGS_AND_GROUPS.md): Details on filtering with `-t` and `-g`.
* [Configuration Reference](CONFIGURATION.md): Consult all supported variables.
* [Main README](../README.md): Return to the main page.
