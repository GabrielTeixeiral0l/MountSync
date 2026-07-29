#!/bin/bash

list_callback() {
    local local_rel=$1
    echo "- $local_rel"
}

cmd_list() {
    if [ ! -f "$MOSY_MAP_FILE" ]; then
        echo "No items are currently being managed by MountSync."
        return 0
    fi

    echo "Items managed by MountSync:"
    foreach_mapping list_callback
}
