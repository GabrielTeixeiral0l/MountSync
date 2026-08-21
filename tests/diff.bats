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

@test "Diff: Respects custom MOSY_BACKUP_EXT configuration" {
    export MOSY_BACKUP_EXT=".custombak"
    echo "active version" > "$HOME/custom_doc"
    run mosy add "$HOME/custom_doc"
    assert_success

    echo "backup version" > "$HOME/custom_doc.custombak_20260821_170000"

    run mosy diff custom_doc
    assert_success
    assert_output --partial "custom_doc.custombak_20260821_170000"
    assert_output --partial "-backup version"
    assert_output --partial "+active version"
}

@test "Diff: Direct backup filepath passed to -b flag" {
    echo "active text" > "$HOME/direct_file"
    run mosy add "$HOME/direct_file"
    assert_success

    echo "legacy text" > "$HOME/arbitrary_snapshot.bak"

    run mosy diff direct_file -b "$HOME/arbitrary_snapshot.bak"
    assert_success
    assert_output --partial "arbitrary_snapshot.bak"
    assert_output --partial "-legacy text"
    assert_output --partial "+active text"
}

@test "Diff: Filtering with --tag and --group in all-items mode" {
    echo "doc1" > "$HOME/doc1"
    echo "doc2" > "$HOME/doc2"
    run mosy add "$HOME/doc1" --tag dev --group docs
    assert_success
    run mosy add "$HOME/doc2" --tag prod --group ops
    assert_success

    echo "old doc1" > "$HOME/doc1.bak_20260821_111111"
    echo "old doc2" > "$HOME/doc2.bak_20260821_222222"

    run mosy diff --tag dev
    assert_success
    assert_output --partial "doc1.bak_20260821_111111"
    refute_output --partial "doc2.bak_20260821_222222"

    run mosy diff --group ops
    assert_success
    assert_output --partial "doc2.bak_20260821_222222"
    refute_output --partial "doc1.bak_20260821_111111"
}

@test "Diff: Handles no matches in filter criteria and missing map file" {
    echo "item" > "$HOME/item"
    run mosy add "$HOME/item" --tag alpha
    assert_success

    run mosy diff --tag non_existent_tag
    assert_success
    assert_output --partial "No managed items matched filter criteria"

    rm -f "$MOSY_CLOUD_DIR/sync-map.conf"
    run mosy diff
    assert_success
    assert_output --partial "No items are currently being managed"
}

@test "Diff: Cross-profile errors when file missing in active or target profile" {
    mkdir -p "$MOSY_CLOUD_DIR/profiles/work"
    echo "content" > "$MOSY_CLOUD_DIR/profiles/work/only_work.txt"
    ln -s "$MOSY_CLOUD_DIR/profiles/work/only_work.txt" "$HOME/only_work.txt"

    run mosy -p work diff only_work.txt -c default
    assert_failure
    assert_output --partial "Error: File only_work.txt not found in target profile (default)"

    run mosy diff non_existent.txt -c work
    assert_failure
    assert_output --partial "Error: File non_existent.txt not found in active profile (default)"
}

@test "Diff: Rejects unknown flags" {
    run mosy diff --unknown-flag
    assert_failure
    assert_output --partial "Unknown flag: --unknown-flag"
}
