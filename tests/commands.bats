#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    # Re-using the virtual home logic from helper
    # 1. Load BATS helpers
    load 'libs/bats-support/load'
    load 'libs/bats-assert/load'
    load 'libs/bats-file/load'

    export TEST_HOME=$(mktemp -d)
    export HOME="$TEST_HOME"
    export PROJECT_ROOT="$(pwd)"
    export PATH="$PROJECT_ROOT/tests/mock_bin:$PROJECT_ROOT:$PATH"
    
    # Set the variables for these tests
    export CSYNC_MOUNT_POINT="$HOME/Cloud"
    export CSYNC_CLOUD_DIR="$CSYNC_MOUNT_POINT/config_sync"
    mkdir -p "$CSYNC_CLOUD_DIR"
}

@test "Add: Successfully syncs a file" {
  touch "$HOME/testfile"
  
  run csync add "$HOME/testfile"
  
  assert_success
  assert_output --partial "Success! testfile is now synced"
  
  [ -f "$CSYNC_CLOUD_DIR/testfile" ]
  [ -L "$HOME/testfile" ]
  run grep "testfile|testfile" "$CSYNC_CLOUD_DIR/sync-map.conf"
  assert_success
}

@test "Add: Successfully syncs a directory" {
  mkdir -p "$HOME/testdir"
  touch "$HOME/testdir/file1"
  
  run csync add "$HOME/testdir"
  
  assert_success
  [ -d "$CSYNC_CLOUD_DIR/testdir" ]
  [ -f "$CSYNC_CLOUD_DIR/testdir/file1" ]
  [ -L "$HOME/testdir" ]
}

@test "Init: Recreates links and adds bridge to .bashrc" {
  mkdir -p "$CSYNC_CLOUD_DIR/scripts"
  touch "$CSYNC_CLOUD_DIR/scripts/myscript"
  echo "scripts/myscript|scripts/myscript" > "$CSYNC_CLOUD_DIR/sync-map.conf"
  
  touch "$HOME/.bashrc"
  
  run csync init
  
  assert_success
  [ -L "$HOME/scripts/myscript" ]
  run grep "ConfigSync - Bridge" "$HOME/.bashrc"
  assert_success
}

@test "Pull: Links missing items but doesn't touch existing" {
  mkdir -p "$CSYNC_CLOUD_DIR/config"
  touch "$CSYNC_CLOUD_DIR/config/app"
  echo "config/app|config/app" > "$CSYNC_CLOUD_DIR/sync-map.conf"
  
  mkdir -p "$HOME/config"
  touch "$HOME/config/app"
  
  mkdir -p "$CSYNC_CLOUD_DIR/scripts"
  touch "$CSYNC_CLOUD_DIR/scripts/tool"
  echo "scripts/tool|scripts/tool" >> "$CSYNC_CLOUD_DIR/sync-map.conf"
  
  run csync pull
  
  assert_success
  [ ! -L "$HOME/config/app" ]
  [ -L "$HOME/scripts/tool" ]
}
