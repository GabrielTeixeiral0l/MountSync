#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
    
    # Mock systemctl to avoid errors and have predictable output
    mkdir -p "$MOCK_BIN"
    cat <<EOF > "$MOCK_BIN/systemctl"
#!/bin/bash
if [ "\$1" == "--user" ] && [ "\$2" == "is-active" ]; then
    # systemctl is-active returns 'inactive' and exit code 3 if inactive
    # We exit 3 and let the '|| echo inactive' in status.sh handle it
    exit 3
fi
exit 1
EOF
    chmod +x "$MOCK_BIN/systemctl"
}

# Helper to strip ANSI color codes
strip_colors() {
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

@test "List: Shows 'no items' when map is missing" {
  run mosy list
  assert_success
  assert_output --partial "No items are currently being managed"
}

@test "List: Lists managed items from the map" {
  echo "config/app|config/app" > "$MOSY_CLOUD_DIR/sync-map.conf"
  echo "scripts/tool|scripts/tool" >> "$MOSY_CLOUD_DIR/sync-map.conf"
  
  run mosy list
  assert_success
  assert_output --partial "Items managed by MountSync:"
  assert_output --partial "- config/app"
  assert_output --partial "- scripts/tool"
}

@test "Status: Shows [OK] for healthy links" {
  mkdir -p "$MOSY_CLOUD_DIR/config"
  touch "$MOSY_CLOUD_DIR/config/app"
  echo "config/app|config/app" > "$MOSY_CLOUD_DIR/sync-map.conf"
  
  # Create a healthy link
  mkdir -p "$HOME/config"
  ln -s "$MOSY_CLOUD_DIR/config/app" "$HOME/config/app"
  
  run mosy status
  assert_success
  
  clean_output=$(strip_colors "$output")
  echo "$clean_output" | grep -q "\[OK\] config/app"
  echo "$clean_output" | grep -q "Total: 1"
  echo "$clean_output" | grep -q "OK: 1"
}

@test "Status: Shows [WARN] for missing links" {
  mkdir -p "$MOSY_CLOUD_DIR/config"
  touch "$MOSY_CLOUD_DIR/config/app"
  echo "config/app|config/app" > "$MOSY_CLOUD_DIR/sync-map.conf"
  
  # Link is missing in $HOME
  
  run mosy status
  assert_success
  
  clean_output=$(strip_colors "$output")
  echo "$clean_output" | grep -q "\[WARN\] config/app (Missing link: cloud source exists)"
  echo "$clean_output" | grep -q "Total: 1"
  echo "$clean_output" | grep -q "Warnings: 1"
}

@test "Status: Shows [ERR] for broken links (cloud source missing)" {
  echo "config/app|config/app" > "$MOSY_CLOUD_DIR/sync-map.conf"
  
  # Create a link pointing to non-existent cloud source
  mkdir -p "$HOME/config"
  ln -s "$MOSY_CLOUD_DIR/config/app" "$HOME/config/app"
  
  run mosy status
  assert_success
  
  clean_output=$(strip_colors "$output")
  echo "$clean_output" | grep -q "\[ERR\] config/app (Broken link: cloud source missing)"
  echo "$clean_output" | grep -q "Total: 1"
  echo "$clean_output" | grep -q "Errors: 1"
}
