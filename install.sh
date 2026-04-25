#!/bin/bash

# MountSync - install.sh
# Installation script for MountSync

set -e # Exit on error

# Auto-download if piped from curl
if [ ! -f "mosy" ] || [ ! -d "src" ]; then
    echo "--- Downloading MountSync ---"
    if [ -d "$HOME/.mountsync" ]; then
        echo "Updating existing repository at $HOME/.mountsync..."
        cd "$HOME/.mountsync"
        git pull origin main
    else
        echo "Cloning repository to $HOME/.mountsync..."
        git clone https://github.com/GabrielTeixeiral0l/MountSync.git "$HOME/.mountsync"
        cd "$HOME/.mountsync"
    fi
    if [ -c /dev/tty ]; then
        exec bash install.sh < /dev/tty
    else
        exec bash install.sh
    fi
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
        echo "Error: rclone is required for MountSync."
        exit 1
    fi
fi

# 1.5. Remote Configuration Check
if ! rclone listremotes | grep -q .; then
    echo "--- rclone Configuration ---"
    echo "No cloud remotes detected in rclone."
    read -p "Would you like to configure one now? (y/n): " run_config
    if [[ $run_config =~ ^[Yy]$ ]]; then
        rclone config
    else
        echo "Warning: You need at least one configured rclone remote for MountSync to work."
    fi
fi

# 2. Configuration Wizard
echo "--- MountSync Setup ---"
read -p "Enter your rclone remote name [$DEFAULT_REMOTE]: " REMOTE_NAME
REMOTE_NAME="${REMOTE_NAME:-$DEFAULT_REMOTE}"

read -p "Enter your cloud mount point [$DEFAULT_MOUNT]: " MOUNT_POINT
MOUNT_POINT="${MOUNT_POINT:-$DEFAULT_MOUNT}"
MOUNT_POINT="${MOUNT_POINT/#\~/$HOME}" 

# 2.5. Mount Awareness Check
SHOULD_SETUP_SYSTEMD=true
if mountpoint -q "$MOUNT_POINT" 2>/dev/null || mount | grep -q "$MOUNT_POINT"; then
    echo "Notice: $MOUNT_POINT is already a mountpoint."
    read -p "Do you still want to install the MountSync auto-mount service? (y/N): " setup_service
    if [[ ! $setup_service =~ ^[Yy]$ ]]; then
        SHOULD_SETUP_SYSTEMD=false
        echo "Skipping Systemd service setup. MountSync will use your existing mount."
    fi
fi

# 3. Generation of Configuration
CONFIG_DIR="${HOME}/.config/mosy"
mkdir -p "$CONFIG_DIR" || { echo "Error: Could not create config directory $CONFIG_DIR"; exit 1; }
CONFIG_FILE="$CONFIG_DIR/config"

cat <<EOF > "$CONFIG_FILE" || { echo "Error: Could not write to $CONFIG_FILE"; exit 1; }
MOSY_REMOTE_NAME="$REMOTE_NAME"
MOSY_MOUNT_POINT="$MOUNT_POINT"
MOSY_CLOUD_DIR="$MOUNT_POINT/mosy_vault"
EOF

# 4. Persistence with Systemd
if [ "$SHOULD_SETUP_SYSTEMD" = true ]; then
    SERVICE_DIR="${HOME}/.config/systemd/user"
    mkdir -p "$SERVICE_DIR" || { echo "Error: Could not create systemd directory $SERVICE_DIR"; exit 1; }
    SERVICE_FILE="$SERVICE_DIR/mosy-mount.service"

    RCLONE_PATH=$(command -v rclone)

    cat <<EOF > "$SERVICE_FILE" || { echo "Error: Could not write to $SERVICE_FILE"; exit 1; }
[Unit]
Description=Rclone Mount for MountSync
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
    systemctl --user enable mosy-mount.service || echo "Warning: Could not enable systemd service (might be in a container/non-systemd system)."
    systemctl --user start mosy-mount.service || echo "Warning: Could not start systemd service. You may need to start it manually."
fi

# 5. Integration in PATH
BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR" || { echo "Error: Could not create $BIN_DIR"; exit 1; }
ln -sf "$(pwd)/mosy" "$BIN_DIR/mosy"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "Warning: $BIN_DIR is not in your PATH."
    echo "Add the following line to your ~/.bashrc (or ~/.zshrc):"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo "Installation complete! 'mosy' is now linked to $BIN_DIR/mosy"
