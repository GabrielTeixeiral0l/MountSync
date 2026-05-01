#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    common_setup
}

@test "Core: Loads configuration from environment variables" {
  export MOSY_CLOUD_DIR="$HOME/custom_cloud"
  export MOSY_MOUNT_POINT="$HOME/custom_mount"
  
  run bash -c "source src/core.sh && echo \$SYNC_DIR \$MOUNT_POINT"
  assert_output --partial "$HOME/custom_cloud $HOME/custom_mount"
}

@test "Core: Loads configuration from config file" {
  mkdir -p "$HOME/.config/mosy"
  echo "MOSY_MOUNT_POINT=\"$HOME/file_mount\"" > "$HOME/.config/mosy/config"
  echo "MOSY_CLOUD_DIR=\"$HOME/file_cloud\"" >> "$HOME/.config/mosy/config"
  
  run bash -c "source src/core.sh && echo \$SYNC_DIR \$MOUNT_POINT"
  assert_output --partial "$HOME/file_cloud $HOME/file_mount"
}

@test "Core: Defaults to GoogleDrive fallback" {
  run bash -c "source src/core.sh && echo \$SYNC_DIR \$MOUNT_POINT"
  assert_output --partial "$HOME/GoogleDrive/mosy_vault $HOME/GoogleDrive"
}

@test "Core: foreach_mapping iteration works" {
  export MOSY_CLOUD_DIR="$HOME/Cloud/mosy_vault"
  mkdir -p "$MOSY_CLOUD_DIR"
  echo "local1|cloud1" > "$MOSY_CLOUD_DIR/sync-map.conf"
  echo "local2|cloud2" >> "$MOSY_CLOUD_DIR/sync-map.conf"
  
  local test_script="${BATS_TMPDIR}/test_script.sh"
  cat <<EOF > "$test_script"
source src/core.sh
callback() { echo "L:\$1 C:\$2"; }
foreach_mapping callback
EOF
  
  run bash "$test_script"
  assert_output --partial "L:local1 C:cloud1"
  assert_output --partial "L:local2 C:cloud2"
}
