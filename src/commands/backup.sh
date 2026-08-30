#!/bin/bash

_create_item_snapshot() {
    local rel_path="$1"
    local local_path="${HOME}/${rel_path}"

    if [ ! -e "$local_path" ] && [ ! -L "$local_path" ]; then
        return 1
    fi

    local backup_path
    backup_path=$(generate_backup_path "$local_path")

    if [ -L "$local_path" ]; then
        local target
        target=$(readlink -f "$local_path" 2>/dev/null || true)
        if [ -n "$target" ] && [ -e "$target" ]; then
            if [ -d "$target" ]; then
                cp -r "$target" "$backup_path"
            else
                cp "$target" "$backup_path"
            fi
        else
            return 1
        fi
    else
        if [ -d "$local_path" ]; then
            cp -r "$local_path" "$backup_path"
        else
            cp "$local_path" "$backup_path"
        fi
    fi

    echo "$backup_path"
    return 0
}

cmd_backup() {
    local TARGET_PATH=""
    parse_filter_flags "$@"

    while [ $# -gt 0 ]; do
        case "$1" in
            --tag|-t|--group|-g)
                shift 2
                ;;
            *)
                [ -z "$TARGET_PATH" ] && TARGET_PATH="$1"
                shift
                ;;
        esac
    done

    if [ -n "$TARGET_PATH" ]; then
        local rel_path
        rel_path=$(get_relative_home_path "$TARGET_PATH")
        local local_path="${HOME}/${rel_path}"

        if [ ! -e "$local_path" ] && [ ! -L "$local_path" ]; then
            echo "Error: Target ~/$rel_path does not exist." >&2
            exit 1
        fi

        local backup_file
        backup_file=$(_create_item_snapshot "$rel_path")
        if [ $? -eq 0 ] && [ -n "$backup_file" ]; then
            echo "Success! Created safety backup for ~/$rel_path ($(basename "$backup_file"))."
        else
            echo "Error: Failed to create safety backup for ~/$rel_path." >&2
            exit 1
        fi
    else
        local count=0
        local failed=0

        _batch_backup_item() {
            local l_rel="$1"
            local backup_file
            backup_file=$(_create_item_snapshot "$l_rel")
            if [ $? -eq 0 ] && [ -n "$backup_file" ]; then
                echo "  [OK] ~/$l_rel -> $(basename "$backup_file")"
                ((count++))
            else
                echo "  [SKIP] ~/$l_rel (file missing or inaccessible)"
                ((failed++))
            fi
        }

        echo "Creating safety snapshots for managed dotfiles..."
        foreach_mapping _batch_backup_item

        if [ $count -eq 0 ] && [ $failed -eq 0 ]; then
            echo "No managed dotfiles found matching criteria."
        else
            echo "Done! Backed up $count item(s) successfully."
        fi
    fi
}

cmd_snapshot() {
    cmd_backup "$@"
}
