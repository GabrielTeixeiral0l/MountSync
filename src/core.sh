load_settings() {
    local config_file="${HOME}/.config/mosy/config"
    
    if [ -f "$config_file" ]; then
        while IFS='=' read -r key val; do
            [[ "$key" =~ ^[A-Z_]+$ ]] && [ -z "${!key+x}" ] && eval "export $key=$val"
        done < "$config_file"
    fi

    export MOSY_REMOTE_NAME="${MOSY_REMOTE_NAME:-}"
    export MOSY_MOUNT_POINT="${MOSY_MOUNT_POINT:-${HOME}/GoogleDrive}"
    export MOSY_VFS_CACHE="${MOSY_VFS_CACHE:-writes}"
    export MOSY_CLOUD_DIR="${MOSY_CLOUD_DIR:-${MOSY_MOUNT_POINT}/mosy_vault}"
    export MOSY_BACKUP_EXT="${MOSY_BACKUP_EXT:-.bak}"
    export MOSY_LOG_LEVEL="${MOSY_LOG_LEVEL:-INFO}"
    export MOSY_DRY_RUN="${MOSY_DRY_RUN:-false}"
    export MOSY_PROFILE="${MOSY_PROFILE:-default}"

    if [ -z "$MOSY_REMOTE_NAME" ]; then
        echo "Error: MOSY_REMOTE_NAME is missing" >&2
        return 1
    fi
    if [ "$MOSY_PROFILE" = "default" ]; then
        export MOSY_PROFILE_DIR="$MOSY_CLOUD_DIR"
    else
        export MOSY_PROFILE_DIR="$MOSY_CLOUD_DIR/profiles/$MOSY_PROFILE"
    fi
    export MOSY_MAP_FILE="$MOSY_PROFILE_DIR/sync-map.conf"

    # Source ignore helper
    local src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$src_dir/ignore.sh" ]; then
        . "$src_dir/ignore.sh"
    fi
}

# Load settings automatically when sourced
if ! load_settings; then
    exit 1
fi

parse_filter_flags() {
    export MOSY_FILTER_TAG=""
    export MOSY_FILTER_GROUP=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --tag|-t)
                MOSY_FILTER_TAG="$2"
                shift 2
                ;;
            --group|-g)
                MOSY_FILTER_GROUP="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
}

is_mounted() {
    local target="${1:-$MOSY_MOUNT_POINT}"
    mountpoint -q "$target"
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
        IFS="|" read -r local_rel cloud_rel tags groups <<< "$entry"
        if [ -z "$local_rel" ]; then continue; fi

        # Filter by tag if MOSY_FILTER_TAG is set
        if [ -n "${MOSY_FILTER_TAG:-}" ]; then
            local tag_matched=false
            IFS=',' read -ra filter_tags <<< "$MOSY_FILTER_TAG"
            for ft in "${filter_tags[@]}"; do
                if [[ ",${tags:-}," == *",$ft,"* ]]; then
                    tag_matched=true
                    break
                fi
            done
            if [ "$tag_matched" = false ]; then continue; fi
        fi

        # Filter by group if MOSY_FILTER_GROUP is set
        if [ -n "${MOSY_FILTER_GROUP:-}" ]; then
            local group_matched=false
            IFS=',' read -ra filter_groups <<< "$MOSY_FILTER_GROUP"
            for fg in "${filter_groups[@]}"; do
                if [[ ",${groups:-}," == *",$fg,"* ]]; then
                    group_matched=true
                    break
                fi
            done
            if [ "$group_matched" = false ]; then continue; fi
        fi

        "$callback" "$local_rel" "$cloud_rel" "$tags" "$groups"
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
