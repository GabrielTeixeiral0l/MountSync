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
    "*.sqlite-wal"
    "*.sqlite-shm"
    "*.db-wal"
    "*.db-shm"
    "*.db-journal"
    "*.sock"
    "*.lock"
)

_read_ignore_file() {
    local file="$1"
    [ -f "$file" ] || return 0
    while read -r line || [ -n "$line" ]; do
        # trim leading/trailing whitespace with native bash parameter expansion
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
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

    local curr_dir
    curr_dir=$(dirname "$target_path")
    while [[ -n "$curr_dir" && "$curr_dir" == "$HOME"* && "$curr_dir" != "/" ]]; do
        if [ -f "$curr_dir/.mosyignore" ]; then
            _read_ignore_file "$curr_dir/.mosyignore"
        fi
        [ "$curr_dir" = "$HOME" ] && break
        curr_dir=$(dirname "$curr_dir")
    done

    for pattern in "${patterns[@]}"; do
        local clean_pat="${pattern%/}"
        if [[ "$base_name" == $clean_pat || "$base_name" == $pattern || "$target_path" == *"/$clean_pat/"* || "$target_path" == *"/$clean_pat" || "$target_path" == *"/$pattern" || "$target_path" == *"/$pattern/"* ]]; then
            return 0
        fi
    done

    return 1
}
