#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}

@test "Info: Displays environment overview in text mode" {
    touch "$HOME/testfile"
    run mosy add "$HOME/testfile" --tag dev,shell --group dotfiles
    assert_success

    run mosy info
    assert_success
    assert_output --partial "=== MountSync Environment Overview ==="
    assert_output --partial "Hostname:"
    assert_output --partial "Architecture:"
    assert_output --partial "Active Profile:"
    assert_output --partial "default"
    assert_output --partial "Cloud Remote:"
    assert_output --partial "test-remote"
    assert_output --partial "Mount Point:"
    assert_output --partial "MOUNTED"
    assert_output --partial "Total Managed:"
    assert_output --partial "1"
    assert_output --partial "Valid Links:"
    assert_output --partial "Unique Tags:"
    assert_output --partial "2"
    assert_output --partial "Unique Groups:"
    assert_output --partial "1"
}

@test "Info: Generates valid JSON output with --json flag" {
    touch "$HOME/file1"
    run mosy add "$HOME/file1" --tag test --group work
    assert_success

    run mosy info --json
    assert_success
    assert_output --partial '"system":'
    assert_output --partial '"hostname":'
    assert_output --partial '"os":'
    assert_output --partial '"architecture":'
    assert_output --partial '"configuration":'
    assert_output --partial '"profile": "default"'
    assert_output --partial '"remote_name": "test-remote"'
    assert_output --partial '"mount_status": "MOUNTED"'
    assert_output --partial '"is_mounted": true'
    assert_output --partial '"metrics":'
    assert_output --partial '"total_managed": 1'
    assert_output --partial '"valid_links": 1'
    assert_output --partial '"broken_links": 0'
    assert_output --partial '"missing_links": 0'
    assert_output --partial '"unique_tags": 1'
    assert_output --partial '"unique_groups": 1'
}

@test "Info: Gracefully handles unmounted state and empty vault" {
    export MOSY_MOUNT_POINT="$HOME/NotMounted_Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"

    run mosy info
    assert_success
    assert_output --partial "NOT MOUNTED"
    assert_output --partial "Total Managed:"
    assert_output --partial "0"

    run mosy info -j
    assert_success
    assert_output --partial '"is_mounted": false'
    assert_output --partial '"mount_status": "NOT MOUNTED"'
    assert_output --partial '"total_managed": 0'
}

@test "Info: Tracks broken and missing links accurately" {
    mkdir -p "$MOSY_CLOUD_DIR"
    # 1. Valid link
    touch "$MOSY_CLOUD_DIR/valid_file"
    ln -s "$MOSY_CLOUD_DIR/valid_file" "$HOME/valid_file"
    echo "valid_file|valid_file|tagA|grpA" > "$MOSY_CLOUD_DIR/sync-map.conf"

    # 2. Missing link (cloud file exists, no local link)
    touch "$MOSY_CLOUD_DIR/missing_file"
    echo "missing_file|missing_file|tagB|grpA" >> "$MOSY_CLOUD_DIR/sync-map.conf"

    # 3. Broken link (local link points to non-existent cloud target)
    ln -s "$MOSY_CLOUD_DIR/nonexistent" "$HOME/broken_file"
    echo "broken_file|nonexistent|tagA|grpB" >> "$MOSY_CLOUD_DIR/sync-map.conf"

    run mosy info --json
    assert_success
    assert_output --partial '"total_managed": 3'
    assert_output --partial '"valid_links": 1'
    assert_output --partial '"missing_links": 1'
    assert_output --partial '"broken_links": 1'
    assert_output --partial '"unique_tags": 2'
    assert_output --partial '"unique_groups": 2'
}

@test "Info: Custom profile isolation with -p flag" {
    touch "$HOME/workdoc"
    run mosy -p work add "$HOME/workdoc" --tag office
    assert_success

    run mosy -p work info
    assert_success
    assert_output --partial "Active Profile:"
    assert_output --partial "work"
    assert_output --partial "profiles/work"
    assert_output --partial "Total Managed:"
    assert_output --partial "1"

    run mosy info
    assert_success
    assert_output --partial "Active Profile:"
    assert_output --partial "default"
    assert_output --partial "Total Managed:"
    assert_output --partial "0"
}
