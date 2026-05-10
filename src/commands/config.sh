#!/bin/bash

# Metadata definition
# Format: KEY | CATEGORY | DESCRIPTION | VALIDATION_TYPE | DEFAULT
_config_metadata() {
    cat <<EOF
MOSY_REMOTE_NAME|Remote|The rclone remote name (e.g., gdrive:).|string|
MOSY_MOUNT_POINT|Remote|Local mount path.|path|${HOME}/GoogleDrive
MOSY_VFS_CACHE|Remote|rclone VFS cache mode (e.g., writes, full, off).|string|writes
MOSY_CLOUD_DIR|Remote|Root folder inside mount.|path|\${MOSY_MOUNT_POINT}/mosy_vault
MOSY_BACKUP_EXT|Behavior|Extension for conflict backups.|string|.bak
MOSY_LOG_LEVEL|Behavior|Verbosity: INFO, DEBUG, SILENT.|list:INFO,DEBUG,SILENT|INFO
MOSY_DRY_RUN|Behavior|If true, simulate actions without changes.|bool|false
EOF
}

cmd_config() {
    if [[ -z "$1" ]]; then
        _config_list
    elif [[ "$1" == "set" ]]; then
        shift
        _config_set "$@"
    else
        log_error "Usage: mosy config [set <KEY> <VALUE>]"
        exit 1
    fi
}

_config_list() {
    log_info "--- Mosy Configuration ---"
    local last_cat=""
    while IFS="|" read -r key cat desc val_type default; do
        if [[ "$cat" != "$last_cat" ]]; then
            echo -e "\n[$cat]"
            last_cat="$cat"
        fi
        local current_val="${!key}"
        local default_str=""
        if [[ -n "$default" ]]; then
            default_str=" (Default: $default)"
        fi
        printf "%-20s \"%s\"    # %s%s\n" "$key" "$current_val" "$desc" "$default_str"
    done < <(_config_metadata)
}

_config_validate() {
    local type="$1"
    local value="$2"

    case "$type" in
        bool)
            if [[ "$value" == "true" || "$value" == "false" ]]; then
                return 0
            fi
            ;;
        list:*)
            local list="${type#list:}"
            IFS=',' read -ra options <<< "$list"
            for opt in "${options[@]}"; do
                if [[ "$opt" == "$value" ]]; then
                    return 0
                fi
            done
            ;;
        string|path)
            return 0
            ;;
    esac
    return 1
}

_config_set() {
    local target_key="$1"
    local target_val="$2"

    if [[ -z "$target_key" || -z "$target_val" ]]; then
        log_error "Usage: mosy config set <KEY> <VALUE>"
        exit 1
    fi

    local found=0
    local val_type=""
    while IFS="|" read -r key cat desc type default; do
        if [[ "$key" == "$target_key" ]]; then
            found=1
            val_type="$type"
            break
        fi
    done < <(_config_metadata)

    if [[ $found -eq 0 ]]; then
        log_error "Error: Unknown configuration key '$target_key'"
        exit 1
    fi

    if ! _config_validate "$val_type" "$target_val"; then
        log_error "Error: Invalid value for $target_key (type: $val_type)"
        exit 1
    fi

    local config_file="${HOME}/.config/mosy/config"
    mkdir -p "$(dirname "$config_file")"
    touch "$config_file"

    # Create a temp file to store the new config
    local tmp_file=$(mktemp)
    trap 'rm -f "$tmp_file"' EXIT
    
    # Filter out the existing key and append the new one
    grep -v "^${target_key}=" "$config_file" > "$tmp_file" || true
    
    # Escape backslashes, double quotes, dollar signs, and backticks
    local escaped_val="${target_val//\\/\\\\}"
    escaped_val="${escaped_val//\"/\\\"}"
    escaped_val="${escaped_val//\$/\\\$}"
    escaped_val="${escaped_val//\`/\\\`}"
    
    printf "%s=\"%s\"\n" "$target_key" "$escaped_val" >> "$tmp_file"
    
    # Move the temp file back to the config file
    mv "$tmp_file" "$config_file"

    log_info "Configured ${target_key}=\"${target_val}\""
}
