#!/usr/bin/env bats

setup() {
    load 'test_helper'
    common_setup
    export HOME="$TEST_HOME"
    mkdir -p "$HOME/.config/mosy"
}

@test "settings: loads default values when no config exists" {
    export MOSY_REMOTE_NAME="gdrive"
    run bash -c "source src/core.sh && load_settings && echo \$MOSY_VFS_CACHE"
    [ "$status" -eq 0 ]
    [ "$output" == "writes" ]
}

@test "settings: config file overrides defaults" {
    export MOSY_REMOTE_NAME="gdrive"
    echo 'MOSY_VFS_CACHE="off"' > "$HOME/.config/mosy/config"
    run bash -c "source src/core.sh && load_settings && echo \$MOSY_VFS_CACHE"
    [ "$status" -eq 0 ]
    [ "$output" == "off" ]
}

@test "settings: environment variables override everything" {
    export MOSY_REMOTE_NAME="gdrive"
    echo 'MOSY_VFS_CACHE="off"' > "$HOME/.config/mosy/config"
    export MOSY_VFS_CACHE="full"
    run bash -c "source src/core.sh && load_settings && echo \$MOSY_VFS_CACHE"
    [ "$status" -eq 0 ]
    [ "$output" == "full" ]
}

@test "settings: fails if MOSY_REMOTE_NAME is missing" {
    unset MOSY_REMOTE_NAME
    # Create empty config to ensure it's not loaded from there
    touch "$HOME/.config/mosy/config"
    run bash -c "source src/core.sh && load_settings"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: MOSY_REMOTE_NAME is missing"* ]]
}

@test "settings: loads new Phase 1 defaults" {
    export MOSY_REMOTE_NAME="gdrive"
    run bash -c "source src/core.sh && load_settings && echo \"\$MOSY_LOG_LEVEL|\$MOSY_DRY_RUN|\$MOSY_BACKUP_EXT\""
    [ "$status" -eq 0 ]
    [ "$output" == "INFO|false|.bak" ]
}

@test "settings: profile defaults to default and uses root vault" {
    export MOSY_REMOTE_NAME="gdrive"
    export MOSY_CLOUD_DIR="/tmp/vault"
    run bash -c "source src/core.sh && load_settings && echo \"\$MOSY_PROFILE|\$MOSY_MAP_FILE\""
    [ "$status" -eq 0 ]
    [ "$output" == "default|/tmp/vault/sync-map.conf" ]
}

@test "settings: custom profile uses profiles subdirectory" {
    export MOSY_REMOTE_NAME="gdrive"
    export MOSY_CLOUD_DIR="/tmp/vault"
    export MOSY_PROFILE="work"
    run bash -c "source src/core.sh && load_settings && echo \"\$MOSY_PROFILE|\$MOSY_MAP_FILE\""
    [ "$status" -eq 0 ]
    [ "$output" == "work|/tmp/vault/profiles/work/sync-map.conf" ]
}
