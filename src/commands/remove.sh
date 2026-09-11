#!/bin/bash

cmd_remove() {
    check_mount
    if [ -z "$1" ]; then
        echo "Usage: mosy remove <file_or_directory>"
        exit 1
    fi

    local target_arg="$1"
    if command -v cygpath >/dev/null 2>&1; then
        target_arg=$(cygpath -u "$target_arg" 2>/dev/null || echo "$target_arg")
    fi
    local TARGET
    TARGET=$(realpath -s "$target_arg" 2>/dev/null || echo "$target_arg")
    if command -v cygpath >/dev/null 2>&1; then
        TARGET=$(cygpath -u "$TARGET" 2>/dev/null || echo "$TARGET")
    fi
    local REL_PATH
    REL_PATH=$(get_relative_home_path "$target_arg")

    if [ -L "$TARGET" ]; then
        local SOURCE
        SOURCE=$(readlink -f "$TARGET")

        if [ ! -e "$SOURCE" ]; then
            echo "Error: Cloud source missing at $SOURCE"
            echo "The link is broken. Removing the broken link to cleanup..."
            rm "$TARGET"
            update_map_remove_entry "$REL_PATH"
            echo "Success! Broken link removed and item unmanaged."
            return 0
        fi

        echo "Reverting $REL_PATH to local file..."
        rm "$TARGET" && cp -r "$SOURCE" "$TARGET" || { echo "Error: Failed to copy from cloud."; exit 1; }
    elif [ -d "$TARGET" ] && grep -q "^${REL_PATH}|" "$MOSY_MAP_FILE" 2>/dev/null; then
        # Revert all managed cloud symlinks inside directory to regular local files
        echo "Reverting $REL_PATH to local directory..."
        while IFS= read -r -d '' link; do
            local link_target
            link_target=$(readlink "$link")
            if [[ "$link_target" == "$MOSY_PROFILE_DIR"* ]]; then
                if [ -e "$link_target" ]; then
                    rm "$link" && cp -r "$link_target" "$link"
                else
                    rm "$link"
                fi
            fi
        done < <(find "$TARGET" -type l -print0)
    else
        echo "Error: $1 is not a symbolic link managed by MountSync."
        exit 1
    fi

    # Robust map update
    update_map_remove_entry "$REL_PATH"

    echo "Success! $REL_PATH is now a local file."
    echo "Note: The cloud copy remains in the vault for your other devices."
}
