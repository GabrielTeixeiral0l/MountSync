#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}

@test "Clean: Removes snapshots for single file with --force" {
    echo "active" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc"
    assert_success

    # Create dummy snapshots
    touch "$HOME/.bashrc.bak_20260101_100000"
    touch "$HOME/.bashrc.bak_20260102_100000"

    run mosy clean "$HOME/.bashrc" --force
    assert_success
    assert_output --partial "Success! Removed 2 backup snapshot(s)"

    # Verify symlink is still intact and active
    [ -L "$HOME/.bashrc" ]
    run cat "$HOME/.bashrc"
    assert_output "active"

    # Verify snapshots are gone
    [ ! -e "$HOME/.bashrc.bak_20260101_100000" ]
    [ ! -e "$HOME/.bashrc.bak_20260102_100000" ]
}

@test "Clean: --dry-run / -n simulates deletion without removing files" {
    echo "active" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc"
    assert_success

    touch "$HOME/.bashrc.bak_20260101_100000"

    run mosy clean "$HOME/.bashrc" --dry-run
    assert_success
    assert_output --partial "[DRY RUN] The following backup snapshot(s) would be removed:"
    assert_output --partial ".bashrc.bak_20260101_100000"
    assert_output --partial "Total: 1 file(s)"

    # Verify file was NOT removed
    [ -e "$HOME/.bashrc.bak_20260101_100000" ]
}

@test "Clean: --older-than removes only older snapshots and keeps recent ones" {
    echo "active" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc"
    assert_success

    local old_snap="$HOME/.bashrc.bak_old"
    local new_snap="$HOME/.bashrc.bak_new"

    touch "$old_snap"
    touch "$new_snap"

    # Set old_snap modification time to 30 days ago
    local old_date
    old_date=$(date -d "30 days ago" +%Y%m%d%H%M.%S 2>/dev/null || date -v-30d +%Y%m%d%H%M.%S)
    touch -t "$old_date" "$old_snap"

    run mosy clean "$HOME/.bashrc" --older-than 7d --force
    assert_success
    assert_output --partial "Success! Removed 1 backup snapshot(s)"

    # Old snapshot deleted, new snapshot kept
    [ ! -e "$old_snap" ]
    [ -e "$new_snap" ]
}

@test "Clean: Batch clean purges backups across all managed items" {
    echo "bash" > "$HOME/.bashrc"
    echo "vim" > "$HOME/.vimrc"
    run mosy add "$HOME/.bashrc"
    run mosy add "$HOME/.vimrc"
    assert_success

    touch "$HOME/.bashrc.bak_1"
    touch "$HOME/.vimrc.bak_1"

    run mosy clean --force
    assert_success
    assert_output --partial "Success! Removed 2 backup snapshot(s)"

    [ ! -e "$HOME/.bashrc.bak_1" ]
    [ ! -e "$HOME/.vimrc.bak_1" ]
}

@test "Clean: Removes directory snapshots safely" {
    mkdir -p "$HOME/.config/app"
    echo "cfg" > "$HOME/.config/app/config"
    run mosy add "$HOME/.config/app"
    assert_success

    # Create dummy directory snapshot
    mkdir -p "$HOME/.config/app.bak_20260101_100000"
    echo "old" > "$HOME/.config/app.bak_20260101_100000/config"

    run mosy clean "$HOME/.config/app" --force
    assert_success
    assert_output --partial "Success! Removed 1 backup snapshot(s)"

    [ ! -d "$HOME/.config/app.bak_20260101_100000" ]
    [ -d "$HOME/.config/app" ]
}

@test "Clean: Honors custom MOSY_BACKUP_EXT" {
    export MOSY_BACKUP_EXT=".custombak"
    echo "test" > "$HOME/custom.conf"
    run mosy add "$HOME/custom.conf"
    assert_success

    touch "$HOME/custom.conf.custombak_20260101_100000"

    run mosy clean "$HOME/custom.conf" --force
    assert_success
    assert_output --partial "Success! Removed 1 backup snapshot(s)"

    [ ! -e "$HOME/custom.conf.custombak_20260101_100000" ]
}

@test "Clean: Respects tag and group filters" {
    echo "work" > "$HOME/work.conf"
    echo "home" > "$HOME/home.conf"
    run mosy add "$HOME/work.conf" -t work -g dev
    run mosy add "$HOME/home.conf" -t home -g dev
    assert_success

    touch "$HOME/work.conf.bak_1"
    touch "$HOME/home.conf.bak_1"

    run mosy clean -t work --force
    assert_success
    assert_output --partial "Success! Removed 1 backup snapshot(s)"

    [ ! -e "$HOME/work.conf.bak_1" ]
    [ -e "$HOME/home.conf.bak_1" ]
}

@test "Clean: Reports when no backups are found matching criteria" {
    echo "clean item" > "$HOME/clean.conf"
    run mosy add "$HOME/clean.conf"
    assert_success

    run mosy clean "$HOME/clean.conf" --force
    assert_success
    assert_output "No obsolete backups found matching criteria."
}

@test "Clean: Fails with clear error on invalid duration format" {
    run mosy clean --older-than invalid_time
    assert_failure
    assert_output --partial "Error: Invalid duration format for --older-than: 'invalid_time'"
}
