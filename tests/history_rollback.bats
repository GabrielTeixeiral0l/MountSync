#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}

@test "History: Lists snapshots for specific file in reverse chronological order" {
    echo "current content" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc"
    assert_success

    echo "v1" > "$HOME/.bashrc.bak_20260820_100000"
    echo "v2" > "$HOME/.bashrc.bak_20260821_120000"
    echo "v3" > "$HOME/.bashrc.bak_20260822_150000"

    run mosy history "$HOME/.bashrc"
    assert_success
    assert_output --partial "Backup History for ~/.bashrc:"
    assert_output --partial "[1] 2026-08-22 15:00:00"
    assert_output --partial "[2] 2026-08-21 12:00:00"
    assert_output --partial "[3] 2026-08-20 10:00:00"
}

@test "History: Reports when no history found for specific target" {
    echo "fresh file" > "$HOME/fresh.conf"
    run mosy add "$HOME/fresh.conf"
    assert_success

    run mosy history "$HOME/fresh.conf"
    assert_success
    assert_output --partial "No backup history found for ~/fresh.conf."
}

@test "History: Global history lists all snapshots across managed items" {
    echo "bashrc" > "$HOME/.bashrc"
    echo "vimrc" > "$HOME/.vimrc"
    run mosy add "$HOME/.bashrc"
    run mosy add "$HOME/.vimrc"

    echo "old bash" > "$HOME/.bashrc.bak_20260820_090000"
    echo "old vim" > "$HOME/.vimrc.bak_20260821_110000"

    run mosy history
    assert_success
    assert_output --partial "Backup History for ~/.bashrc:"
    assert_output --partial ".bashrc.bak_20260820_090000"
    assert_output --partial "Backup History for ~/.vimrc:"
    assert_output --partial ".vimrc.bak_20260821_110000"
}

@test "History: Outputs valid JSON format with --json flag" {
    echo "data" > "$HOME/app.conf"
    run mosy add "$HOME/app.conf"
    assert_success

    echo "v1" > "$HOME/app.conf.bak_20260820_100000"

    run mosy history "$HOME/app.conf" --json
    assert_success
    assert_output --partial '"item":"app.conf"'
    assert_output --partial '"timestamp":"20260820_100000"'
    assert_output --partial '"datetime":"2026-08-20 10:00:00"'
    assert_output --partial '"backup_path":'
}

@test "History: Respects tags and groups filtering" {
    echo "dev config" > "$HOME/dev.conf"
    echo "prod config" > "$HOME/prod.conf"
    run mosy add "$HOME/dev.conf" -t dev -g work
    run mosy add "$HOME/prod.conf" -t prod -g server

    echo "old dev" > "$HOME/dev.conf.bak_20260820_090000"
    echo "old prod" > "$HOME/prod.conf.bak_20260820_090000"

    run mosy history -t dev
    assert_success
    assert_output --partial "dev.conf"
    refute_output --partial "prod.conf"
}

@test "Rollback: Restores latest snapshot in non-interactive mode" {
    echo "version 3" > "$HOME/settings.json"
    run mosy add "$HOME/settings.json"
    assert_success

    echo "version 1" > "$HOME/settings.json.bak_20260820_100000"
    echo "version 2" > "$HOME/settings.json.bak_20260821_140000"

    run mosy rollback "$HOME/settings.json"
    assert_success
    assert_output --partial "Success! Rolled back ~/settings.json to settings.json.bak_20260821_140000."

    # Verify content in symlink / vault
    run cat "$HOME/settings.json"
    assert_output "version 2"
}

@test "Rollback: Restores specific snapshot by timestamp" {
    echo "version 3" > "$HOME/myconfig"
    run mosy add "$HOME/myconfig"
    assert_success

    echo "version 1" > "$HOME/myconfig.bak_20260820_100000"
    echo "version 2" > "$HOME/myconfig.bak_20260821_140000"

    run mosy rollback myconfig 20260820_100000
    assert_success
    assert_output --partial "Success! Rolled back ~/myconfig to myconfig.bak_20260820_100000."

    run cat "$HOME/myconfig"
    assert_output "version 1"
}

@test "Rollback: Restores snapshot by index" {
    echo "version 3" > "$HOME/indexconfig"
    run mosy add "$HOME/indexconfig"
    assert_success

    echo "version 1" > "$HOME/indexconfig.bak_20260820_100000"
    echo "version 2" > "$HOME/indexconfig.bak_20260821_140000"

    # Index 1 = most recent (20260821_140000), Index 2 = older (20260820_100000)
    run mosy rollback indexconfig 2
    assert_success
    assert_output --partial "Success! Rolled back ~/indexconfig to indexconfig.bak_20260820_100000."

    run cat "$HOME/indexconfig"
    assert_output "version 1"
}

@test "Rollback: Automatically creates pre-rollback safety backup" {
    echo "pre-rollback live content" > "$HOME/safe.conf"
    run mosy add "$HOME/safe.conf"
    assert_success

    echo "old snapshot" > "$HOME/safe.conf.bak_20260819_120000"

    run mosy rollback safe.conf 1
    assert_success

    # Verify a new backup was created preserving the state before rollback
    run find "$HOME" -maxdepth 1 -name "safe.conf.bak_*"
    assert_success
    # There should be 2 backup files now (the old snapshot + the pre-rollback backup)
    [ $(echo "$output" | wc -l) -ge 2 ]
}

@test "Rollback: Fails if target has no backup snapshots" {
    echo "lone file" > "$HOME/lonely.txt"
    run mosy add "$HOME/lonely.txt"
    assert_success

    run mosy rollback "$HOME/lonely.txt"
    assert_failure
    assert_output --partial "Error: No backup snapshots found for ~/lonely.txt."
}

@test "Rollback: Fails if specified timestamp does not exist" {
    echo "some data" > "$HOME/file.txt"
    run mosy add "$HOME/file.txt"
    assert_success

    echo "backup 1" > "$HOME/file.txt.bak_20260820_100000"

    run mosy rollback file.txt 19990101_000000
    assert_failure
    assert_output --partial "Error: Snapshot '19990101_000000' not found for ~/file.txt."
}

@test "Rollback: Restores managed directory snapshot" {
    mkdir -p "$HOME/myfolder"
    echo "file A live" > "$HOME/myfolder/a.txt"
    run mosy add "$HOME/myfolder"
    assert_success

    # Create directory backup
    mkdir -p "$HOME/myfolder.bak_20260820_100000"
    echo "file A v1" > "$HOME/myfolder.bak_20260820_100000/a.txt"
    echo "file B v1" > "$HOME/myfolder.bak_20260820_100000/b.txt"

    run mosy rollback myfolder 1
    assert_success

    run cat "$HOME/myfolder/a.txt"
    assert_output "file A v1"
    run cat "$HOME/myfolder/b.txt"
    assert_output "file B v1"
}
