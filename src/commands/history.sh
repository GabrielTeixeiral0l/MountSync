_extract_snapshot_timestamp() {
    local snap_name="$1"
    if [[ "$snap_name" =~ \.(bak|backup)_([0-9_]+)$ ]]; then
        echo "${BASH_REMATCH[2]}"
    elif [[ "$snap_name" =~ \.(bak|backup)$ ]]; then
        echo "legacy"
    else
        echo "${snap_name##*_}"
    fi
}

# Format timestamp string YYYYMMDD_HHMMSS or Unix epoch timestamp into human readable format
_format_snapshot_datetime() {
    local raw_ts="$1"
    if [[ "$raw_ts" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})$ ]]; then
        echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
    elif [[ "$raw_ts" =~ ^[0-9]{9,12}$ ]]; then
        date -d @"$raw_ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$raw_ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$raw_ts"
    else
        echo "$raw_ts"
    fi
}

_format_bytes() {
    local bytes="$1"
    if [ "$bytes" -ge 1048576 ]; then
        echo "$(( bytes / 1048576 )) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(( bytes / 1024 )) KB"
    else
        echo "${bytes} B"
    fi
}

_get_item_snapshots() {
    local local_rel="$1"
    local local_path="${HOME}/${local_rel}"
    local parent_dir
    parent_dir=$(dirname "$local_path")
    local base_name
    base_name=$(basename "$local_path")

    [ -d "$parent_dir" ] || return 0

    find "$parent_dir" -maxdepth 1 \( -name "${base_name}.bak*" -o -name "${base_name}.backup*" -o -name "${base_name}${MOSY_BACKUP_EXT}*" \) 2>/dev/null | sort -r
}

cmd_history() {
    local TARGET_PATH=""
    local JSON_MODE=false

    parse_filter_flags "$@"

    while [ $# -gt 0 ]; do
        case "$1" in
            --json|-j)
                JSON_MODE=true
                shift
                ;;
            --tag|-t|--group|-g)
                shift 2
                ;;
            *)
                [ -z "$TARGET_PATH" ] && TARGET_PATH="$1"
                shift
                ;;
        esac
    done

    local items_to_check=()
    if [ -n "$TARGET_PATH" ]; then
        local rel_path
        rel_path=$(get_relative_home_path "$TARGET_PATH")
        items_to_check+=("$rel_path")
    else
        _collect_history_item() {
            local l_rel="$1"
            items_to_check+=("$l_rel")
        }
        foreach_mapping _collect_history_item
    fi

    if [ "$JSON_MODE" = true ]; then
        local json_records=()
        for item in "${items_to_check[@]}"; do
            while IFS= read -r snap_file; do
                [ -z "$snap_file" ] && continue
                local snap_name
                snap_name=$(basename "$snap_file")
                local raw_ts
                raw_ts=$(_extract_snapshot_timestamp "$snap_name")
                local dt
                dt=$(_format_snapshot_datetime "$raw_ts")
                local size=0
                if [ -e "$snap_file" ]; then
                    size=$(stat -c%s "$snap_file" 2>/dev/null || stat -f%z "$snap_file" 2>/dev/null || echo 0)
                fi
                json_records+=("{\"item\":\"$item\",\"timestamp\":\"$raw_ts\",\"datetime\":\"$dt\",\"size_bytes\":$size,\"backup_path\":\"$snap_file\"}")
            done < <(_get_item_snapshots "$item")
        done

        echo -n "["
        local first=true
        for record in "${json_records[@]}"; do
            if [ "$first" = true ]; then
                echo ""
                echo -n "  $record"
                first=false
            else
                echo ","
                echo -n "  $record"
            fi
        done
        if [ "$first" = false ]; then
            echo ""
        fi
        echo "]"
    else
        local total_snapshots=0
        for item in "${items_to_check[@]}"; do
            local snaps=()
            while IFS= read -r snap_file; do
                [ -n "$snap_file" ] && snaps+=("$snap_file")
            done < <(_get_item_snapshots "$item")

            if [ ${#snaps[@]} -eq 0 ]; then
                if [ -n "$TARGET_PATH" ]; then
                    echo "No backup history found for ~/$item."
                fi
                continue
            fi

            echo "Backup History for ~/$item:"
            local idx=1
            for snap in "${snaps[@]}"; do
                local snap_name
                snap_name=$(basename "$snap")
                local raw_ts
                raw_ts=$(_extract_snapshot_timestamp "$snap_name")
                local dt
                dt=$(_format_snapshot_datetime "$raw_ts")
                local size=0
                if [ -e "$snap" ]; then
                    size=$(stat -c%s "$snap" 2>/dev/null || stat -f%z "$snap" 2>/dev/null || echo 0)
                fi
                local size_fmt
                size_fmt=$(_format_bytes "$size")
                echo "  [$idx] $dt ($size_fmt)  $snap"
                ((idx++))
                ((total_snapshots++))
            done
            echo ""
        done

        if [ $total_snapshots -eq 0 ] && [ -z "$TARGET_PATH" ]; then
            echo "No backup snapshots found for any managed items."
        fi
    fi
}
