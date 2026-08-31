#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}

@test "Which: Reports healthy managed file with exit code 0" {
    echo "test content" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc" -t shell -g env
    assert_success

    run mosy which "$HOME/.bashrc"
    assert_success
    assert_output --partial "Item:         ~/.bashrc"
    assert_output --partial "Managed:      Yes (Profile: default)"
    assert_output --partial "Root Entry:   ~/.bashrc"
    assert_output --partial "Cloud Target: $MOSY_CLOUD_DIR/.bashrc"
    assert_output --partial "Link Status:  OK (Active Symlink)"
    assert_output --partial "Tags:         shell"
    assert_output --partial "Groups:       env"
}

@test "Which: Outputs valid JSON format with --json flag" {
    mkdir -p "$HOME/.config"
    echo "test config" > "$HOME/.config/app.conf"
    run mosy add "$HOME/.config/app.conf" -t app
    assert_success

    run mosy which "$HOME/.config/app.conf" --json
    assert_success
    assert_output --partial '"managed":true'
    assert_output --partial '"profile":"default"'
    assert_output --partial '"status":"OK"'
    assert_output --partial '"path":"~/.config/app.conf"'
    assert_output --partial '"tags":["app"]'
}

@test "Which: Reports unmanaged file with exit code 1" {
    echo "local only" > "$HOME/local.txt"

    run mosy which "$HOME/local.txt"
    assert_failure
    assert_output "~/local.txt is NOT managed by MountSync."
}

@test "Which: Reports unmanaged file in JSON format with exit code 1" {
    run mosy which "$HOME/nonexistent.txt" --json
    assert_failure
    assert_output --partial '"managed":false'
    assert_output --partial '"status":"NOT_MANAGED"'
    assert_output --partial '"profile":"default"'
}

@test "Which: Fails when path argument is missing" {
    run mosy which
    assert_failure
    assert_output --partial "Error: Path argument is required."
}

@test "Which: Detects broken symlink when cloud target is missing" {
    echo "broken" > "$HOME/broken.conf"
    run mosy add "$HOME/broken.conf"
    assert_success

    # Remove target in cloud vault
    rm -f "$MOSY_CLOUD_DIR/broken.conf"

    run mosy which "$HOME/broken.conf"
    assert_failure
    assert_output --partial "Link Status:  Broken Link (target missing in vault)"

    run mosy which "$HOME/broken.conf" --json
    assert_failure
    assert_output --partial '"status":"BROKEN_LINK"'
}

@test "Which: Detects local physical unlinked file" {
    echo "test" > "$HOME/unlinked.conf"
    run mosy add "$HOME/unlinked.conf"
    assert_success

    # Replace symlink with local physical file
    rm -f "$HOME/unlinked.conf"
    echo "now physical" > "$HOME/unlinked.conf"

    run mosy which "$HOME/unlinked.conf"
    assert_failure
    assert_output --partial "Link Status:  Local Physical File (Unlinked)"

    run mosy which "$HOME/unlinked.conf" --json
    assert_failure
    assert_output --partial '"status":"LOCAL_PHYSICAL"'
}

@test "Which: Resolves nested file inside managed directory" {
    mkdir -p "$HOME/scripts"
    echo "echo test" > "$HOME/scripts/deploy.sh"
    run mosy add "$HOME/scripts" -t dev -g tools
    assert_success

    run mosy which "$HOME/scripts/deploy.sh"
    assert_success
    assert_output --partial "Item:         ~/scripts/deploy.sh"
    assert_output --partial "Root Entry:   ~/scripts"
    assert_output --partial "Cloud Target: $MOSY_CLOUD_DIR/scripts/deploy.sh"
    assert_output --partial "Link Status:  OK (Active Symlink)"
    assert_output --partial "Tags:         dev"
    assert_output --partial "Groups:       tools"
}

@test "Which: Respects custom profile with -p flag" {
    mkdir -p "$MOSY_CLOUD_DIR/profiles/work"

    echo "work dotfile" > "$HOME/work.conf"
    run mosy -p work add "$HOME/work.conf"
    assert_success

    # Query under default profile (should not be managed)
    run mosy which "$HOME/work.conf"
    assert_failure

    # Query under work profile (should be managed)
    run mosy -p work which "$HOME/work.conf"
    assert_success
    assert_output --partial "Managed:      Yes (Profile: work)"
}

@test "Which: Counts snapshots with custom MOSY_BACKUP_EXT" {
    export MOSY_BACKUP_EXT=".custombak"
    echo "test" > "$HOME/custom.conf"
    run mosy add "$HOME/custom.conf"
    assert_success

    # Create backups with custom extension and legacy extension
    touch "$HOME/custom.conf.custombak_20260831_120000"
    touch "$HOME/custom.conf.backup_20260831_110000"

    run mosy which "$HOME/custom.conf"
    assert_success
    assert_output --partial "Snapshots:    2 in history"
}
