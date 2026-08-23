# How to Prevent Secret Leaks with MountSync

This guide explains how to protect sensitive credentials, API keys, private certificates, and environment files from accidentally uploading to cloud storage when using MountSync.

---

## Overview

Dotfile repositories and synchronized folders frequently contain sensitive credentials:
- SSH private keys (`id_rsa`, `id_ed25519`)
- API tokens (AWS credentials, GitHub personal access tokens, Stripe API keys)
- Environment files (`.env`, `.env.local`)
- SSL/TLS certificates and private keys (`*.pem`, `*.key`, `*.pfx`)

MountSync provides a built-in pre-vaulting secret inspection engine (`src/secrets.sh`) that evaluates files before moving them into your Cloud Vault.

---

## Step 1: Built-in Detection Rules

MountSync inspects target files against two categories of detection rules:

### 1. Sensitive Filenames

Files matching the following names or glob patterns are flagged immediately:
- `.env`, `.env.*`, `*.env`
- `id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519`
- `*.pem`, `*.key`, `*.pkcs12`, `*.pfx`
- `credentials.json`, `service-account*.json`
- `secrets.yaml`, `secrets.yml`

### 2. File Content Patterns

MountSync scans file contents using regular expressions targeting common credential signatures:
- **Private Keys**: `-----BEGIN.*PRIVATE KEY-----`, `-----BEGIN OPENSSH PRIVATE KEY-----`, `-----BEGIN PGP PRIVATE KEY BLOCK-----`
- **AWS Credentials**: `AKIA[0-9A-Z]{16}`, `aws_secret_access_key`
- **GitHub Tokens**: `ghp_[0-9a-zA-Z]{36}`, `github_pat_[0-9a-zA-Z_]{82}`
- **Slack Tokens**: `xox[baprs]-[0-9a-zA-Z]{10,48}`
- **Stripe Keys**: `sk_live_[0-9a-zA-Z]{24}`

---

## Step 2: Enable Secret Scanning

### On-Demand via CLI Flag

To scan a file or directory on demand during `add`:

```bash
# Scan a single file
mosy add ~/.gitconfig --scan-secrets

# Short flag variant
mosy add ~/.config/nvim --scan
```

### Global Configuration

To enable secret scanning by default across all `mosy add` operations, configure `MOSY_SCAN_SECRETS`:

```bash
mosy config set MOSY_SCAN_SECRETS "true"
```

Or edit `~/.config/mosy/config`:

```bash
MOSY_SCAN_SECRETS="true"
```

### Bypassing Secret Scanning

If you need to bypass scanning for a trusted path when global scanning is enabled:

```bash
mosy add ~/.my_config --no-scan
```

---

## Step 3: Interactive Safety Prompts

When a potential secret is detected, MountSync displays an interactive warning and pauses execution.

### Single File Prompt

When adding an individual sensitive file:

```text
Warning: Potential secret detected in /home/user/.env
Reason: Matches sensitive filename pattern (.env)
Do you want to continue adding this file to the cloud vault? (y/N):
```

- Answering `y` or `yes` moves the file to the cloud vault and symlinks it.
- Pressing `Enter` or answering `n` halts execution and leaves the local file untouched.

### Directory Batch Prompt

When adding a directory containing sensitive files:

```text
Warning: 2 potential secrets detected inside /home/user/.config/myapp:
  - secrets.json (Matches sensitive filename pattern)
  - auth.key (Private key detected)

Choose an action:
  [y]es: Add all files including detected secrets to cloud vault
  [s]kip: Keep detected secret files on local disk only (recommended)
  [n]o: Abort adding this directory
Choice (y/s/n) [s]:
```

- **`s` (Skip - Recommended)**: Keeps sensitive files on local physical storage without moving or uploading them, while moving and symlinking all other safe configuration files.
- **`y` (Yes)**: Moves all files (including secrets) to the cloud vault.
- **`n` (No)**: Cancels the entire operation without modifying the filesystem.

---

## Step 4: Define Custom Secret Patterns (`secrets.conf`)

You can extend the scanning engine with organization-specific tokens or custom filenames by creating `~/.config/mosy/secrets.conf`.

### Syntax

- Lines starting with `file:` define filename patterns (glob format).
- Other non-empty lines define regular expressions matched against file contents.
- Lines starting with `#` are comments.

### Example `~/.config/mosy/secrets.conf`

```text
# Custom filename exclusions
file:internal_credentials.json
file:*.auth
file:production_*.conf

# Custom token regex patterns
COMPANY_API_KEY_[A-Z0-9]{32}
jwt_token_secret:[A-Za-z0-9+/=]+
SECRET_ENCRYPTION_KEY=[^\n\r]+
```

---

## Non-Interactive & CI Automation

In automated scripts or environments without a TTY (`MOSY_NO_TTY=true` or piped stdin), MountSync automatically halts execution with exit code `1` when a secret is detected to prevent accidental leaks.

To force synchronization in headless scripts when intended, pass `-f` / `--force`:

```bash
mosy add ~/.my_config --scan --force
```

---

## Related Documentation

- [CLI Reference](../reference/cli.md): Parameter details for `mosy add`.
- [Ignore Patterns Guide](mosyignore.md): Exclude folders and files permanently.
- [Configuration Reference](../reference/configuration.md): `MOSY_SCAN_SECRETS` and settings options.
- [Documentation Portal](../README.md): Return to the main project documentation index.
