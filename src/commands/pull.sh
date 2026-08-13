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
    local MOSY_FILTER_TAG=""
    local MOSY_FILTER_GROUP=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --tag|-t)
                MOSY_FILTER_TAG="$2"
                shift 2
                ;;
            --group|-g)
                MOSY_FILTER_GROUP="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    export MOSY_FILTER_TAG
    export MOSY_FILTER_GROUP
    foreach_mapping _pull_link
}
