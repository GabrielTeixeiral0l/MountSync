#!/usr/bin/env bats

load 'test_helper.bash'

@test "Core: Loads configuration from environment variables" {
  export CSYNC_CLOUD_DIR="$HOME/custom_cloud"
  export CSYNC_MOUNT_POINT="$HOME/custom_mount"
  
  run bash -c "source src/core.sh && echo \$SYNC_DIR \$MOUNT_POINT"
  assert_output --partial "$HOME/custom_cloud $HOME/custom_mount"
}

@test "Core: Loads configuration from config file" {
  mkdir -p "$HOME/.config/csync"
  echo "CSYNC_MOUNT_POINT=\"$HOME/file_mount\"" > "$HOME/.config/csync/config"
  echo "CSYNC_CLOUD_DIR=\"$HOME/file_cloud\"" >> "$HOME/.config/csync/config"
  
  run bash -c "source src/core.sh && echo \$SYNC_DIR \$MOUNT_POINT"
  assert_output --partial "$HOME/file_cloud $HOME/file_mount"
}

@test "Core: Defaults to GoogleDrive fallback" {
  run bash -c "source src/core.sh && echo \$SYNC_DIR \$MOUNT_POINT"
  assert_output --partial "$HOME/GoogleDrive/csync_vault $HOME/GoogleDrive"
}

@test "Core: foreach_mapping iteration works" {
  export CSYNC_CLOUD_DIR="$HOME/Cloud/csync_vault"
  mkdir -p "$CSYNC_CLOUD_DIR"
  echo "local1|cloud1" > "$CSYNC_CLOUD_DIR/sync-map.conf"
  echo "local2|cloud2" >> "$CSYNC_CLOUD_DIR/sync-map.conf"
  
  cat <<EOF > test_script.sh
source src/core.sh
callback() { echo "L:\$1 C:\$2"; }
foreach_mapping callback
EOF
  
  run bash test_script.sh
  assert_output --partial "L:local1 C:cloud1"
  assert_output --partial "L:local2 C:cloud2"
}
