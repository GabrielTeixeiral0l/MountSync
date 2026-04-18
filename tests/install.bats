#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'libs/bats-support/load'
    load 'libs/bats-assert/load'
    load 'libs/bats-file/load'

    export TEST_HOME=$(mktemp -d)
    export HOME="$TEST_HOME"
    export PROJECT_ROOT="$(pwd)"
    
    export MOCK_BIN="$TEST_HOME/mock_bin"
    mkdir -p "$MOCK_BIN"
    
    export PATH="$MOCK_BIN:$PROJECT_ROOT:$PATH"

    cat <<EOF > "$MOCK_BIN/systemctl"
#!/bin/bash
exit 0
EOF
    chmod +x "$MOCK_BIN/systemctl"
}

@test "Install: Successfully creates config and systemd service" {
  touch "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  run bash -c "printf 'MyRemote\n$HOME/MyCloud\n' | bash install.sh"
  
  assert_success
  assert_file_exists "$HOME/.config/csync/config"
}

@test "Install: Skips rclone installation if already present" {
  touch "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  run bash -c "printf '\n\n' | bash install.sh"
  
  assert_success
  refute_output --partial "rclone not found"
}

@test "Install: Aborts if rclone missing and user says no" {
  # Hide system rclone by shadowing with a DIRECTORY
  mkdir -p "$MOCK_BIN/rclone"
  
  run bash -c "printf 'n\n' | bash install.sh"
  
  assert_failure
  assert_output --partial "rclone not found"
}

@test "Install: Triggers rclone installation via sudo if missing" {
  # Hide system rclone
  mkdir -p "$MOCK_BIN/rclone"

  # Mock sudo and curl
  cat <<EOF > "$MOCK_BIN/sudo"
#!/bin/bash
if [[ "\$*" == "-v" ]]; then exit 0; fi
# Simulate installation by removing the directory shadow and creating an executable
rm -rf "$MOCK_BIN/rclone"
touch "$MOCK_BIN/rclone"
chmod +x "$MOCK_BIN/rclone"
echo "SUDO CALLED"
EOF
  cat <<EOF > "$MOCK_BIN/curl"
#!/bin/bash
echo "echo 'RCLONE INSTALLED'"
EOF
  chmod +x "$MOCK_BIN/sudo" "$MOCK_BIN/curl"

  run bash -c "printf 'y\nMyRemote\n$HOME/MyCloud\n' | bash install.sh"
  
  assert_success
  assert_output --partial "Installing rclone..."
  assert_output --partial "SUDO CALLED"
}

@test "Install: Creates ~/.local/bin if missing" {
  touch "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"
  
  run bash -c "printf '\n\n' | bash install.sh"
  
  assert_success
  assert_dir_exists "$HOME/.local/bin"
  assert_file_exists "$HOME/.local/bin/csync"
}

@test "Install: Warns if ~/.local/bin is not in PATH" {
  touch "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"
  
  # Ensure the subshell has a path that definitely doesn't include the new bin
  run bash -c "export PATH='/usr/bin:/bin:$MOCK_BIN:$PROJECT_ROOT'; printf '\n\n' | bash install.sh"
  
  assert_success
  assert_output --partial "Warning: $HOME/.local/bin is not in your PATH"
}

@test "Install: Expands tilde (~) in mount point" {
  touch "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  run bash -c "printf 'TestRemote\n~/TildeCloud\n' | bash install.sh"
  
  assert_success
  run grep "CSYNC_MOUNT_POINT=\"$HOME/TildeCloud\"" "$HOME/.config/csync/config"
  assert_success
}

@test "Install: Uses default values on empty input" {
  touch "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  run bash -c "printf '\n\n' | bash install.sh"
  
  assert_success
  run grep "CSYNC_REMOTE_NAME=\"GoogleDrive\"" "$HOME/.config/csync/config"
  assert_success
}

@test "Install: Overwrites existing configuration" {
  touch "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  mkdir -p "$HOME/.config/csync"
  echo "OLD_DATA=true" > "$HOME/.config/csync/config"

  run bash -c "printf 'NewRemote\n\n' | bash install.sh"
  
  assert_success
  run grep "CSYNC_REMOTE_NAME=\"NewRemote\"" "$HOME/.config/csync/config"
  assert_success
  run grep "OLD_DATA" "$HOME/.config/csync/config"
  assert_failure
}

@test "Install: Handles mkdir permission errors gracefully" {
  touch "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  mkdir -p "$HOME"
  touch "$HOME/.config"

  run bash -c "printf '\n\n' | bash install.sh"
  
  assert_failure
}
