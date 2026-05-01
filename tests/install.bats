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
echo "Mocked systemctl \$@"
exit 0
EOF
    chmod +x "$MOCK_BIN/systemctl"
}

@test "Install: Successfully creates config and systemd service" {
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  run bash -c "printf 'MyRemote\n$HOME/MyCloud\n' | bash install.sh"
  
  assert_success
  assert_file_exists "$HOME/.config/mosy/config"
  assert_output --partial "Mocked systemctl --user start mosy-mount.service"
}

@test "Install: Skips rclone installation if already present" {
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  run bash -c "printf '\n\n' | bash install.sh"
  
  assert_success
  refute_output --partial "rclone not found"
}

@test "Install: Aborts if rclone missing and user says no" {
  run bash -c "command() { if [[ \"\$2\" == \"rclone\" ]]; then return 1; else builtin command \"\$@\"; fi; }; export -f command; printf 'n\n' | bash install.sh"
  
  assert_failure
  assert_output --partial "rclone not found"
}

@test "Install: Triggers rclone installation via sudo if missing" {
  # Mock sudo and curl
  cat <<EOF > "$MOCK_BIN/sudo"
#!/bin/bash
if [[ "\$*" == "-v" ]]; then exit 0; fi
# Simulate installation by creating an executable mock
echo -e '#!/bin/bash\nif [[ "\$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
chmod +x "$MOCK_BIN/rclone"
echo "SUDO CALLED"
EOF
  cat <<EOF > "$MOCK_BIN/curl"
#!/bin/bash
echo "echo 'RCLONE INSTALLED'"
EOF
  chmod +x "$MOCK_BIN/sudo" "$MOCK_BIN/curl"

  run bash -c "command() { if [[ \"\$2\" == \"rclone\" ]]; then if [ -x \"$MOCK_BIN/rclone\" ]; then return 0; else return 1; fi; else builtin command \"\$@\"; fi; }; export -f command; printf 'y\nMyRemote\n$HOME/MyCloud\n' | bash install.sh"
  
  assert_success
  assert_output --partial "Installing rclone..."
  assert_output --partial "SUDO CALLED"
}

@test "Install: Creates ~/.local/bin if missing" {
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"
  
  run bash -c "printf '\n\n' | bash install.sh"
  
  assert_success
  assert_dir_exists "$HOME/.local/bin"
  assert_file_exists "$HOME/.local/bin/mosy"
}

@test "Install: Warns if ~/.local/bin is not in PATH" {
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"
  
  # Ensure the subshell has a path that definitely doesn't include the new bin
  run bash -c "export PATH='$MOCK_BIN:$PROJECT_ROOT:/usr/bin:/bin'; printf '\n\n' | bash install.sh"
  
  assert_success
  assert_output --partial "Warning: $HOME/.local/bin is not in your PATH"
}

@test "Install: Expands tilde (~) in mount point" {
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  run bash -c "printf 'TestRemote\n~/TildeCloud\n' | bash install.sh"
  
  assert_success
  run grep "MOSY_MOUNT_POINT=\"$HOME/TildeCloud\"" "$HOME/.config/mosy/config"
  assert_success
}

@test "Install: Uses default values on empty input" {
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  run bash -c "printf '\n\n' | bash install.sh"
  
  assert_success
  run grep "MOSY_REMOTE_NAME=\"GoogleDrive\"" "$HOME/.config/mosy/config"
  assert_success
}

@test "Install: Overwrites existing configuration" {
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  mkdir -p "$HOME/.config/mosy"
  echo "OLD_DATA=true" > "$HOME/.config/mosy/config"

  run bash -c "printf 'NewRemote\n\n' | bash install.sh"
  
  assert_success
  run grep "MOSY_REMOTE_NAME=\"NewRemote\"" "$HOME/.config/mosy/config"
  assert_success
  run grep "OLD_DATA" "$HOME/.config/mosy/config"
  assert_failure
}

@test "Install: Handles mkdir permission errors gracefully" {
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  mkdir -p "$HOME"
  touch "$HOME/.config"

  run bash -c "printf '\n\n' | bash install.sh"
  
  assert_failure
}

@test "Install: Allows skipping systemd setup if already mounted" {
  # Mock rclone
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  # Mock mountpoint to return success (meaning it's a mountpoint)
  cat <<EOF > "$MOCK_BIN/mountpoint"
#!/bin/bash
exit 0
EOF
  chmod +x "$MOCK_BIN/mountpoint"

  # Run install and say 'n' to the auto-mount service question
  # Inputs: Enter (remote), Enter (mountpoint), 'n' (skip systemd)
  run bash -c "printf '\n\nn\n' | bash install.sh"

  assert_success
  assert_output --partial "Skipping Systemd service setup"
  
  # Service file should NOT exist
  [ ! -f "$HOME/.config/systemd/user/mosy-mount.service" ]
}

@test "Install: Auto-downloads repo when piped via curl" {
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  # Create a mock git command
  cat <<EOF > "$MOCK_BIN/git"
#!/bin/bash
if [[ "\$1" == "clone" ]]; then
  mkdir -p "\$3/src"
  touch "\$3/mosy"
  # Mock install.sh in the cloned dir so exec bash install.sh doesn't fail
  cat <<SCRIPT > "\$3/install.sh"
echo "MOCKED INSTALLER RAN"
SCRIPT
  exit 0
fi
EOF
  chmod +x "$MOCK_BIN/git"

  # Run install.sh from an empty directory to trigger auto-download
  EMPTY_DIR=$(mktemp -d)
  cd "$EMPTY_DIR"
  run bash "$PROJECT_ROOT/install.sh"

  assert_success
  assert_output --partial "--- Downloading MountSync ---"
  assert_output --partial "Cloning repository to $HOME/.mountsync..."
  assert_output --partial "MOCKED INSTALLER RAN"
}

@test "Install: Auto-updates existing repo when piped via curl" {
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  # Mock git command
  cat <<EOF > "$MOCK_BIN/git"
#!/bin/bash
if [[ "\$1" == "pull" ]]; then
  echo "MOCKED PULL RAN"
  cat <<SCRIPT > "install.sh"
echo "MOCKED INSTALLER RAN"
SCRIPT
  exit 0
fi
EOF
  chmod +x "$MOCK_BIN/git"

  # Create dummy existing mountsync dir
  mkdir -p "$HOME/.mountsync/src"
  touch "$HOME/.mountsync/mosy"

  EMPTY_DIR=$(mktemp -d)
  cd "$EMPTY_DIR"
  run bash "$PROJECT_ROOT/install.sh"

  assert_success
  assert_output --partial "--- Downloading MountSync ---"
  assert_output --partial "Updating existing repository at $HOME/.mountsync..."
  assert_output --partial "MOCKED PULL RAN"
  assert_output --partial "MOCKED INSTALLER RAN"
}

@test "Install: --update flag skips prompts and preserves config" {
  # Mock rclone
  echo -e '#!/bin/bash\nif [[ "$1" == "listremotes" ]]; then echo "GoogleDrive:"; fi' > "$MOCK_BIN/rclone"
  chmod +x "$MOCK_BIN/rclone"

  mkdir -p "$HOME/.config/mosy"
  cat <<EOF > "$HOME/.config/mosy/config"
MOSY_REMOTE_NAME="ExistingRemote"
MOSY_MOUNT_POINT="$HOME/ExistingCloud"
MOSY_CLOUD_DIR="$HOME/ExistingCloud/mosy_vault"
EOF

  # Run with --update, should not ask anything
  # If it asks for input, it will fail because stdin is closed/empty in run
  run bash install.sh --update
  
  assert_success
  run grep "MOSY_REMOTE_NAME=\"ExistingRemote\"" "$HOME/.config/mosy/config"
  assert_success
  run grep "MOSY_MOUNT_POINT=\"$HOME/ExistingCloud\"" "$HOME/.config/mosy/config"
  assert_success
}
