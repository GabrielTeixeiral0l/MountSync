#!/bin/bash

cmd_uninstall() {
    echo "=== MountSync Uninstall ==="
    # Ensure we can read from TTY if piped
    local tty_input="/dev/stdin"
    [ -c /dev/tty ] && [ -z "$MOSY_NO_TTY" ] && tty_input="/dev/tty"

    read -p "Do you want to revert all synced files to local files? (y/N) " revert < "$tty_input"
    
    if [[ "$revert" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        source "${SCRIPT_DIR}/src/commands/remove.sh"
        revert_item() {
            local rel_path=$1
            # Call remove command for the item
            cmd_remove "$HOME/$rel_path"
        }
        foreach_mapping revert_item
    fi

    read -p "The installation folder ($SCRIPT_DIR) and binary will be removed. Confirm? (y/N) " confirm < "$tty_input"
    if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Cleaning up system integration..."
        
        # Ask before stopping the mount
        read -p "Do you want to unmount the cloud drive ($MOSY_MOUNT_POINT) now? (y/N) " unmount < "$tty_input"
        if [[ "$unmount" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "Stopping service and unmounting..."
            systemctl --user stop mosy-mount.service || true
        fi

        echo "Disabling service and removing files..."
        systemctl --user disable mosy-mount.service || true
        rm -f "$HOME/.config/systemd/user/mosy-mount.service"
        rm -f "$HOME/.local/bin/mosy"
        rm -rf "$SCRIPT_DIR"
        
        echo "MountSync uninstalled successfully. Goodbye!"
    else
        echo "Uninstall cancelled. System remains unchanged."
    fi
}
