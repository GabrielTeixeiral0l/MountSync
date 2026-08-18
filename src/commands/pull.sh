#!/bin/bash

_pull_link() {
    local local_rel=$1
    local cloud_rel=$2

    local LOCAL_TARGET="$HOME/$local_rel"
    local CLOUD_SOURCE="$MOSY_PROFILE_DIR/$cloud_rel"

    if is_ignored "$cloud_rel"; then
        echo "Skipping ignored item: $cloud_rel"
        return 0
    fi

    if [ ! -e "$CLOUD_SOURCE" ]; then
        return 0
    fi

    if [ -d "$CLOUD_SOURCE" ]; then
        # Link missing files in directory without altering existing local files
        mkdir -p "$LOCAL_TARGET"
        while IFS= read -r -d '' cfile; do
            local rel_cfile="${cfile#$CLOUD_SOURCE/}"
            local local_dest="$LOCAL_TARGET/$rel_cfile"

            if is_ignored "$cfile" || is_ignored "$local_dest"; then
                continue
            fi

            if [ ! -e "$local_dest" ] && [ ! -L "$local_dest" ]; then
                mkdir -p "$(dirname "$local_dest")"
                ln -s "$cfile" "$local_dest"
                echo "Linked $local_rel/$rel_cfile"
            fi
        done < <(find "$CLOUD_SOURCE" -type f -print0)
    else
        if [ ! -e "$LOCAL_TARGET" ] && [ ! -L "$LOCAL_TARGET" ]; then
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
