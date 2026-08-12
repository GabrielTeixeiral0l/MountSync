#!/bin/bash

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
    
    echo -e "\n[Remote]"
    printf "%-20s \"%s\"    # The rclone remote name (e.g., gdrive:).\n" "MOSY_REMOTE_NAME" "$MOSY_REMOTE_NAME"
    printf "%-20s \"%s\"    # Local mount path. (Default: ${HOME}/GoogleDrive)\n" "MOSY_MOUNT_POINT" "$MOSY_MOUNT_POINT"
    printf "%-20s \"%s\"    # rclone VFS cache mode (e.g., writes, full, off). (Default: writes)\n" "MOSY_VFS_CACHE" "$MOSY_VFS_CACHE"
    printf "%-20s \"%s\"    # Root folder inside mount. (Default: \${MOSY_MOUNT_POINT}/mosy_vault)\n" "MOSY_CLOUD_DIR" "$MOSY_CLOUD_DIR"
    
    echo -e "\n[Behavior]"
    printf "%-20s \"%s\"    # Extension for conflict backups. (Default: .bak)\n" "MOSY_BACKUP_EXT" "$MOSY_BACKUP_EXT"
    printf "%-20s \"%s\"    # Verbosity: INFO, DEBUG, SILENT (Default: INFO)\n" "MOSY_LOG_LEVEL" "$MOSY_LOG_LEVEL"
    printf "%-20s \"%s\"    # If true, simulate actions without changes. (Default: false)\n" "MOSY_DRY_RUN" "$MOSY_DRY_RUN"
}

_config_set() {
    local key="$1"
    local val="$2"

    if [[ -z "$key" || -z "$val" ]]; then
        log_error "Usage: mosy config set <KEY> <VALUE>"
        exit 1
    fi

    # Validate key
    case "$key" in
        MOSY_REMOTE_NAME|MOSY_MOUNT_POINT|MOSY_VFS_CACHE|MOSY_CLOUD_DIR|MOSY_BACKUP_EXT|MOSY_LOG_LEVEL|MOSY_DRY_RUN)
            ;;
        *)
            log_error "Error: Unknown configuration key '$key'"
            exit 1
            ;;
    esac

    # Validate value
    case "$key" in
        MOSY_LOG_LEVEL)
            if [[ "$val" != "INFO" && "$val" != "DEBUG" && "$val" != "SILENT" ]]; then
                log_error "Error: Invalid value for $key (expected INFO, DEBUG, SILENT)"
                exit 1
            fi
            ;;
        MOSY_DRY_RUN)
            if [[ "$val" != "true" && "$val" != "false" ]]; then
                log_error "Error: Invalid value for $key (expected true or false)"
                exit 1
            fi
            ;;
    esac

    local config_file="${HOME}/.config/mosy/config"
    mkdir -p "$(dirname "$config_file")"
    touch "$config_file"

    # Escape double quotes and backslashes for bash assignment
    local escaped_val="${val//\\/\\\\}"
    escaped_val="${escaped_val//\"/\\\"}"

    if grep -q "^${key}=" "$config_file"; then
        sed -i "s|^${key}=.*|${key}=\"${escaped_val}\"|" "$config_file"
    else
        echo "${key}=\"${escaped_val}\"" >> "$config_file"
    fi

    log_info "Configured ${key}=\"${val}\""
}
