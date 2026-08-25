#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_REMOTE_NAME="test-remote"
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
    mkdir -p "$HOME/.config/mosy"
    chmod 700 "$HOME/.config/mosy"

    mkdir -p "$MOCK_BIN"
    cat <<'EOF' > "$MOCK_BIN/rclone"
#!/bin/bash
if [[ "$1" == "listremotes" ]]; then
    echo "test-remote:"
    exit 0
elif [[ "$1" == "about" ]]; then
    echo "Total: 100GiB"
    echo "Used: 10GiB"
    echo "Free: 90GiB"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/rclone"

    cat <<'EOF' > "$MOCK_BIN/systemctl"
#!/bin/bash
if [[ "$1" == "--user" ]] && [[ "$2" == "is-active" ]]; then
    echo "active"
    exit 0
elif [[ "$1" == "--user" ]] && [[ "$2" == "start" ]]; then
    echo "Started service $3"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/systemctl"

    cat <<'EOF' > "$MOCK_BIN/pgrep"
#!/bin/bash
exit 0
EOF
    chmod +x "$MOCK_BIN/pgrep"
}

@test "Safety Guard: By default (MOSY_SAFETY_GUARD=true), detects SQLite database and aborts in non-interactive mode" {
    touch "$HOME/app.sqlite"

    run bash -c "mosy add '$HOME/app.sqlite' < /dev/null"
    assert_failure
    assert_output --partial "High-Churn / Database / Lockfile detected"
    assert_output --partial "Embedded database file (app.sqlite)"
    assert_output --partial "Aborting sync to prevent FUSE lock contention"
    [ ! -e "$MOSY_CLOUD_DIR/app.sqlite" ]
    [ ! -L "$HOME/app.sqlite" ]
}

@test "Safety Guard: Detects DuckDB, KDBX, LDB, RDB and DB files" {
    touch "$HOME/analytics.duckdb"
    touch "$HOME/passwords.kdbx"
    touch "$HOME/store.ldb"
    touch "$HOME/dump.rdb"
    touch "$HOME/data.db"
    touch "$HOME/app.sqlite3"

    run bash -c "mosy add '$HOME/analytics.duckdb' < /dev/null"
    assert_failure
    assert_output --partial "Embedded database file (analytics.duckdb)"

    run bash -c "mosy add '$HOME/passwords.kdbx' < /dev/null"
    assert_failure
    assert_output --partial "Embedded database file (passwords.kdbx)"

    run bash -c "mosy add '$HOME/store.ldb' < /dev/null"
    assert_failure
    assert_output --partial "Embedded database file (store.ldb)"

    run bash -c "mosy add '$HOME/dump.rdb' < /dev/null"
    assert_failure
    assert_output --partial "Embedded database file (dump.rdb)"

    run bash -c "mosy add '$HOME/app.sqlite3' < /dev/null"
    assert_failure
    assert_output --partial "Embedded database file (app.sqlite3)"

    run bash -c "mosy add '$HOME/data.db' < /dev/null"
    assert_failure
    assert_output --partial "Database file (data.db)"
}

@test "Safety Guard: Detects SQLite magic header on extensionless database file" {
    # Write "SQLite format 3\000" header
    printf "SQLite format 3\x00extra_header_bytes_here" > "$HOME/custom_state_file"

    run bash -c "mosy add '$HOME/custom_state_file' < /dev/null"
    assert_failure
    assert_output --partial "SQLite database (header: SQLite format 3)"
    [ ! -e "$MOSY_CLOUD_DIR/custom_state_file" ]
}

@test "Safety Guard: Detects runtime locks (*.lock, *.socket, *.pid, *.lck, *.ipc)" {
    touch "$HOME/app.lock"
    touch "$HOME/daemon.pid"
    touch "$HOME/worker.lck"
    touch "$HOME/server.ipc"
    touch "$HOME/system.socket"

    run bash -c "mosy add '$HOME/app.lock' < /dev/null"
    assert_failure
    assert_output --partial "Runtime lock or IPC state file (app.lock)"

    run bash -c "mosy add '$HOME/daemon.pid' < /dev/null"
    assert_failure
    assert_output --partial "Runtime lock or IPC state file (daemon.pid)"

    run bash -c "mosy add '$HOME/worker.lck' < /dev/null"
    assert_failure
    assert_output --partial "Runtime lock or IPC state file (worker.lck)"

    run bash -c "mosy add '$HOME/server.ipc' < /dev/null"
    assert_failure
    assert_output --partial "Runtime lock or IPC state file (server.ipc)"

    run bash -c "mosy add '$HOME/system.socket' < /dev/null"
    assert_failure
    assert_output --partial "Runtime lock or IPC state file (system.socket)"
}

@test "Safety Guard: Detects unix domain sockets and named pipes" {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import socket; s = socket.socket(socket.AF_UNIX); s.bind('$HOME/test.sock')"
    fi
    mkfifo "$HOME/test_pipe"

    if [ -S "$HOME/test.sock" ]; then
        run bash -c "mosy add '$HOME/test.sock' < /dev/null"
        assert_failure
        assert_output --partial "Unix Domain Socket"
    fi

    run bash -c "mosy add '$HOME/test_pipe' < /dev/null"
    assert_failure
    assert_output --partial "Named pipe / FIFO"
}

@test "Safety Guard: Detects high-churn log files and cache paths" {
    touch "$HOME/debug.log"
    touch "$HOME/app.log.1"
    touch "$HOME/session.cache"

    run bash -c "mosy add '$HOME/debug.log' < /dev/null"
    assert_failure
    assert_output --partial "High-churn log/cache file (debug.log)"

    run bash -c "mosy add '$HOME/app.log.1' < /dev/null"
    assert_failure
    assert_output --partial "High-churn log/cache file (app.log.1)"

    run bash -c "mosy add '$HOME/session.cache' < /dev/null"
    assert_failure
    assert_output --partial "High-churn log/cache file (session.cache)"
}

@test "Safety Guard: Single file - Interactive prompt accepts 'y' and syncs file" {
    touch "$HOME/history.sqlite"

    # Simulate answering 'y'
    run bash -c "echo 'y' | mosy add '$HOME/history.sqlite'"
    assert_success
    assert_output --partial "Success! history.sqlite is now synced."
    [ -f "$MOSY_CLOUD_DIR/history.sqlite" ]
    [ -L "$HOME/history.sqlite" ]
}

@test "Safety Guard: Single file - Interactive prompt rejects 'n' and aborts" {
    touch "$HOME/history.sqlite"

    # Simulate answering 'n'
    run bash -c "echo 'n' | mosy add '$HOME/history.sqlite'"
    assert_failure
    assert_output --partial "Sync cancelled by user."
    [ ! -e "$MOSY_CLOUD_DIR/history.sqlite" ]
    [ ! -L "$HOME/history.sqlite" ]
}

@test "Safety Guard: Directory - user chooses 's' (skip) keeps DB and locks local and syncs configs" {
    mkdir -p "$HOME/myai_app"
    echo '{"theme": "dark"}' > "$HOME/myai_app/config.json"
    echo 'prompt: "hello"' > "$HOME/myai_app/settings.yaml"
    touch "$HOME/myai_app/state.sqlite"
    touch "$HOME/myai_app/app.pid"

    # Simulate answering 's' (skip)
    run bash -c "echo 's' | mosy add '$HOME/myai_app'"
    assert_success
    assert_output --partial "Keeping file local (skipped): state.sqlite"
    assert_output --partial "Keeping file local (skipped): app.pid"
    assert_output --partial "Success! myai_app is now synced."

    # Configs moved to cloud and symlinked
    [ -f "$MOSY_CLOUD_DIR/myai_app/config.json" ]
    [ -L "$HOME/myai_app/config.json" ]
    [ -f "$MOSY_CLOUD_DIR/myai_app/settings.yaml" ]
    [ -L "$HOME/myai_app/settings.yaml" ]

    # Volatile DB and PID files remain purely local, NOT in vault, NOT symlinks
    [ ! -e "$MOSY_CLOUD_DIR/myai_app/state.sqlite" ]
    [ ! -e "$MOSY_CLOUD_DIR/myai_app/app.pid" ]
    [ ! -L "$HOME/myai_app/state.sqlite" ]
    [ ! -L "$HOME/myai_app/app.pid" ]
    [ -f "$HOME/myai_app/state.sqlite" ]
    [ -f "$HOME/myai_app/app.pid" ]
}

@test "Safety Guard: Directory - user chooses 'y' syncs everything including DB" {
    mkdir -p "$HOME/myai_all"
    echo '{"theme": "dark"}' > "$HOME/myai_all/config.json"
    touch "$HOME/myai_all/state.sqlite"

    # Simulate answering 'y'
    run bash -c "echo 'y' | mosy add '$HOME/myai_all'"
    assert_success
    assert_output --partial "Success! myai_all is now synced."

    [ -f "$MOSY_CLOUD_DIR/myai_all/config.json" ]
    [ -L "$HOME/myai_all/config.json" ]
    [ -f "$MOSY_CLOUD_DIR/myai_all/state.sqlite" ]
    [ -L "$HOME/myai_all/state.sqlite" ]
}

@test "Safety Guard: Directory - user chooses 'n' cancels entire operation" {
    mkdir -p "$HOME/myai_cancel"
    echo '{"theme": "dark"}' > "$HOME/myai_cancel/config.json"
    touch "$HOME/myai_cancel/state.sqlite"

    # Simulate answering 'n'
    run bash -c "echo 'n' | mosy add '$HOME/myai_cancel'"
    assert_failure
    assert_output --partial "Sync cancelled by user."

    [ ! -e "$MOSY_CLOUD_DIR/myai_cancel" ]
    [ ! -L "$HOME/myai_cancel/config.json" ]
    [ ! -L "$HOME/myai_cancel/state.sqlite" ]
}

@test "Safety Guard: Directory with both secrets and safety risks skips both when chosen" {
    mkdir -p "$HOME/mixed_app"
    echo 'config = true' > "$HOME/mixed_app/settings.conf"
    echo 'SECRET=token12345' > "$HOME/mixed_app/.env"
    touch "$HOME/mixed_app/data.sqlite"

    # Pass 's' twice (once for safety prompt, once for secret prompt)
    run bash -c "printf 's\ns\n' | mosy add --scan-secrets '$HOME/mixed_app'"
    assert_success
    assert_output --partial "Keeping file local (skipped): data.sqlite"
    assert_output --partial "Skipping secret file (kept local): .env"
    assert_output --partial "Success! mixed_app is now synced."

    [ -f "$MOSY_CLOUD_DIR/mixed_app/settings.conf" ]
    [ -L "$HOME/mixed_app/settings.conf" ]
    [ ! -e "$MOSY_CLOUD_DIR/mixed_app/.env" ]
    [ ! -e "$MOSY_CLOUD_DIR/mixed_app/data.sqlite" ]
    [ -f "$HOME/mixed_app/.env" ]
    [ -f "$HOME/mixed_app/data.sqlite" ]
}

@test "Safety Guard: --force / -f bypasses safety guard prompt" {
    touch "$HOME/forced.sqlite"

    run mosy add --force "$HOME/forced.sqlite"
    assert_success
    assert_output --partial "Success! forced.sqlite is now synced."
    [ -f "$MOSY_CLOUD_DIR/forced.sqlite" ]
    [ -L "$HOME/forced.sqlite" ]
}

@test "Safety Guard: --no-guard flag bypasses safety guard" {
    touch "$HOME/noguard.sqlite"

    run mosy add --no-guard "$HOME/noguard.sqlite"
    assert_success
    assert_output --partial "Success! noguard.sqlite is now synced."
    [ -f "$MOSY_CLOUD_DIR/noguard.sqlite" ]
    [ -L "$HOME/noguard.sqlite" ]
}

@test "Safety Guard: config set MOSY_SAFETY_GUARD false disables guard globally" {
    run mosy config set MOSY_SAFETY_GUARD false
    assert_success

    touch "$HOME/disabled_guard.sqlite"
    run bash -c "mosy add '$HOME/disabled_guard.sqlite' < /dev/null"
    assert_success
    assert_output --partial "Success! disabled_guard.sqlite is now synced."
    [ -f "$MOSY_CLOUD_DIR/disabled_guard.sqlite" ]
}

@test "Safety Guard: Doctor detects managed SQLite DB and lockfiles over FUSE with [WARN]" {
    # Forcefully add SQLite database and a lockfile
    touch "$HOME/db.sqlite"
    mosy add --force "$HOME/db.sqlite"

    run mosy doctor
    assert_success
    assert_output --partial "Database & Lockfile Safety Audit"
    assert_output --partial "db.sqlite: Embedded database file (db.sqlite) mounted over FUSE"
    assert_output --partial "Warnings: 1"
}

@test "Safety Guard: Doctor detects nested database inside managed directory" {
    mkdir -p "$HOME/nested_tool/db"
    echo "conf" > "$HOME/nested_tool/config.toml"
    touch "$HOME/nested_tool/db/app.sqlite"

    # Add directory with --force
    mosy add --force "$HOME/nested_tool"

    run mosy doctor
    assert_success
    assert_output --partial "nested_tool (directory): contains 1 volatile symlink(s)"
    assert_output --partial "nested_tool/db/app.sqlite (Embedded database file (app.sqlite))"
    assert_output --partial "Warnings: 1"
}

@test "Safety Guard: Doctor displays OK when no items or no databases are managed" {
    touch "$HOME/clean.conf"
    mosy add "$HOME/clean.conf"

    run mosy doctor
    assert_success
    assert_output --partial "Database & Lockfile Safety Audit"
    assert_output --partial "No active databases, sockets, or lockfiles detected over FUSE"
    assert_output --partial "Warnings: 0"
}

@test "Safety Guard: Doctor detects database inside monolithic directory symlink" {
    mkdir -p "$MOSY_CLOUD_DIR/legacy_monolithic_dir"
    touch "$MOSY_CLOUD_DIR/legacy_monolithic_dir/history.sqlite"
    echo '{"theme": "dark"}' > "$MOSY_CLOUD_DIR/legacy_monolithic_dir/config.json"
    ln -s "$MOSY_CLOUD_DIR/legacy_monolithic_dir" "$HOME/legacy_monolithic_dir"
    echo "legacy_monolithic_dir|legacy_monolithic_dir||" >> "$MOSY_CLOUD_DIR/sync-map.conf"

    run mosy doctor
    assert_success
    assert_output --partial "Database & Lockfile Safety Audit"
    assert_output --partial "legacy_monolithic_dir: Monolithic directory mounted over FUSE contains 1 database/lock/volatile file(s):"
    assert_output --partial "history.sqlite (Embedded database file (history.sqlite))"
}

@test "Safety Guard: Doctor --fix interactively reverts unsafe monolithic directory to local" {
    mkdir -p "$MOSY_CLOUD_DIR/auto_fix_dir"
    touch "$MOSY_CLOUD_DIR/auto_fix_dir/state.sqlite"
    echo '{"theme": "dark"}' > "$MOSY_CLOUD_DIR/auto_fix_dir/config.json"
    ln -s "$MOSY_CLOUD_DIR/auto_fix_dir" "$HOME/auto_fix_dir"
    echo "auto_fix_dir|auto_fix_dir||" >> "$MOSY_CLOUD_DIR/sync-map.conf"

    # Pass 'y' into mosy doctor --fix
    run bash -c "echo 'y' | mosy doctor --fix"
    assert_success
    assert_output --partial "Reverted auto_fix_dir to local directory"
    [ -d "$HOME/auto_fix_dir" ]
    [ ! -L "$HOME/auto_fix_dir" ]
    [ -f "$HOME/auto_fix_dir/state.sqlite" ]
    [ -f "$HOME/auto_fix_dir/config.json" ]
    # Ensure removed from sync-map.conf
    ! grep -q "^auto_fix_dir|" "$MOSY_CLOUD_DIR/sync-map.conf"
}

@test "Safety Guard: Doctor --fix provides safe remediation instructions without breaking files" {
    touch "$HOME/app_warn.sqlite"
    mosy add --force "$HOME/app_warn.sqlite"

    run bash -c "mosy doctor --fix < /dev/null"
    assert_success
    assert_output --partial "Recommendation: Run 'mosy remove ~/app_warn.sqlite'"
    # Verify symlink is still intact and not removed destructively
    [ -L "$HOME/app_warn.sqlite" ]
}

@test "Safety Guard: config set MOSY_SAFETY_GUARD rejects invalid boolean" {
    run mosy config set MOSY_SAFETY_GUARD notaboolean
    assert_failure
    assert_output --partial "Error: Invalid value for MOSY_SAFETY_GUARD (expected true or false)"
}

@test "Safety Guard: Built-in ignore presets ignore SQLite WAL/SHM and lockfiles automatically" {
    mkdir -p "$HOME/sqlite_app"
    echo "content" > "$HOME/sqlite_app/config.json"
    touch "$HOME/sqlite_app/db.sqlite-wal"
    touch "$HOME/sqlite_app/db.sqlite-shm"
    touch "$HOME/sqlite_app/app.lock"

    # Add directory with --force so safety guard doesn't prompt for other files
    run mosy add --force "$HOME/sqlite_app"
    assert_success

    # Ignored files should remain local only
    [ ! -e "$MOSY_CLOUD_DIR/sqlite_app/db.sqlite-wal" ]
    [ ! -e "$MOSY_CLOUD_DIR/sqlite_app/db.sqlite-shm" ]
    [ ! -e "$MOSY_CLOUD_DIR/sqlite_app/app.lock" ]
    [ ! -L "$HOME/sqlite_app/db.sqlite-wal" ]
    [ ! -L "$HOME/sqlite_app/db.sqlite-shm" ]
    [ ! -L "$HOME/sqlite_app/app.lock" ]
    [ -f "$HOME/sqlite_app/db.sqlite-wal" ]
}
