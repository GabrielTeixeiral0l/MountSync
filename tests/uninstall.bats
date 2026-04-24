#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    common_setup
    
    # Mock systemctl
    cat <<EOF > "$MOCK_BIN/systemctl"
#!/bin/bash
echo "Mocked systemctl \$@"
exit 0
EOF
    chmod +x "$MOCK_BIN/systemctl"

    # Setup directories
    mkdir -p "$HOME/.local/bin"
    touch "$HOME/.local/bin/mosy"
    mkdir -p "$HOME/.config/systemd/user"
    touch "$HOME/.config/systemd/user/mosy-mount.service"
    mkdir -p "$HOME/.mountsync"

    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"

    export MOSY_NO_TTY=1
}

@test "Uninstall: Completes without reverting files" {
    # Provide 'n' for the first prompt and 'n' for the second
    run bash -c "echo -e 'n\nn' | mosy uninstall"
    
    assert_success
    assert_output --partial "Stopping and disabling service..."
    assert_output --partial "Removing binary..."
    
    [ ! -f "$HOME/.config/systemd/user/mosy-mount.service" ]
    [ ! -f "$HOME/.local/bin/mosy" ]
}

@test "Uninstall: Reverts files and completes" {
    # Prepare a synced file
    touch "$HOME/file1"
    echo "file1|file1" > "$MOSY_CLOUD_DIR/sync-map.conf"
    mv "$HOME/file1" "$MOSY_CLOUD_DIR/file1"
    ln -s "$MOSY_CLOUD_DIR/file1" "$HOME/file1"

    [ -L "$HOME/file1" ]

    # Provide 's' for revert and 'n' for cleanup
    run bash -c "echo -e 's\nn' | mosy uninstall"

    assert_success
    assert_output --partial "Reverting file1 to local file..."
    
    [ ! -L "$HOME/file1" ]
    [ -f "$HOME/file1" ]
    [ ! -f "$HOME/.local/bin/mosy" ]
}
