load_settings() {
    local config_file="${HOME}/.config/mosy/config"
    
    # Save environment variables before sourcing config file
    local env_remote="${MOSY_REMOTE_NAME+x}" && local env_remote_val="$MOSY_REMOTE_NAME"
    local env_mount="${MOSY_MOUNT_POINT+x}" && local env_mount_val="$MOSY_MOUNT_POINT"
    local env_vfs="${MOSY_VFS_CACHE+x}" && local env_vfs_val="$MOSY_VFS_CACHE"
    local env_cloud="${MOSY_CLOUD_DIR+x}" && local env_cloud_val="$MOSY_CLOUD_DIR"
    local env_backup="${MOSY_BACKUP_EXT+x}" && local env_backup_val="$MOSY_BACKUP_EXT"
    local env_log="${MOSY_LOG_LEVEL+x}" && local env_log_val="$MOSY_LOG_LEVEL"
    local env_dry="${MOSY_DRY_RUN+x}" && local env_dry_val="$MOSY_DRY_RUN"

    [ -f "$config_file" ] && . "$config_file"

    [ -n "$env_remote" ] && export MOSY_REMOTE_NAME="$env_remote_val"
    [ -n "$env_mount" ] && export MOSY_MOUNT_POINT="$env_mount_val"
    [ -n "$env_vfs" ] && export MOSY_VFS_CACHE="$env_vfs_val"
    [ -n "$env_cloud" ] && export MOSY_CLOUD_DIR="$env_cloud_val"
    [ -n "$env_backup" ] && export MOSY_BACKUP_EXT="$env_backup_val"
    [ -n "$env_log" ] && export MOSY_LOG_LEVEL="$env_log_val"
    [ -n "$env_dry" ] && export MOSY_DRY_RUN="$env_dry_val"

    export MOSY_REMOTE_NAME="${MOSY_REMOTE_NAME:-}"
    export MOSY_MOUNT_POINT="${MOSY_MOUNT_POINT:-${HOME}/GoogleDrive}"
    export MOSY_VFS_CACHE="${MOSY_VFS_CACHE:-writes}"
    export MOSY_CLOUD_DIR="${MOSY_CLOUD_DIR:-${MOSY_MOUNT_POINT}/mosy_vault}"
    export MOSY_BACKUP_EXT="${MOSY_BACKUP_EXT:-.bak}"
    export MOSY_LOG_LEVEL="${MOSY_LOG_LEVEL:-INFO}"
    export MOSY_DRY_RUN="${MOSY_DRY_RUN:-false}"

    if [ -z "$MOSY_REMOTE_NAME" ]; then
        echo "Error: MOSY_REMOTE_NAME is missing" >&2
        return 1
    fi
    export MOSY_MAP_FILE="$MOSY_CLOUD_DIR/sync-map.conf"
}

# Load settings automatically when sourced
if ! load_settings; then
    exit 1
fi

is_mounted() {
    local target="${1:-$MOSY_MOUNT_POINT}"
    if command -v mountpoint >/dev/null 2>&1; then
        mountpoint -q "$target"
        return $?
    fi
    mount | grep -qE "[[:space:]]on[[:space:]]${target%/}/?[[:space:]]"
}

check_mount() {
    if ! is_mounted; then
        echo "Error: Cloud drive is not mounted at $MOSY_MOUNT_POINT"
        echo "Try: systemctl --user start mosy-mount.service (if installed)"
        exit 1
    fi
}

foreach_mapping() {
    local callback=$1
    if [ ! -f "$MOSY_MAP_FILE" ]; then
        return 0
    fi

    # Read map into memory first to avoid issues if the callback modifies the file
    local map_entries=()
    while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] && map_entries+=("$line")
    done < "$MOSY_MAP_FILE"

    for entry in "${map_entries[@]}"; do
        IFS="|" read -r local_rel cloud_rel <<< "$entry"
        if [ -z "$local_rel" ]; then continue; fi
        "$callback" "$local_rel" "$cloud_rel"
    done
}

log_info() {
    if [[ "$MOSY_LOG_LEVEL" == "INFO" || "$MOSY_LOG_LEVEL" == "DEBUG" ]]; then
        echo "$@"
    fi
}

mosy_backup() {
    local target="$1"
    if [ -e "$target" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_path="${target}${MOSY_BACKUP_EXT}_${timestamp}"
        log_info "Backing up $target to $(basename "$backup_path")..."
        mv "$target" "$backup_path"
    fi
}

log_debug() {
    if [[ "$MOSY_LOG_LEVEL" == "DEBUG" ]]; then
        echo "[DEBUG] $@"
    fi
}

get_relative_home_path() {
    local target="$1"
    local abs_target
    abs_target=$(realpath -s "$target" 2>/dev/null || realpath "$target")
    echo "${abs_target#$HOME/}"
}

log_error() {
    echo "$@" >&2
}
