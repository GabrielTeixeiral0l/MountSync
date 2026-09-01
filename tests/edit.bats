#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"

    # Mock editor script that writes its arguments to a log file
    export MOCK_EDITOR_LOG="$HOME/mock_editor.log"
    cat <<'EOF' > "$MOCK_BIN/mock_editor"
#!/bin/bash
echo "EDITED: $@" >> "$MOCK_EDITOR_LOG"
EOF
    chmod +x "$MOCK_BIN/mock_editor"
    export EDITOR="mock_editor"
    export VISUAL="mock_editor"
}

@test "Edit: Opens exact path in configured EDITOR" {
    echo "content 1" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc"
    assert_success

    run mosy edit "$HOME/.bashrc"
    assert_success
    assert_output --partial "Opening ~/.bashrc with"

    run cat "$MOCK_EDITOR_LOG"
    assert_output --partial "EDITED: $HOME/.bashrc"
}

@test "Edit: Resolves partial substring query to matching managed item" {
    echo "alias ll='ls -la'" > "$HOME/.bash_aliases"
    run mosy add "$HOME/.bash_aliases"
    assert_success

    run mosy edit "aliases"
    assert_success
    assert_output --partial "Opening ~/.bash_aliases with"

    run cat "$MOCK_EDITOR_LOG"
    assert_output --partial "EDITED: $HOME/.bash_aliases"
}

@test "Edit: Automatically creates pre-edit safety backup before launch" {
    echo "pre-edit original text" > "$HOME/config.json"
    run mosy add "$HOME/config.json"
    assert_success

    run mosy edit "config.json"
    assert_success
    assert_output --partial "Created safety backup before editing:"

    # Verify backup snapshot was created with original text
    local backup_file
    backup_file=$(find "$HOME" -maxdepth 1 -name "config.json.bak_*" | head -n 1)
    [ -f "$backup_file" ]
    run cat "$backup_file"
    assert_output "pre-edit original text"
}

@test "Edit: --no-backup flag skips pre-edit backup creation" {
    echo "data" > "$HOME/nobackup.conf"
    run mosy add "$HOME/nobackup.conf"
    assert_success

    run mosy edit --no-backup "nobackup.conf"
    assert_success
    refute_output --partial "Created safety backup before editing:"

    run find "$HOME" -maxdepth 1 -name "nobackup.conf.bak_*"
    assert_success
    [ -z "$output" ]
}

@test "Edit: Without query opens first item in non-interactive mode" {
    echo "file 1" > "$HOME/.bashrc"
    echo "file 2" > "$HOME/.zshrc"
    run mosy add "$HOME/.bashrc"
    run mosy add "$HOME/.zshrc"
    assert_success

    run mosy edit
    assert_success
    assert_output --partial "Opening ~/.bashrc with"
}

@test "Edit: Fails with clear error when query matches no managed items" {
    echo "bash" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc"
    assert_success

    run mosy edit "nonexistent_pattern"
    assert_failure
    assert_output --partial "Error: No managed text dotfile found matching 'nonexistent_pattern'."
    assert_output --partial "Run 'mosy list' to view all managed items."
}

@test "Edit: Fails when profile has no managed dotfiles" {
    run mosy edit
    assert_failure
    assert_output --partial "Error: No managed dotfiles found in profile 'default'."
}

@test "Edit: Respects custom profile with -p flag" {
    export MOSY_PROFILE="work"
    mkdir -p "$MOSY_CLOUD_DIR/profiles/work"

    echo "work dotfile" > "$HOME/work.conf"
    run mosy -p work add "$HOME/work.conf"
    assert_success

    run mosy -p work edit "work"
    assert_success
    assert_output --partial "Opening ~/work.conf with"

    run cat "$MOCK_EDITOR_LOG"
    assert_output --partial "EDITED: $HOME/work.conf"
}

@test "Edit: Respects tag and group filters" {
    echo "work config" > "$HOME/work.json"
    echo "personal config" > "$HOME/personal.json"
    run mosy add "$HOME/work.json" -t work -g dev
    run mosy add "$HOME/personal.json" -t personal -g home
    assert_success

    run mosy edit -t work
    assert_success
    assert_output --partial "Opening ~/work.json with"
}

@test "Edit: Locates and edits text file inside managed directory" {
    mkdir -p "$HOME/scripts"
    echo "#!/bin/bash" > "$HOME/scripts/deploy.sh"
    echo "echo deploy" >> "$HOME/scripts/deploy.sh"
    run mosy add "$HOME/scripts"
    assert_success

    run mosy edit "deploy"
    assert_success
    assert_output --partial "Opening ~/scripts/deploy.sh with"

    run cat "$MOCK_EDITOR_LOG"
    assert_output --partial "EDITED: $HOME/scripts/deploy.sh"
}

@test "Edit: Filters out binary files (mp3, png, sqlite) from candidate list" {
    mkdir -p "$HOME/assets"
    echo "some text config" > "$HOME/assets/config.txt"
    # Create fake binary / media files
    printf '\x89PNG\r\n\x1a\n\x00\x00' > "$HOME/assets/logo.png"
    printf 'ID3\x03\x00\x00\x00\x00' > "$HOME/assets/track.mp3"
    printf 'SQLite format 3\x00' > "$HOME/assets/data.sqlite"
    run mosy add "$HOME/assets" --force
    assert_success

    # Searching for mp3 or png should fail to find editable text files
    run mosy edit "logo.png"
    assert_failure
    assert_output --partial "Error: No managed text dotfile found matching 'logo.png'."

    run mosy edit "track"
    assert_failure
    assert_output --partial "Error: No managed text dotfile found matching 'track'."

    # But text file is found seamlessly
    run mosy edit "config.txt"
    assert_success
    assert_output --partial "Opening ~/assets/config.txt with"
}

@test "Edit: Rejects opening explicit binary file directly" {
    printf '\x7fELF\x02\x01\x01\x00\x00' > "$HOME/binary.bin"
    run mosy add "$HOME/binary.bin"
    assert_success

    run mosy edit "$HOME/binary.bin"
    assert_failure
    assert_output --partial "Error: ~/binary.bin is a binary file (not a text file)."
}

@test "Edit: Opens directory directly when editor is folder-capable (code)" {
    mkdir -p "$HOME/my_project"
    echo "index" > "$HOME/my_project/index.js"
    run mosy add "$HOME/my_project"
    assert_success

    export EDITOR="code"
    export VISUAL="code"

    # Mock 'code' in path
    mkdir -p "$HOME/bin"
    cat << 'EOF' > "$HOME/bin/code"
#!/bin/bash
echo "CODE_OPENED: $@" >> "$MOCK_EDITOR_LOG"
EOF
    chmod +x "$HOME/bin/code"
    export PATH="$HOME/bin:$PATH"

    run mosy edit "my_project"
    assert_success
    assert_output --partial "Opening ~/my_project with code..."

    run cat "$MOCK_EDITOR_LOG"
    assert_output --partial "CODE_OPENED: $HOME/my_project"
}

@test "Edit: Directory with only binary files errors out when opened with terminal editor" {
    mkdir -p "$HOME/audio_only"
    printf 'ID3\x03\x00\x00\x00\x00' > "$HOME/audio_only/song1.mp3"
    printf 'ID3\x03\x00\x00\x00\x00' > "$HOME/audio_only/song2.mp3"
    run mosy add "$HOME/audio_only"
    assert_success

    # Mock nano / vi as editor
    export EDITOR="nano"
    export VISUAL="nano"

    run mosy edit "audio_only"
    assert_failure
    assert_output --partial "Error: ~/audio_only is a directory containing no editable text files."
}
