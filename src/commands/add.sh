#!/bin/bash

cmd_add() {
    check_mount
    if [ -z "$1" ]; then
        echo "Usage: mosy add <file_or_directory>"
        exit 1
    fi

    local RAW_TARGET="$1"
    
    if [ -L "$RAW_TARGET" ]; then
        echo "Warning: $RAW_TARGET is already a symbolic link."
        exit 0
    fi

    if [ ! -e "$RAW_TARGET" ]; then
        echo "Error: $RAW_TARGET does not exist."
        exit 1
    fi

    TARGET=$(realpath "$RAW_TARGET")
    HOME_DIR="${HOME}"
    if [[ "$TARGET" != "$HOME_DIR"* ]]; then
        echo "Error: Target must be within your home directory ($HOME_DIR)."
        exit 1
    fi

    REL_PATH=${TARGET#$HOME_DIR/}
    CLOUD_DEST="$MOSY_CLOUD_DIR/$REL_PATH"
    CLOUD_DEST_DIR=$(dirname "$CLOUD_DEST")

    mkdir -p "$CLOUD_DEST_DIR"

    echo "Syncing $REL_PATH..."
    if [ -e "$CLOUD_DEST" ]; then
        echo "Warning: A version already exists in the cloud at $REL_PATH. Backing up local copy."
        mv "$TARGET" "${TARGET}.backup_$(date +%s)" || exit 1
    else
        mv "$TARGET" "$CLOUD_DEST" || exit 1
    fi

    ln -s "$CLOUD_DEST" "$TARGET"

    touch "$MOSY_MAP_FILE"
    if ! grep -q "^$REL_PATH|" "$MOSY_MAP_FILE"; then
        echo "$REL_PATH|$REL_PATH" >> "$MOSY_MAP_FILE"
    fi

    echo "Success! $REL_PATH is now synced."
}
