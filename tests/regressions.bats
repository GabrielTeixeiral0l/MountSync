#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    common_setup
}

@test "Regression: foreach_mapping handles map modification during iteration" {
    # 1. Setup a map with 3 entries
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
    
    cat <<EOF > "$MOSY_CLOUD_DIR/sync-map.conf"
item1|item1
item2|item2
item3|item3
EOF

    # 2. Define a callback that modifies the map (removes the current item)
    export VISITED_FILE="$HOME/visited.log"
    touch "$VISITED_FILE"

    modify_callback() {
        local item=$1
        echo "$item" >> "$VISITED_FILE"
        # Real use case: removing the current item from map
        grep -v "^$item|" "$MOSY_CLOUD_DIR/sync-map.conf" > "$MOSY_CLOUD_DIR/sync-map.conf.tmp" || true
        mv "$MOSY_CLOUD_DIR/sync-map.conf.tmp" "$MOSY_CLOUD_DIR/sync-map.conf"
    }

    # 3. Run the iteration
    source src/core.sh
    foreach_mapping modify_callback

    # 4. Verify results
    local count=$(wc -l < "$VISITED_FILE")
    echo "DEBUG: Visited items list:"
    cat "$VISITED_FILE"
    
    if [ "$count" -ne 3 ]; then
        echo "Error: Only $count items visited, expected 3."
        return 1
    fi
}
