# Load configuration
CONFIG_DIR="${HOME}/.config/mosy"
[ -f "$CONFIG_DIR/config" ] && . "$CONFIG_DIR/config"

SYNC_DIR="${MOSY_CLOUD_DIR:-${HOME}/GoogleDrive/mosy_vault}"
MOUNT_POINT="${MOSY_MOUNT_POINT:-${HOME}/GoogleDrive}"
MAP_FILE="$SYNC_DIR/sync-map.conf"

check_mount() {
    if ! mount | grep -q "$MOUNT_POINT"; then
        echo "Error: Cloud drive is not mounted at $MOUNT_POINT"
        echo "Try: systemctl --user start mosy-mount.service (if installed)"
        exit 1
    fi
}

foreach_mapping() {
    local callback=$1
    if [ ! -f "$MAP_FILE" ]; then
        return 0
    fi

    # Read map into memory first to avoid issues if the callback modifies the file
    local map_entries=()
    while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] && map_entries+=("$line")
    done < "$MAP_FILE"

    for entry in "${map_entries[@]}"; do
        IFS="|" read -r local_rel cloud_rel <<< "$entry"
        if [ -z "$local_rel" ]; then continue; fi
        "$callback" "$local_rel" "$cloud_rel"
    done
}
