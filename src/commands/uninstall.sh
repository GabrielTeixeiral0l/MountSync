#!/bin/bash

cmd_uninstall() {
    echo "=== MountSync Uninstall ==="
    # Ensure we can read from TTY if piped
    local tty_input="/dev/stdin"
    [ -c /dev/tty ] && [ -z "$MOSY_NO_TTY" ] && tty_input="/dev/tty"

    read -p "Desejas reverter todos os ficheiros sincronizados para ficheiros locais? (s/N) " revert < "$tty_input"
    
    if [[ "$revert" =~ ^([sS][imIM]|[sS])$ ]]; then
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

    read -p "A pasta de instalação (~/.mountsync) será removida. Confirmar? (s/N) " confirm < "$tty_input"
    if [[ "$confirm" =~ ^([sS][imIM]|[sS])$ ]]; then
        echo "Cleaning up files..."
        # Final cleanup: removing the project folder
        # We can't easily rm -rf the current dir while running from it, 
        # so we schedule it or warn the user.
        echo "Por favor, remove manualmente a pasta: rm -rf $HOME/.mountsync"
        echo "MountSync desinstalado com sucesso. Adeus!"
    fi
}
