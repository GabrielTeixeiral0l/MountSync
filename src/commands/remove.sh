#!/bin/bash

cmd_remove() {
    check_mount
    if [ -z "$1" ]; then
        echo "Usage: mosy remove <file_or_directory>"
        exit 1
    fi

    local TARGET=$(realpath -s "$1")
    local REL_PATH=${TARGET#$HOME/}

    if [ ! -L "$TARGET" ]; then
        echo "Error: $1 is not a symbolic link managed by MountSync."
        exit 1
    fi

    local SOURCE=$(readlink -f "$TARGET")
    
    if [ ! -e "$SOURCE" ]; then
        echo "Error: Cloud source missing at $SOURCE"
        echo "The link is broken. Removing the broken link to cleanup..."
        rm "$TARGET"
        # Cleanup map anyway to keep it consistent
        local clean_map=$(grep -v "^$REL_PATH|" "$MAP_FILE")
        echo "$clean_map" > "$MAP_FILE"
        echo "Success! Broken link removed and item unmanaged."
        return 0
    fi

    echo "Reverting $REL_PATH to local file..."
    # Copy to a local temporary name first to ensure success before deleting the link
    if [ -d "$SOURCE" ]; then
        cp -r "$SOURCE" "${TARGET}.new" || { echo "Error: Failed to copy from cloud."; exit 1; }
    else
        cp "$SOURCE" "${TARGET}.new" || { echo "Error: Failed to copy from cloud."; exit 1; }
    fi

    # Atomic-like swap
    rm "$TARGET"
    mv "${TARGET}.new" "$TARGET"

    # Robust map update
    local clean_map=$(grep -v "^$REL_PATH|" "$MAP_FILE")
    echo "$clean_map" > "$MAP_FILE"

    echo "Success! $REL_PATH is now a local file."
    echo "Note: The cloud copy remains in the vault for your other devices."
}
