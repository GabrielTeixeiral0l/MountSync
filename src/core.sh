load_settings() {
    local config_file="${HOME}/.config/mosy/config"
    
    # Save env vars to preserve precedence
    local env_MOSY_REMOTE_NAME="${MOSY_REMOTE_NAME:-}"
    local env_MOSY_MOUNT_POINT="${MOSY_MOUNT_POINT:-}"
    local env_MOSY_VFS_CACHE="${MOSY_VFS_CACHE:-}"
    local env_MOSY_CLOUD_DIR="${MOSY_CLOUD_DIR:-}"
    local env_MOSY_BACKUP_EXT="${MOSY_BACKUP_EXT:-}"
    local env_MOSY_LOG_LEVEL="${MOSY_LOG_LEVEL:-}"
    local env_MOSY_DRY_RUN="${MOSY_DRY_RUN:-}"

    if [ -f "$config_file" ]; then
        . "$config_file"
    fi

    # Restore env vars
    [ -n "$env_MOSY_REMOTE_NAME" ] && MOSY_REMOTE_NAME="$env_MOSY_REMOTE_NAME"
    [ -n "$env_MOSY_MOUNT_POINT" ]  && MOSY_MOUNT_POINT="$env_MOSY_MOUNT_POINT"
    [ -n "$env_MOSY_VFS_CACHE" ]    && MOSY_VFS_CACHE="$env_MOSY_VFS_CACHE"
    [ -n "$env_MOSY_CLOUD_DIR" ]    && MOSY_CLOUD_DIR="$env_MOSY_CLOUD_DIR"
    [ -n "$env_MOSY_BACKUP_EXT" ]   && MOSY_BACKUP_EXT="$env_MOSY_BACKUP_EXT"
    [ -n "$env_MOSY_LOG_LEVEL" ]    && MOSY_LOG_LEVEL="$env_MOSY_LOG_LEVEL"
    [ -n "$env_MOSY_DRY_RUN" ]      && MOSY_DRY_RUN="$env_MOSY_DRY_RUN"

    # Set defaults
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
    # 1. Use mountpoint command if available (most reliable)
    if command -v mountpoint >/dev/null 2>&1; then
        mountpoint -q "$MOSY_MOUNT_POINT"
        return $?
    fi

    # 2. Fallback: check mount output with precision
    # We look for the mount point followed by a space to avoid partial matches
    mount | grep -qE "[[:space:]]on[[:space:]]${MOSY_MOUNT_POINT%/}/?[[:space:]]" || \
    mount | grep -qE "[[:space:]]${MOSY_MOUNT_POINT%/}/?[[:space:]]type[[:space:]]"
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
        mosy_exec "mv \"$target\" \"$backup_path\""
    fi
}

log_debug() {
    if [[ "$MOSY_LOG_LEVEL" == "DEBUG" ]]; then
        echo "[DEBUG] $@"
    fi
}

log_error() {
    echo "$@" >&2
}
