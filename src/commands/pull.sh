#!/bin/bash

_pull_link() {
    local local_rel=$1
    local cloud_rel=$2

    local LOCAL_TARGET="$HOME/$local_rel"
    local CLOUD_SOURCE="$MOSY_PROFILE_DIR/$cloud_rel"

    if [ ! -e "$LOCAL_TARGET" ] && [ ! -L "$LOCAL_TARGET" ]; then
        if is_ignored "$cloud_rel"; then
            echo "Skipping ignored item: $cloud_rel"
            return 0
        fi
        if [ -e "$CLOUD_SOURCE" ]; then
            mkdir -p "$(dirname "$LOCAL_TARGET")"
            ln -s "$CLOUD_SOURCE" "$LOCAL_TARGET"
            echo "Linked $local_rel"
        fi
    fi
}

cmd_pull() {
    check_mount
    parse_filter_flags "$@"
    foreach_mapping _pull_link
}
