#!/bin/bash

cmd_add() {
    check_mount
    local RAW_TARGET=""
    parse_filter_flags "$@"
    local TAGS="$MOSY_FILTER_TAG"
    local ITEM_GROUPS="$MOSY_FILTER_GROUP"

    while [ $# -gt 0 ]; do
        case "$1" in
            --tag|-t|--group|-g)
                shift 2
                ;;
            *)
                [ -z "$RAW_TARGET" ] && RAW_TARGET="$1"
                shift
                ;;
        esac
    done

    if [ -z "$RAW_TARGET" ]; then
        echo "Usage: mosy add <file_or_directory> [--tag <tags>] [--group <groups>]"
        exit 1
    fi

    if [ -L "$RAW_TARGET" ]; then
        echo "Warning: $RAW_TARGET is already a symbolic link."
        exit 0
    fi

    if [ ! -e "$RAW_TARGET" ]; then
        echo "Error: $RAW_TARGET does not exist."
        exit 1
    fi

    TARGET=$(realpath "$RAW_TARGET")
    if [[ "$TARGET" != "$HOME"* ]]; then
        echo "Error: Target must be within your home directory ($HOME)."
        exit 1
    fi

    REL_PATH=$(get_relative_home_path "$RAW_TARGET")
    CLOUD_DEST="$MOSY_PROFILE_DIR/$REL_PATH"

    echo "Syncing $REL_PATH..."

    if [ -d "$TARGET" ]; then
        # Sync directory granularly without modifying or deleting local ignored files
        mkdir -p "$CLOUD_DEST"
        
        while IFS= read -r -d '' file; do
            local rel_file="${file#$TARGET/}"
            local cloud_file="$CLOUD_DEST/$rel_file"

            if is_ignored "$file"; then
                log_debug "Ignoring local file: $rel_file"
                continue
            fi

            if [ -L "$file" ]; then
                continue
            fi

            mkdir -p "$(dirname "$cloud_file")"
            if [ -e "$cloud_file" ]; then
                echo "Warning: Cloud version already exists at $rel_file. Backing up local copy."
                mosy_backup "$file" || continue
            else
                mv "$file" "$cloud_file" || continue
            fi
            ln -s "$cloud_file" "$file"
        done < <(find "$TARGET" -type f -print0)
    else
        local CLOUD_DEST_DIR
        CLOUD_DEST_DIR=$(dirname "$CLOUD_DEST")
        mkdir -p "$CLOUD_DEST_DIR"

        if [ -e "$CLOUD_DEST" ]; then
            echo "Warning: A version already exists in the cloud at $REL_PATH. Backing up local copy."
            mosy_backup "$TARGET" || exit 1
        else
            mv "$TARGET" "$CLOUD_DEST" || exit 1
        fi
        ln -s "$CLOUD_DEST" "$TARGET"
    fi

    touch "$MOSY_MAP_FILE"
    update_map_remove_entry "$REL_PATH"
    echo "$REL_PATH|$REL_PATH|$TAGS|$ITEM_GROUPS" >> "$MOSY_MAP_FILE"

    echo "Success! $REL_PATH is now synced."
}
