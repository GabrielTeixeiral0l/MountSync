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
    if [ -t 0 ] || [ -c /dev/tty ]; then
        # Try to use TTY if available, otherwise just run
        exec bash install.sh < /dev/tty 2>/dev/null || exec bash install.sh
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

REMOTES=($(rclone listremotes 2>/dev/null | sed 's/://'))
DEFAULT_REMOTE="GoogleDrive"
if [ ${#REMOTES[@]} -gt 0 ]; then
    DEFAULT_REMOTE="${REMOTES[0]}"
    echo "Detected rclone remotes:"
    for i in "${!REMOTES[@]}"; do
        echo "  $((i+1))) ${REMOTES[$i]}"
    done
fi

VALID_REMOTE=false
while [ "$VALID_REMOTE" = false ]; do
    read -p "Enter your rclone remote name or number [$DEFAULT_REMOTE]: " REMOTE_INPUT
    if [[ "$REMOTE_INPUT" =~ ^[0-9]+$ ]] && [ "$REMOTE_INPUT" -le "${#REMOTES[@]}" ] && [ "$REMOTE_INPUT" -gt 0 ]; then
        REMOTE_NAME="${REMOTES[$((REMOTE_INPUT-1))]}"
    else
        REMOTE_NAME="${REMOTE_INPUT:-$DEFAULT_REMOTE}"
    fi
    
    # Validation check
    FOUND=false
    for r in "${REMOTES[@]}"; do
        if [ "$r" == "$REMOTE_NAME" ]; then FOUND=true; break; fi
    done
    
    if [ "$FOUND" = true ] || [ ${#REMOTES[@]} -eq 0 ]; then
        VALID_REMOTE=true
    else
        echo "Warning: Remote '$REMOTE_NAME' not found in rclone configuration."
        read -p "Do you want to proceed anyway? (y/N): " PROCEED
        if [[ $PROCEED =~ ^[Yy]$ ]]; then
            VALID_REMOTE=true
        fi
    fi
done

VALID_PATH=false
while [ "$VALID_PATH" = false ]; do
    read -p "Enter your cloud mount point [$DEFAULT_MOUNT]: " MOUNT_INPUT
    MOUNT_POINT="${MOUNT_INPUT:-$DEFAULT_MOUNT}"
    MOUNT_POINT="${MOUNT_POINT/#\~/$HOME}"
    
    if [ -d "$MOUNT_POINT" ]; then
        VALID_PATH=true
    else
        read -p "Directory '$MOUNT_POINT' does not exist. Create it now? (Y/n): " CREATE_DIR
        if [[ ! $CREATE_DIR =~ ^[Nn]$ ]]; then
            if mkdir -p "$MOUNT_POINT" 2>/dev/null; then
                VALID_PATH=true
            else
                echo "Error: Could not create directory $MOUNT_POINT. Please check permissions."
            fi
        fi
    fi
done

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
