#!/bin/bash

# ConfigSync - install.sh
# Installation script for ConfigSync

set -e # Exit on error

# Auto-download if piped from curl
if [ ! -f "csync" ] || [ ! -d "src" ]; then
    echo "--- Downloading ConfigSync ---"
    if [ -d "$HOME/.configsync" ]; then
        echo "Updating existing repository at $HOME/.configsync..."
        cd "$HOME/.configsync"
        git pull origin main
    else
        echo "Cloning repository to $HOME/.configsync..."
        git clone https://github.com/GabrielTeixeiral0l/configsync.git "$HOME/.configsync"
        cd "$HOME/.configsync"
    fi
    exec bash install.sh
    exit 0
fi

# Default values
DEFAULT_REMOTE="GoogleDrive"
DEFAULT_MOUNT="${HOME}/GoogleDrive"

# 1. Dependency Check: rclone
if ! command -v rclone &> /dev/null; then
    echo "rclone not found."
    read -p "Install rclone now? (y/n): " install_rclone
    if [[ $install_rclone =~ ^[Yy]$ ]]; then
        echo "Installing rclone..."
        sudo -v 
        curl https://rclone.org/install.sh | sudo bash
    else
        echo "Error: rclone is required for ConfigSync."
        exit 1
    fi
fi

# 2. Configuration Wizard
echo "--- ConfigSync Setup ---"
read -p "Enter your rclone remote name [$DEFAULT_REMOTE]: " REMOTE_NAME
REMOTE_NAME="${REMOTE_NAME:-$DEFAULT_REMOTE}"

read -p "Enter your cloud mount point [$DEFAULT_MOUNT]: " MOUNT_POINT
MOUNT_POINT="${MOUNT_POINT:-$DEFAULT_MOUNT}"
MOUNT_POINT="${MOUNT_POINT/#\~/$HOME}" 

# 3. Generation of Configuration
CONFIG_DIR="${HOME}/.config/csync"
mkdir -p "$CONFIG_DIR" || { echo "Error: Could not create config directory $CONFIG_DIR"; exit 1; }
CONFIG_FILE="$CONFIG_DIR/config"

cat <<EOF > "$CONFIG_FILE" || { echo "Error: Could not write to $CONFIG_FILE"; exit 1; }
CSYNC_REMOTE_NAME="$REMOTE_NAME"
CSYNC_MOUNT_POINT="$MOUNT_POINT"
CSYNC_CLOUD_DIR="$MOUNT_POINT/csync_vault"
EOF

# 4. Persistence with Systemd
SERVICE_DIR="${HOME}/.config/systemd/user"
mkdir -p "$SERVICE_DIR" || { echo "Error: Could not create systemd directory $SERVICE_DIR"; exit 1; }
SERVICE_FILE="$SERVICE_DIR/csync-mount.service"

RCLONE_PATH=$(command -v rclone)

cat <<EOF > "$SERVICE_FILE" || { echo "Error: Could not write to $SERVICE_FILE"; exit 1; }
[Unit]
Description=Rclone Mount for ConfigSync
After=network-online.target

[Service]
Type=simple
ExecStart=$RCLONE_PATH mount ${REMOTE_NAME}: ${MOUNT_POINT} --vfs-cache-mode writes
ExecStop=/bin/fusermount -u ${MOUNT_POINT}
Restart=on-failure

[Install]
WantedBy=default.target
EOF

echo "Setting up Systemd service..."
systemctl --user daemon-reload || true
systemctl --user enable csync-mount.service || echo "Warning: Could not enable systemd service (might be in a container/non-systemd system)."

# 5. Integration in PATH
BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR" || { echo "Error: Could not create $BIN_DIR"; exit 1; }
ln -sf "$(pwd)/csync" "$BIN_DIR/csync"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "Warning: $BIN_DIR is not in your PATH."
    echo "Add the following line to your ~/.bashrc (or ~/.zshrc):"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo "Installation complete! 'csync' is now linked to $BIN_DIR/csync"
