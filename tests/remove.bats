#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
    
    # Mock mount
    mkdir -p "$MOSY_MOUNT_POINT"
    # We need to make sure 'mount' command returns the mount point.
    # The test_helper might have some mocks.
}

@test "Remove: Reverts a synced file to local" {
    # Prepare synced file
    touch "$HOME/local_file"
    mkdir -p "$MOSY_CLOUD_DIR"
    echo "local_file|local_file" > "$MOSY_CLOUD_DIR/sync-map.conf"
    mv "$HOME/local_file" "$MOSY_CLOUD_DIR/local_file"
    ln -s "$MOSY_CLOUD_DIR/local_file" "$HOME/local_file"
    
    [ -L "$HOME/local_file" ]
    
    run mosy remove "$HOME/local_file"
    
    assert_success
    assert_output --partial "Success! local_file is now a local file."
    
    [ ! -L "$HOME/local_file" ]
    [ -f "$HOME/local_file" ]
    [ -f "$MOSY_CLOUD_DIR/local_file" ] # Should remain in vault
    
    run grep "local_file|local_file" "$MOSY_CLOUD_DIR/sync-map.conf"
    assert_failure
}

@test "Remove: Reverts a synced directory to local" {
    # Prepare synced directory
    mkdir -p "$HOME/local_dir"
    touch "$HOME/local_dir/content"
    mkdir -p "$MOSY_CLOUD_DIR"
    echo "local_dir|local_dir" > "$MOSY_CLOUD_DIR/sync-map.conf"
    mv "$HOME/local_dir" "$MOSY_CLOUD_DIR/local_dir"
    ln -s "$MOSY_CLOUD_DIR/local_dir" "$HOME/local_dir"
    
    [ -L "$HOME/local_dir" ]
    
    run mosy remove "$HOME/local_dir"
    
    assert_success
    assert_output --partial "Success! local_dir is now a local file."
    
    [ ! -L "$HOME/local_dir" ]
    [ -d "$HOME/local_dir" ]
    [ -f "$HOME/local_dir/content" ]
    [ -d "$MOSY_CLOUD_DIR/local_dir" ] # Should remain in vault
    
    run grep "local_dir|local_dir" "$MOSY_CLOUD_DIR/sync-map.conf"
    assert_failure
}

@test "Remove: Fails if not a symbolic link" {
    touch "$HOME/normal_file"
    
    run mosy remove "$HOME/normal_file"
    
    assert_failure
    assert_output --partial "is not a symbolic link managed by MountSync"
}
