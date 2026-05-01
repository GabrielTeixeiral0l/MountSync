#!/usr/bin/env bats

setup() {
    load 'test_helper'
    common_setup
    export HOME="$BATS_TEST_TMPDIR"
    mkdir -p "$HOME/.config/mosy"
}

@test "settings: loads default values when no config exists" {
    run bash -c "source src/core.sh && load_settings && echo \$MOSY_VFS_CACHE"
    [ "$status" -eq 0 ]
    [ "$output" == "writes" ]
}

@test "settings: config file overrides defaults" {
    echo 'MOSY_VFS_CACHE="off"' > "$HOME/.config/mosy/config"
    run bash -c "source src/core.sh && load_settings && echo \$MOSY_VFS_CACHE"
    [ "$status" -eq 0 ]
    [ "$output" == "off" ]
}

@test "settings: environment variables override everything" {
    echo 'MOSY_VFS_CACHE="off"' > "$HOME/.config/mosy/config"
    export MOSY_VFS_CACHE="full"
    run bash -c "source src/core.sh && load_settings && echo \$MOSY_VFS_CACHE"
    [ "$status" -eq 0 ]
    [ "$output" == "full" ]
}
