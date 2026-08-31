#!/bin/bash

cmd_which() {
    local TARGET_PATH=""
    local JSON_OUTPUT=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --json|-j)
                JSON_OUTPUT=true
                shift
                ;;
            *)
                [ -z "$TARGET_PATH" ] && TARGET_PATH="$1"
                shift
                ;;
        esac
    done

    if [ -z "$TARGET_PATH" ]; then
        echo "Error: Path argument is required." >&2
        echo "Usage: mosy [-p <profile>] which <path> [--json]" >&2
        exit 1
    fi

    local target_rel
    target_rel=$(get_relative_home_path "$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH")
    local local_path="${HOME}/${target_rel}"

    local is_managed=false
    local matched_root=""
    local matched_cloud_rel=""
    local item_tags=""
    local item_groups=""

    _check_mapping_match() {
        local l_rel="$1"
        local c_rel="$2"
        local tags="$3"
        local groups="$4"

        if [ "$l_rel" = "$target_rel" ]; then
            is_managed=true
            matched_root="$l_rel"
            matched_cloud_rel="$c_rel"
            item_tags="$tags"
            item_groups="$groups"
        elif [[ "$target_rel" == "$l_rel/"* ]]; then
            # Target is nested inside a managed directory
            is_managed=true
            matched_root="$l_rel"
            local sub_rel="${target_rel#$l_rel/}"
            matched_cloud_rel="${c_rel}/${sub_rel}"
            item_tags="$tags"
            item_groups="$groups"
        fi
    }
    foreach_mapping _check_mapping_match

    local display_path="~/${target_rel}"
    [[ "$target_rel" == /* ]] && display_path="$target_rel"

    if [ "$is_managed" = false ]; then
        if [ "$JSON_OUTPUT" = true ]; then
            printf '{"path":"%s","absolute_path":"%s","managed":false,"profile":"%s","status":"NOT_MANAGED"}\n' \
                "$display_path" "$local_path" "$MOSY_PROFILE"
        else
            if [ "$MOSY_PROFILE" = "default" ]; then
                echo "$display_path is NOT managed by MountSync."
            else
                echo "$display_path is NOT managed in profile '${MOSY_PROFILE}'."
            fi
        fi
        exit 1
    fi

    local cloud_target="${MOSY_CLOUD_DIR}/${matched_cloud_rel}"
    local link_status="UNKNOWN"
    local status_desc=""

    if [ -L "$local_path" ]; then
        local resolved_target
        resolved_target=$(readlink -f "$local_path" 2>/dev/null || true)
        if [ -z "$resolved_target" ] || [ ! -e "$resolved_target" ]; then
            link_status="BROKEN_LINK"
            status_desc="Broken Link (target missing in vault)"
        elif [[ "$resolved_target" == "$MOSY_CLOUD_DIR"* ]]; then
            link_status="OK"
            status_desc="OK (Active Symlink)"
        else
            link_status="MISCONFIGURED_LINK"
            status_desc="Misconfigured Link (points outside vault)"
        fi
    elif [ -e "$local_path" ]; then
        link_status="LOCAL_PHYSICAL"
        status_desc="Local Physical File (Unlinked)"
    else
        link_status="MISSING_LOCAL"
        status_desc="Missing Local File"
    fi

    # Snapshot count
    local snapshot_count=0
    local snap_dir
    snap_dir=$(dirname "$local_path")
    local snap_base
    snap_base=$(basename "$local_path")
    if [ -d "$snap_dir" ]; then
        snapshot_count=$(find "$snap_dir" -maxdepth 1 \( -name "${snap_base}.bak_*" -o -name "${snap_base}.backup_*" \) 2>/dev/null | wc -l)
    fi

    [ -z "$item_tags" ] && item_tags="none"
    [ -z "$item_groups" ] && item_groups="none"

    if [ "$JSON_OUTPUT" = true ]; then
        local json_tags="[]"
        if [ "$item_tags" != "none" ]; then
            json_tags=$(echo "$item_tags" | awk -F',' '{printf "["; for(i=1;i<=NF;i++){printf "\"%s\"%s", $i, (i<NF?", ":"")}; printf "]"}')
        fi
        local json_groups="[]"
        if [ "$item_groups" != "none" ]; then
            json_groups=$(echo "$item_groups" | awk -F',' '{printf "["; for(i=1;i<=NF;i++){printf "\"%s\"%s", $i, (i<NF?", ":"")}; printf "]"}')
        fi

        printf '{"path":"%s","absolute_path":"%s","managed":true,"profile":"%s","matched_root":"~/%s","cloud_target":"%s","status":"%s","tags":%s,"groups":%s,"snapshot_count":%d}\n' \
            "$display_path" "$local_path" "$MOSY_PROFILE" "$matched_root" "$cloud_target" "$link_status" "$json_tags" "$json_groups" "$snapshot_count"
    else
        echo "Item:         $display_path"
        echo "Managed:      Yes (Profile: ${MOSY_PROFILE})"
        echo "Root Entry:   ~/$matched_root"
        echo "Cloud Target: $cloud_target"
        echo "Link Status:  $status_desc"
        echo "Tags:         $item_tags"
        echo "Groups:       $item_groups"
        echo "Snapshots:    $snapshot_count in history"
    fi

    if [ "$link_status" = "OK" ]; then
        exit 0
    else
        exit 1
    fi
}
