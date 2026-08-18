#!/usr/bin/env bats

load 'test_helper'

setup() {
    common_setup
    export MOSY_MOUNT_POINT="$TEST_HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}



@test "ignore: preserves local node_modules and .git without sending to cloud (zero data loss)" {
    local target_dir="$TEST_HOME/my_project"
    mkdir -p "$target_dir/node_modules/pkg"
    mkdir -p "$target_dir/.git"
    echo "git history" > "$target_dir/.git/config"
    echo "pkg code" > "$target_dir/node_modules/pkg/index.js"
    echo "content" > "$target_dir/main.js"

    run ./mosy add "$target_dir"
    [ "$status" -eq 0 ]

    # Verify cloud vault has ONLY non-ignored items
    [ ! -d "$MOSY_CLOUD_DIR/my_project/node_modules" ]
    [ ! -d "$MOSY_CLOUD_DIR/my_project/.git" ]
    [ -f "$MOSY_CLOUD_DIR/my_project/main.js" ]

    # Verify local machine preserved ALL ignored files intact without data loss
    [ -d "$target_dir/.git" ]
    [ -f "$target_dir/.git/config" ]
    [ -d "$target_dir/node_modules/pkg" ]
    [ -f "$target_dir/node_modules/pkg/index.js" ]
    [ -L "$target_dir/main.js" ]
}

@test "ignore: respects custom .mosyignore file preserving local secrets" {
    mkdir -p "$TEST_HOME/.config/mosy"
    echo "secret.txt" > "$TEST_HOME/.config/mosy/.mosyignore"

    local target_dir="$TEST_HOME/app_with_secrets"
    mkdir -p "$target_dir"
    echo "secret_data" > "$target_dir/secret.txt"
    echo "public_data" > "$target_dir/public.txt"

    run ./mosy add "$target_dir"
    [ "$status" -eq 0 ]

    # Secret is not in cloud
    [ ! -f "$MOSY_CLOUD_DIR/app_with_secrets/secret.txt" ]
    [ -f "$MOSY_CLOUD_DIR/app_with_secrets/public.txt" ]

    # Secret still exists locally and is not a symlink
    [ -f "$target_dir/secret.txt" ]
    [ ! -L "$target_dir/secret.txt" ]
    [ -L "$target_dir/public.txt" ]
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

    # Cloud has no temp or node_modules
    [ ! -d "$MOSY_CLOUD_DIR/large_project/node_modules" ]
    [ ! -f "$MOSY_CLOUD_DIR/large_project/src/components/file_1.tmp" ]
    [ -f "$MOSY_CLOUD_DIR/large_project/src/components/component_1.js" ]
    [ -f "$MOSY_CLOUD_DIR/large_project/src/components/component_50.js" ]

    # Local preserves temp and node_modules intact
    [ -d "$target_dir/node_modules" ]
    [ -f "$target_dir/src/components/file_1.tmp" ]
    [ -L "$target_dir/src/components/component_1.js" ]
}

@test "ignore: trims leading and trailing whitespace and ignores comments in .mosyignore" {
    mkdir -p "$TEST_HOME/.config/mosy"
    cat << 'EOF' > "$TEST_HOME/.config/mosy/.mosyignore"
   # Leading spaces comment
    ignored_file.txt    
	tab_ignored.log	
EOF

    local target_dir="$TEST_HOME/test_trim"
    mkdir -p "$target_dir"
    echo "data" > "$target_dir/ignored_file.txt"
    echo "data" > "$target_dir/tab_ignored.log"
    echo "keep" > "$target_dir/kept.txt"

    run ./mosy add "$target_dir"
    [ "$status" -eq 0 ]

    [ ! -f "$MOSY_CLOUD_DIR/test_trim/ignored_file.txt" ]
    [ ! -f "$MOSY_CLOUD_DIR/test_trim/tab_ignored.log" ]
    [ -f "$MOSY_CLOUD_DIR/test_trim/kept.txt" ]

    # Local files remain intact
    [ -f "$target_dir/ignored_file.txt" ]
    [ -f "$target_dir/tab_ignored.log" ]
    [ -L "$target_dir/kept.txt" ]
}

@test "ignore: full lifecycle add and remove with zero data loss" {
    local app_dir="$TEST_HOME/lifecycle_app"
    mkdir -p "$app_dir/.git"
    echo "git_head" > "$app_dir/.git/HEAD"
    echo "app_config" > "$app_dir/config.json"
    echo "app_log" > "$app_dir/app.log"

    # 1. Add app
    run ./mosy add "$app_dir"
    [ "$status" -eq 0 ]
    [ -f "$app_dir/.git/HEAD" ]
    [ -f "$app_dir/app.log" ]
    [ -L "$app_dir/config.json" ]
    [ -f "$MOSY_CLOUD_DIR/lifecycle_app/config.json" ]
    [ ! -e "$MOSY_CLOUD_DIR/lifecycle_app/.git" ]

    # 2. Revert locally with remove
    run ./mosy remove "$app_dir"
    [ "$status" -eq 0 ]
    [ ! -L "$app_dir/config.json" ]
    [ -f "$app_dir/config.json" ]
    [ -f "$app_dir/.git/HEAD" ]
    [ -f "$app_dir/app.log" ]
}
