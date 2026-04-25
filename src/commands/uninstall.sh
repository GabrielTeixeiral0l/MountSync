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

    echo "Stopping and disabling service..."
    systemctl --user stop mosy-mount.service || true
    systemctl --user disable mosy-mount.service || true
    rm -f "$HOME/.config/systemd/user/mosy-mount.service"

    echo "Removing binary..."
    rm -f "$HOME/.local/bin/mosy"

    read -p "The installation folder (~/.mountsync) will be removed. Confirm? (y/N) " confirm < "$tty_input"
    if [[ "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Cleaning up files..."
        # Final cleanup: removing the project folder
        # We can't easily rm -rf the current dir while running from it, 
        # so we schedule it or warn the user.
        echo "Please manually remove the folder: rm -rf $HOME/.mountsync"
        echo "MountSync uninstalled successfully. Goodbye!"
    fi
}
