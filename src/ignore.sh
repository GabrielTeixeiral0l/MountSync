#!/bin/bash

# Default ignore patterns if no file exists
DEFAULT_IGNORE_PATTERNS=(
    ".git"
    ".git/*"
    "node_modules"
    "node_modules/*"
    ".DS_Store"
    "*.tmp"
    "*.log"
)

_read_ignore_file() {
    local file="$1"
    [ -f "$file" ] || return 0
    while read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        patterns+=("$line")
    done < "$file"
}

is_ignored() {
    local target_path="$1"
    local base_name
    base_name=$(basename "$target_path")

    local patterns=()
    local global_ignore="${HOME}/.config/mosy/.mosyignore"

    if [ -f "$global_ignore" ]; then
        _read_ignore_file "$global_ignore"
    else
        patterns=("${DEFAULT_IGNORE_PATTERNS[@]}")
    fi

    if [ -d "$target_path" ] && [ -f "$target_path/.mosyignore" ]; then
        _read_ignore_file "$target_path/.mosyignore"
    fi

    for pattern in "${patterns[@]}"; do
        local clean_pat="${pattern%/}"
        if [[ "$base_name" == $clean_pat || "$target_path" == *"/$clean_pat"* || "$target_path" == *"/$pattern"* ]]; then
            return 0
        fi
    done

    return 1
}

clean_ignored_files() {
    local dir="$1"
    [ ! -d "$dir" ] && return 0

    find "$dir" -mindepth 1 | while read -r item; do
        if is_ignored "$item"; then
            log_info "Expunging ignored item: $item"
            rm -rf "$item"
        fi
    done
}
