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

@test "Version: Displays current version and path" {
  run mosy version
  assert_success
  assert_output --partial "MountSync version"
  assert_output --partial "Installed at:"
}

@test "Update: Fails if local changes exist" {
  # Mock git to show changes
  cat <<EOF > "$MOCK_BIN/git"
#!/bin/bash
if [[ "\$*" == *"diff-index --quiet HEAD --"* ]]; then
    exit 1
fi
exit 0
EOF
  chmod +x "$MOCK_BIN/git"

  run mosy update
  assert_failure
  assert_output --partial "Local changes detected"
}

@test "Update: Reports already up to date" {
  # Mock git to show same SHA
  cat <<EOF > "$MOCK_BIN/git"
#!/bin/bash
if [[ "\$*" == *"diff-index --quiet HEAD --"* ]]; then
    exit 0
fi
if [[ "\$*" == *"rev-parse HEAD"* ]]; then
    echo "current-sha"
    exit 0
fi
if [[ "\$*" == *"fetch origin main"* ]]; then
    exit 0
fi
if [[ "\$*" == *"rev-parse origin/main"* ]]; then
    echo "current-sha"
    exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_BIN/git"

  run mosy update
  assert_success
  assert_output --partial "MountSync is already up to date."
}

@test "Update: Success scenario" {
  # Mock git for success
  cat <<EOF > "$MOCK_BIN/git"
#!/bin/bash
if [[ "\$*" == *"diff-index --quiet HEAD --"* ]]; then exit 0; fi
if [[ "\$*" == *"rev-parse HEAD"* ]]; then echo "old-sha"; exit 0; fi
if [[ "\$*" == *"fetch origin main"* ]]; then exit 0; fi
if [[ "\$*" == *"rev-parse origin/main"* ]]; then echo "new-sha"; exit 0; fi
if [[ "\$*" == *"pull origin main"* ]]; then exit 0; fi
exit 1
EOF
  chmod +x "$MOCK_BIN/git"

  # Mock rclone for install.sh
  cat <<EOF > "$MOCK_BIN/rclone"
#!/bin/bash
if [[ "\$*" == "listremotes" ]]; then echo "remote:"; exit 0; fi
exit 0
EOF
  chmod +x "$MOCK_BIN/rclone"

  run mosy update
  assert_success
  assert_output --partial "Update successful!"
}

@test "Update: Failure and rollback" {
  # Mock git for failure and rollback
  cat <<EOF > "$MOCK_BIN/git"
#!/bin/bash
# Using a file to track state for mock persistence if needed, but simple grep works here
if [[ "\$*" == *"diff-index --quiet HEAD --"* ]]; then exit 0; fi
if [[ "\$*" == *"rev-parse HEAD"* ]]; then echo "old-sha"; exit 0; fi
if [[ "\$*" == *"fetch origin main"* ]]; then exit 0; fi
if [[ "\$*" == *"rev-parse origin/main"* ]]; then echo "new-sha"; exit 0; fi
if [[ "\$*" == *"pull origin main"* ]]; then
    echo "Pull failed!"
    exit 1
fi
if [[ "\$*" == *"reset --hard old-sha"* ]]; then
    echo "Rollback success"
    exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_BIN/git"

  # Mock rclone for install.sh
  cat <<EOF > "$MOCK_BIN/rclone"
#!/bin/bash
exit 0
EOF
  chmod +x "$MOCK_BIN/rclone"

  run mosy update
  assert_failure
  assert_output --partial "Update failed. Rolling back..."
  assert_output --partial "Rollback success"
}
