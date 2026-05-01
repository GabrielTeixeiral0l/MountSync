#!/bin/bash

_pull_link() {
    local local_rel=$1
    local cloud_rel=$2

    LOCAL_TARGET="$HOME/$local_rel"
    CLOUD_SOURCE="$MOSY_CLOUD_DIR/$cloud_rel"

    if [ ! -e "$LOCAL_TARGET" ] && [ ! -L "$LOCAL_TARGET" ]; then
        if [ -e "$CLOUD_SOURCE" ]; then
            mkdir -p "$(dirname "$LOCAL_TARGET")"
            ln -s "$CLOUD_SOURCE" "$LOCAL_TARGET"
            echo "Linked $local_rel"
        fi
    fi
}

cmd_pull() {
    check_mount
    foreach_mapping _pull_link
}
