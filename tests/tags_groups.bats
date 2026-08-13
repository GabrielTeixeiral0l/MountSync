#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    export MOSY_MOUNT_POINT="$TEST_HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    export MOSY_MAP_FILE="$MOSY_CLOUD_DIR/sync-map.conf"
    mkdir -p "$MOSY_CLOUD_DIR"
}

@test "Tags & Groups: mosy add saves tags and groups to map" {
    touch "$TEST_HOME/testfile.txt"
    run mosy add "$TEST_HOME/testfile.txt" --tag work,dev --group desktop
    [ "$status" -eq 0 ]
    [ -f "$MOSY_MAP_FILE" ]
    run cat "$MOSY_MAP_FILE"
    [ "$output" = "testfile.txt|testfile.txt|work,dev|desktop" ]
}

@test "Tags & Groups: mosy add updates existing item tags and groups" {
    touch "$TEST_HOME/testfile.txt"
    mosy add "$TEST_HOME/testfile.txt" --tag oldtag --group oldgroup
    rm -f "$TEST_HOME/testfile.txt"
    touch "$TEST_HOME/testfile.txt"
    run mosy add "$TEST_HOME/testfile.txt" --tag newtag --group newgroup
    [ "$status" -eq 0 ]
    run cat "$MOSY_MAP_FILE"
    [ "$output" = "testfile.txt|testfile.txt|newtag|newgroup" ]
}

@test "Tags & Groups: retrocompatibility parses 2-field lines without tags/groups" {
    echo "legacy.txt|legacy.txt" > "$MOSY_MAP_FILE"
    run mosy list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "legacy.txt" ]]
}

@test "Tags & Groups: mosy list displays tags and groups and filters correctly" {
    echo "file1.txt|file1.txt|work|dev" > "$MOSY_MAP_FILE"
    echo "file2.txt|file2.txt|personal|home" >> "$MOSY_MAP_FILE"

    run mosy list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "file1.txt [tags: work] [groups: dev]" ]]
    [[ "$output" =~ "file2.txt [tags: personal] [groups: home]" ]]

    run mosy list --tag work
    [ "$status" -eq 0 ]
    [[ "$output" =~ "file1.txt" ]]
    [[ ! "$output" =~ "file2.txt" ]]

    run mosy list --group home
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "file1.txt" ]]
    [[ "$output" =~ "file2.txt" ]]
}

@test "Tags & Groups: mosy pull filters by tag and group" {
    echo "file1.txt|file1.txt|work|dev" > "$MOSY_MAP_FILE"
    echo "file2.txt|file2.txt|personal|home" >> "$MOSY_MAP_FILE"

    touch "$MOSY_CLOUD_DIR/file1.txt"
    touch "$MOSY_CLOUD_DIR/file2.txt"

    run mosy pull --tag work
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/file1.txt" ]
    [ ! -e "$TEST_HOME/file2.txt" ]
}

@test "Tags & Groups: mosy init filters links by tag" {
    echo "file1.txt|file1.txt|work|dev" > "$MOSY_MAP_FILE"
    echo "file2.txt|file2.txt|personal|home" >> "$MOSY_MAP_FILE"

    touch "$MOSY_CLOUD_DIR/file1.txt"
    touch "$MOSY_CLOUD_DIR/file2.txt"

    run mosy init --tag work
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/file1.txt" ]
    [ ! -e "$TEST_HOME/file2.txt" ]
}

@test "Tags & Groups: mosy status filters file integrity checks by group" {
    echo "file1.txt|file1.txt|work|dev" > "$MOSY_MAP_FILE"
    echo "file2.txt|file2.txt|personal|home" >> "$MOSY_MAP_FILE"

    touch "$MOSY_CLOUD_DIR/file1.txt"
    ln -s "$MOSY_CLOUD_DIR/file1.txt" "$TEST_HOME/file1.txt"

    run mosy status --group dev
    [ "$status" -eq 0 ]
    [[ "$output" =~ "file1.txt" ]]
    [[ ! "$output" =~ "file2.txt" ]]
}
