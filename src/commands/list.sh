#!/bin/bash

list_callback() {
    local local_rel=$1
    local cloud_rel=$2
    local tags=$3
    local groups=$4

    local meta=""
    [ -n "$tags" ] && meta=" [tags: $tags]"
    [ -n "$groups" ] && meta="$meta [groups: $groups]"

    echo "- $local_rel$meta"
}

cmd_list() {
    parse_filter_flags "$@"

    if [ ! -f "$MOSY_MAP_FILE" ]; then
        echo "No items are currently being managed by MountSync."
        return 0
    fi

    echo "Items managed by MountSync:"
    foreach_mapping list_callback
}
