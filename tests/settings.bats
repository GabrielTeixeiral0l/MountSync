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
