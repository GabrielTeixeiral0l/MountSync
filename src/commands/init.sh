#!/bin/bash

_init_link() {
    local local_rel=$1
    local cloud_rel=$2
    local HOME_DIR="${HOME}"

    LOCAL_TARGET="$HOME/$local_rel"
    CLOUD_SOURCE="$MOSY_PROFILE_DIR/$cloud_rel"

    if is_ignored "$cloud_rel"; then
        echo "Skipping ignored item: $cloud_rel"
        return 0
    fi

    if [ -L "$LOCAL_TARGET" ]; then
        echo "Removing old link at $local_rel..."
        rm "$LOCAL_TARGET"
    elif [ -e "$LOCAL_TARGET" ]; then
        echo "Warning: $LOCAL_TARGET already exists locally. Moving to backup..."
        mosy_backup "$LOCAL_TARGET"
    fi

    echo "Creating link for $local_rel..."
    mkdir -p "$(dirname "$LOCAL_TARGET")"
    ln -s "$CLOUD_SOURCE" "$LOCAL_TARGET"
}

cmd_init() {
    check_mount
    parse_filter_flags "$@"

    if [ ! -f "$MOSY_MAP_FILE" ]; then
        echo "Warning: No sync map found at $MOSY_MAP_FILE. Nothing to link."
        exit 0
    fi

    echo "Configuring PC from sync map..."
    foreach_mapping _init_link

    echo "PC configured successfully!"
}
