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
    mkdir -p "$HOME/.config/systemd/user"
    touch "$HOME/.config/systemd/user/mosy-mount.service"
    
    # Simulate installation directory
    mkdir -p "$HOME/.mountsync/src"
    cp -r "$PROJECT_ROOT/src" "$HOME/.mountsync/"
    cp "$PROJECT_ROOT/mosy" "$HOME/.mountsync/"
    ln -sf "$HOME/.mountsync/mosy" "$HOME/.local/bin/mosy"

    # Update PATH to use the installed mosy
    export PATH="$HOME/.local/bin:$MOCK_BIN:$PATH"

    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"

    export MOSY_NO_TTY=1
}

@test "Uninstall: Completes and removes installation directory" {
    # Provide 'n' for revert and 'y' for directory cleanup
    run bash -c "echo -e 'n\ny' | mosy uninstall"
    
    assert_success
    assert_output --partial "Stopping and disabling service..."
    assert_output --partial "Removing binary..."
    assert_output --partial "Cleaning up files..."
    
    [ ! -f "$HOME/.config/systemd/user/mosy-mount.service" ]
    [ ! -f "$HOME/.local/bin/mosy" ]
    [ ! -d "$HOME/.mountsync" ]
}

@test "Uninstall: Reverts files and completes" {
    # Prepare a synced file
    touch "$HOME/file1"
    echo "file1|file1" > "$MOSY_CLOUD_DIR/sync-map.conf"
    mv "$HOME/file1" "$MOSY_CLOUD_DIR/file1"
    ln -s "$MOSY_CLOUD_DIR/file1" "$HOME/file1"

    [ -L "$HOME/file1" ]

    # Provide 'y' for revert and 'y' for cleanup
    run bash -c "echo -e 'y\ny' | mosy uninstall"

    assert_success
    assert_output --partial "Reverting file1 to local file..."
    
    [ ! -L "$HOME/file1" ]
    [ -f "$HOME/file1" ]
    [ ! -f "$HOME/.local/bin/mosy" ]
    [ ! -d "$HOME/.mountsync" ]
}
