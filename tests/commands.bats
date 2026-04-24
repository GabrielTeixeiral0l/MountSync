#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}

@test "Add: Successfully syncs a file" {
  touch "$HOME/testfile"
  
  run mosy add "$HOME/testfile"
  
  assert_success
  assert_output --partial "Success! testfile is now synced"
  
  [ -f "$MOSY_CLOUD_DIR/testfile" ]
  [ -L "$HOME/testfile" ]
  run grep "testfile|testfile" "$MOSY_CLOUD_DIR/sync-map.conf"
  assert_success
}

@test "Add: Successfully syncs a directory" {
  mkdir -p "$HOME/testdir"
  touch "$HOME/testdir/file1"
  
  run mosy add "$HOME/testdir"
  
  assert_success
  [ -d "$MOSY_CLOUD_DIR/testdir" ]
  [ -f "$MOSY_CLOUD_DIR/testdir/file1" ]
  [ -L "$HOME/testdir" ]
}

@test "Init: Recreates links and adds bridge to .bashrc" {
  mkdir -p "$MOSY_CLOUD_DIR/scripts"
  touch "$MOSY_CLOUD_DIR/scripts/myscript"
  echo "scripts/myscript|scripts/myscript" > "$MOSY_CLOUD_DIR/sync-map.conf"
  
  touch "$HOME/.bashrc"
  
  run mosy init
  
  assert_success
  [ -L "$HOME/scripts/myscript" ]
  run grep "MountSync - Bridge" "$HOME/.bashrc"
  assert_success
}

@test "Pull: Links missing items but doesn't touch existing" {
  mkdir -p "$MOSY_CLOUD_DIR/config"
  touch "$MOSY_CLOUD_DIR/config/app"
  echo "config/app|config/app" > "$MOSY_CLOUD_DIR/sync-map.conf"
  
  mkdir -p "$HOME/config"
  touch "$HOME/config/app"
  
  mkdir -p "$MOSY_CLOUD_DIR/scripts"
  touch "$MOSY_CLOUD_DIR/scripts/tool"
  echo "scripts/tool|scripts/tool" >> "$MOSY_CLOUD_DIR/sync-map.conf"
  
  run mosy pull
  
  assert_success
  [ ! -L "$HOME/config/app" ]
  [ -L "$HOME/scripts/tool" ]
}
