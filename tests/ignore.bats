#!/usr/bin/env bats

load 'test_helper'

setup() {
    common_setup
    export MOSY_MOUNT_POINT="$TEST_HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}



@test "ignore: expunges node_modules and .git when adding a folder" {
    local target_dir="$TEST_HOME/my_project"
    mkdir -p "$target_dir/node_modules/pkg"
    mkdir -p "$target_dir/.git"
    echo "content" > "$target_dir/main.js"

    run ./mosy add "$target_dir"
    [ "$status" -eq 0 ]

    # Check cloud destination does not have node_modules or .git
    [ ! -d "$MOSY_CLOUD_DIR/my_project/node_modules" ]
    [ ! -d "$MOSY_CLOUD_DIR/my_project/.git" ]
    [ -f "$MOSY_CLOUD_DIR/my_project/main.js" ]
}

@test "ignore: respects custom .mosyignore file" {
    mkdir -p "$TEST_HOME/.config/mosy"
    echo "secret.txt" > "$TEST_HOME/.config/mosy/.mosyignore"

    local target_dir="$TEST_HOME/app_with_secrets"
    mkdir -p "$target_dir"
    echo "secret_data" > "$target_dir/secret.txt"
    echo "public_data" > "$target_dir/public.txt"

    run ./mosy add "$target_dir"
    [ "$status" -eq 0 ]

    [ ! -f "$MOSY_CLOUD_DIR/app_with_secrets/secret.txt" ]
    [ -f "$MOSY_CLOUD_DIR/app_with_secrets/public.txt" ]
}

@test "ignore: handles large directory structure with nested ignored files effectively" {
    local target_dir="$TEST_HOME/large_project"
    mkdir -p "$target_dir/src/components"
    for d in {1..20}; do
        mkdir -p "$target_dir/node_modules/dep_$d"
    done

    for i in {1..50}; do
        local dep_idx=$(( (i % 20) + 1 ))
        echo "log data $i" > "$target_dir/node_modules/dep_${dep_idx}/file_$i.js"
        echo "log data $i" > "$target_dir/src/components/file_$i.tmp"
        echo "code $i" > "$target_dir/src/components/component_$i.js"
    done

    run ./mosy add "$target_dir"
    [ "$status" -eq 0 ]

    [ ! -d "$MOSY_CLOUD_DIR/large_project/node_modules" ]
    [ ! -f "$MOSY_CLOUD_DIR/large_project/src/components/file_1.tmp" ]
    [ -f "$MOSY_CLOUD_DIR/large_project/src/components/component_1.js" ]
    [ -f "$MOSY_CLOUD_DIR/large_project/src/components/component_50.js" ]
}
