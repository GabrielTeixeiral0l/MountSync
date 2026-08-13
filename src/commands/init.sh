#!/bin/bash

_init_link() {
    local local_rel=$1
    local cloud_rel=$2
    local HOME_DIR="${HOME}"

    LOCAL_TARGET="$HOME_DIR/$local_rel"
    CLOUD_SOURCE="$MOSY_CLOUD_DIR/$cloud_rel"

    if [ -L "$LOCAL_TARGET" ]; then
        echo "Removing old link at $local_rel..."
        rm "$LOCAL_TARGET"
    elif [ -e "$LOCAL_TARGET" ]; then
        echo "Warning: $LOCAL_TARGET already exists locally. Moving to backup..."
        mv "$LOCAL_TARGET" "${LOCAL_TARGET}.backup_$(date +%s)"
    fi

    echo "Creating link for $local_rel..."
    mkdir -p "$(dirname "$LOCAL_TARGET")"
    ln -s "$CLOUD_SOURCE" "$LOCAL_TARGET"
}

cmd_init() {
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

    if [ ! -f "$MOSY_MAP_FILE" ]; then
        echo "Warning: No sync map found at $MOSY_MAP_FILE. Nothing to link."
        exit 0
    fi

    echo "Configuring PC from sync map..."
    foreach_mapping _init_link

    HOME_DIR="${HOME}"
    BASHRC="$HOME_DIR/.bashrc"
    BRIDGE_CMD="source $MOSY_CLOUD_DIR/.bashrc_cloud"

    if ! grep -q "$BRIDGE_CMD" "$BASHRC" 2>/dev/null; then
        echo "Adding bridge to your local .bashrc..."
        echo -e "\n# MountSync - Bridge to cloud settings\nif [ -f \"$MOSY_CLOUD_DIR/.bashrc_cloud\" ]; then\n    $BRIDGE_CMD\nfi" >> "$BASHRC"
    fi

    echo "PC configured successfully! Restart your terminal or run 'source ~/.bashrc'."
}
