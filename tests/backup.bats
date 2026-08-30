#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}

@test "backup helper: renames file using MOSY_BACKUP_EXT" {
    source src/core.sh
    load_settings
    export MOSY_BACKUP_EXT=".testbak"
    touch "$HOME/file"
    mosy_backup "$HOME/file"
    run find "$HOME" -maxdepth 1 -name "file.testbak_*"
    assert_success
    [ -n "$output" ]
}

@test "Backup: Creates standalone snapshot for single managed file" {
    echo "active config content" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc"
    assert_success

    run mosy backup "$HOME/.bashrc"
    assert_success
    assert_output --partial "Success! Created safety backup for ~/.bashrc"

    # Verify symlink is still active and intact
    [ -L "$HOME/.bashrc" ]
    run cat "$HOME/.bashrc"
    assert_output "active config content"

    # Verify backup file was created with actual content
    local backup_file
    backup_file=$(find "$HOME" -maxdepth 1 -name ".bashrc.bak_*" | head -n 1)
    [ -f "$backup_file" ]
    [ ! -L "$backup_file" ]
    run cat "$backup_file"
    assert_output "active config content"
}

@test "Backup: Creates standalone snapshot for managed directory" {
    mkdir -p "$HOME/.config/app"
    echo "key=1" > "$HOME/.config/app/settings.conf"
    run mosy add "$HOME/.config/app"
    assert_success

    run mosy backup "$HOME/.config/app"
    assert_success
    assert_output --partial "Success! Created safety backup for ~/.config/app"

    # Verify snapshot directory contains copies
    local backup_dir
    backup_dir=$(find "$HOME/.config" -maxdepth 1 -name "app.bak_*" | head -n 1)
    [ -d "$backup_dir" ]
    run cat "$backup_dir/settings.conf"
    assert_output "key=1"
}

@test "Backup: Creates snapshot for unmanaged regular local file" {
    echo "unmanaged local content" > "$HOME/local_only.txt"

    run mosy backup "$HOME/local_only.txt"
    assert_success
    assert_output --partial "Success! Created safety backup for ~/local_only.txt"

    local backup_file
    backup_file=$(find "$HOME" -maxdepth 1 -name "local_only.txt.bak_*" | head -n 1)
    [ -f "$backup_file" ]
    run cat "$backup_file"
    assert_output "unmanaged local content"
}

@test "Backup: Creates snapshot for unmanaged regular local directory" {
    mkdir -p "$HOME/local_folder"
    echo "data inside" > "$HOME/local_folder/data.txt"

    run mosy backup "$HOME/local_folder"
    assert_success
    assert_output --partial "Success! Created safety backup for ~/local_folder"

    local backup_dir
    backup_dir=$(find "$HOME" -maxdepth 1 -name "local_folder.bak_*" | head -n 1)
    [ -d "$backup_dir" ]
    run cat "$backup_dir/data.txt"
    assert_output "data inside"
}

@test "Backup: Batch backups all managed items when no path is given" {
    echo "bash" > "$HOME/.bashrc"
    echo "vim" > "$HOME/.vimrc"
    run mosy add "$HOME/.bashrc"
    run mosy add "$HOME/.vimrc"

    run mosy backup
    assert_success
    assert_output --partial "Creating safety snapshots for managed dotfiles..."
    assert_output --partial "[OK] ~/.bashrc ->"
    assert_output --partial "[OK] ~/.vimrc ->"
    assert_output --partial "Done! Backed up 2 item(s) successfully."
}

@test "Backup: Respects tag and group filters" {
    echo "work bash" > "$HOME/.bashrc"
    echo "home vim" > "$HOME/.vimrc"
    run mosy add "$HOME/.bashrc" -t work -g shell
    run mosy add "$HOME/.vimrc" -t personal -g editor

    run mosy backup -t work
    assert_success
    assert_output --partial "[OK] ~/.bashrc ->"
    refute_output --partial ".vimrc"
    assert_output --partial "Done! Backed up 1 item(s) successfully."
}

@test "Backup: Batch mode reports [SKIP] on dangling symlinks" {
    echo "valid config" > "$HOME/valid.conf"
    echo "broken config" > "$HOME/broken.conf"
    run mosy add "$HOME/valid.conf"
    run mosy add "$HOME/broken.conf"
    assert_success

    # Break the cloud target of broken.conf
    rm -f "$MOSY_CLOUD_DIR/broken.conf"

    run mosy backup
    assert_success
    assert_output --partial "[OK] ~/valid.conf ->"
    assert_output --partial "[SKIP] ~/broken.conf (file missing or inaccessible)"
    assert_output --partial "Done! Backed up 1 item(s) successfully."
}

@test "Backup: Reports message when no items match criteria" {
    run mosy backup -t nonexistent
    assert_success
    assert_output --partial "No managed dotfiles found matching criteria."
}

@test "Backup: Works under custom profile (-p <profile>)" {
    export MOSY_PROFILE="work"
    mkdir -p "$MOSY_CLOUD_DIR/profiles/work"

    echo "work dotfile" > "$HOME/work.conf"
    run mosy -p work add "$HOME/work.conf"
    assert_success

    run mosy -p work backup
    assert_success
    assert_output --partial "[OK] ~/work.conf ->"
    assert_output --partial "Done! Backed up 1 item(s) successfully."
}

@test "Snapshot: Works as alias for backup command" {
    echo "alias test" > "$HOME/alias.conf"
    run mosy add "$HOME/alias.conf"
    assert_success

    run mosy snapshot "$HOME/alias.conf"
    assert_success
    assert_output --partial "Success! Created safety backup for ~/alias.conf"

    run find "$HOME" -maxdepth 1 -name "alias.conf.bak_*"
    assert_success
    [ -n "$output" ]
}

@test "Backup: Fails with clear error when target does not exist" {
    run mosy backup "$HOME/nonexistent.txt"
    assert_failure
    assert_output --partial "Error: Target ~/nonexistent.txt does not exist."
}

@test "Backup: Fails with clear error when single target is a dangling symlink" {
    ln -s "$HOME/missing_destination.txt" "$HOME/dangling.link"

    run mosy backup "$HOME/dangling.link"
    assert_failure
    assert_output --partial "Error: Failed to create safety backup for ~/dangling.link."
}
