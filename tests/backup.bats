#!/usr/bin/env bats
setup() { 
    load 'test_helper'
    common_setup
    source src/core.sh
    export MOSY_REMOTE_NAME="test"
    load_settings
}

@test "backup: renames file using MOSY_BACKUP_EXT" {
    export MOSY_BACKUP_EXT=".testbak"
    touch "$BATS_TEST_TMPDIR/file"
    run mosy_backup "$BATS_TEST_TMPDIR/file"
    ls "$BATS_TEST_TMPDIR/file.testbak_"*
}
