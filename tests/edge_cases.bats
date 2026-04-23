#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'libs/bats-support/load'
    load 'libs/bats-assert/load'
    load 'libs/bats-file/load'

    export TEST_HOME=$(mktemp -d)
    export HOME="$TEST_HOME"
    export PROJECT_ROOT="$(pwd)"
    export PATH="$PROJECT_ROOT/tests/mock_bin:$PROJECT_ROOT:$PATH"
    
    export CSYNC_MOUNT_POINT="$HOME/Cloud"
    export CSYNC_CLOUD_DIR="$CSYNC_MOUNT_POINT/csync_vault"
    mkdir -p "$CSYNC_CLOUD_DIR"
}

@test "Core: Fails if not mounted" {
  # Change mount point to something not mocked
  export CSYNC_MOUNT_POINT="$HOME/NotMounted"
  run csync init
  assert_failure
  assert_output --partial "Error: Cloud drive is not mounted at $HOME/NotMounted"
}

@test "Add: Fails if target outside HOME" {
  # Try to add a file from /tmp (outside current $HOME)
  local outside_file=$(mktemp)
  run csync add "$outside_file"
  assert_failure
  assert_output --partial "Error: Target must be within your home directory"
  rm "$outside_file"
}

@test "Add: Fails if target doesn't exist" {
  run csync add "$HOME/ghostfile"
  assert_failure
  # realpath will fail or the script will fail later
}

@test "Add: Warns if already a symlink" {
  touch "$HOME/file"
  ln -s "$HOME/file" "$HOME/link"
  run csync add "$HOME/link"
  assert_output --partial "Warning: $HOME/link is already a symbolic link"
}

@test "Init: Backs up existing files" {
  mkdir -p "$CSYNC_CLOUD_DIR/config"
  touch "$CSYNC_CLOUD_DIR/config/app"
  echo "config/app|config/app" > "$CSYNC_CLOUD_DIR/sync-map.conf"
  
  # Existing local file
  mkdir -p "$HOME/config"
  touch "$HOME/config/app"
  
  run csync init
  assert_success
  
  # Check if backup was created (pattern search because of timestamp)
  run bash -c "ls $HOME/config/app.backup_*"
  assert_success
  # Check if link was created
  [ -L "$HOME/config/app" ]
}

@test "Init: Removes existing symlinks" {
  mkdir -p "$CSYNC_CLOUD_DIR/config"
  touch "$CSYNC_CLOUD_DIR/config/app"
  echo "config/app|config/app" > "$CSYNC_CLOUD_DIR/sync-map.conf"
  
  # Existing local link (wrong target)
  mkdir -p "$HOME/config"
  ln -s "/tmp" "$HOME/config/app"
  
  run csync init
  assert_success
  # Check if link now points to cloud
  run readlink "$HOME/config/app"
  assert_output "$CSYNC_CLOUD_DIR/config/app"
}
