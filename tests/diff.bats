#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}

@test "Diff: Diffs current symlinked file against latest backup" {
    echo "line 1: original content" > "$HOME/testfile"
    run mosy add "$HOME/testfile"
    assert_success

    # Simulate a previous backup
    echo "line 1: old backup content" > "$HOME/testfile.bak_20260821_100000"

    run mosy diff "$HOME/testfile"
    assert_success
    assert_output --partial "=== Diff: Backup (testfile.bak_20260821_100000) vs Current (testfile) ==="
    assert_output --partial "-line 1: old backup content"
    assert_output --partial "+line 1: original content"
}

@test "Diff: Diffs against specific backup with -b flag" {
    echo "current content" > "$HOME/myfile"
    run mosy add "$HOME/myfile"
    assert_success

    echo "v1 content" > "$HOME/myfile.bak_20260820_090000"
    echo "v2 content" > "$HOME/myfile.bak_20260821_150000"

    run mosy diff myfile -b 20260820_090000
    assert_success
    assert_output --partial "myfile.bak_20260820_090000"
    assert_output --partial "-v1 content"
    assert_output --partial "+current content"
}

@test "Diff: Diffs unlinked physical local file against cloud vault" {
    echo "vault copy" > "$MOSY_CLOUD_DIR/app.conf"
    echo "local diverged copy" > "$HOME/app.conf"

    run mosy diff app.conf
    assert_success
    assert_output --partial "=== Diff: Local physical file vs Cloud Vault (app.conf) ==="
    assert_output --partial "-vault copy"
    assert_output --partial "+local diverged copy"
}

@test "Diff: Cross-profile diff with -c flag" {
    mkdir -p "$MOSY_CLOUD_DIR/profiles/work"
    echo "email = user@personal.org" > "$MOSY_CLOUD_DIR/.gitconfig"
    echo "email = user@corp.com" > "$MOSY_CLOUD_DIR/profiles/work/.gitconfig"

    ln -s "$MOSY_CLOUD_DIR/profiles/work/.gitconfig" "$HOME/.gitconfig"

    run mosy -p work diff .gitconfig -c default
    assert_success
    assert_output --partial "=== Diff: Profile 'work' vs Profile 'default' for .gitconfig ==="
    assert_output --partial "-email = user@corp.com"
    assert_output --partial "+email = user@personal.org"
}

@test "Diff: Diffs all managed items in sync-map.conf with no arguments" {
    echo "fileA original" > "$HOME/fileA"
    echo "fileB original" > "$HOME/fileB"
    run mosy add "$HOME/fileA"
    assert_success
    run mosy add "$HOME/fileB"
    assert_success

    echo "fileA backup" > "$HOME/fileA.bak_20260821_120000"

    run mosy diff
    assert_success
    assert_output --partial "Diff: Backup (fileA.bak_20260821_120000) vs Current (fileA)"
    assert_output --partial "Info: fileB is linked to the cloud vault. No local backup snapshots"
}

@test "Diff: Fails gracefully when target or requested backup does not exist" {
    run mosy diff non_existent_file.txt
    assert_failure
    assert_output --partial "Error: File non_existent_file.txt not found"

    touch "$HOME/exists.txt"
    run mosy add "$HOME/exists.txt"
    assert_success

    run mosy diff exists.txt -b 999999
    assert_failure
    assert_output --partial "Error: Backup snapshot matching '999999' not found"
}
