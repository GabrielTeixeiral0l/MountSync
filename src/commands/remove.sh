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
    
    echo "Reverting $REL_PATH to local file..."
    rm "$TARGET"
    if [ -d "$SOURCE" ]; then
        cp -r "$SOURCE" "$TARGET"
    else
        cp "$SOURCE" "$TARGET"
    fi

    # Remove from map
    local clean_content=$(grep -v "^$REL_PATH|" "$MAP_FILE")
    echo "$clean_content" > "$MAP_FILE"

    echo "Success! $REL_PATH is now a local file."
    echo "Note: The cloud copy remains in the vault for your other devices."
}
