#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_REMOTE_NAME="test-remote"
    export MOSY_MOUNT_POINT="$HOME/GoogleDrive"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    export MOSY_PROFILE="default"
    export MOSY_PROFILE_DIR="$MOSY_CLOUD_DIR"
    export MOSY_MAP_FILE="$MOSY_PROFILE_DIR/sync-map.conf"

    mkdir -p "$MOSY_CLOUD_DIR"
    mkdir -p "$HOME/.config/mosy"
    chmod 700 "$HOME/.config/mosy"
    cat <<EOF > "$HOME/.config/mosy/config"
MOSY_REMOTE_NAME=test-remote
MOSY_MOUNT_POINT=$MOSY_MOUNT_POINT
EOF

    mkdir -p "$MOCK_BIN"

    # Default Mock for rclone: healthy
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

    # Default Mock for systemctl: active service
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

    # Default Mock for pgrep: rclone running
    cat <<'EOF' > "$MOCK_BIN/pgrep"
#!/bin/bash
exit 0
EOF
    chmod +x "$MOCK_BIN/pgrep"
}

strip_colors() {
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

@test "Doctor: All checks pass on healthy mounted system" {
    # Create healthy managed item
    mkdir -p "$MOSY_CLOUD_DIR/config"
    touch "$MOSY_CLOUD_DIR/config/app"
    echo "config/app|config/app" > "$MOSY_MAP_FILE"

    mkdir -p "$HOME/config"
    ln -s "$MOSY_CLOUD_DIR/config/app" "$HOME/config/app"

    run mosy doctor
    assert_success

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "Dependencies & Environment"
    echo "$clean_out" | grep -q "rclone: found"
    echo "$clean_out" | grep -q "Mount Point & Services"
    echo "$clean_out" | grep -q "Mount Point ($MOSY_MOUNT_POINT): MOUNTED"
    echo "$clean_out" | grep -q "Cloud Connectivity & Storage"
    echo "$clean_out" | grep -q "Cloud connectivity (test-remote:): REACHABLE"
    echo "$clean_out" | grep -q "Vault storage ($MOSY_CLOUD_DIR): READ/WRITE"
    echo "$clean_out" | grep -q "Mapping & Symlink Integrity"
    echo "$clean_out" | grep -q "\[OK\] config/app"
    echo "$clean_out" | grep -q "Errors: 0"
}

@test "Doctor: Flags missing rclone dependency as ERR" {
    run bash -c 'command() { if [[ "$1" == "-v" && "$2" == "rclone" ]]; then return 1; else builtin command "$@"; fi; }; export -f command; mosy doctor'
    assert_failure

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[ERR\].*rclone"
    echo "$clean_out" | grep -q "Errors: 1"
}

@test "Doctor: Flags unmounted mountpoint and inactive systemd service as ERR/WARN" {
    export MOSY_MOUNT_POINT="$HOME/NotMounted"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"

    cat <<'EOF' > "$MOCK_BIN/systemctl"
#!/bin/bash
if [[ "$1" == "--user" ]] && [[ "$2" == "is-active" ]]; then
    echo "inactive"
    exit 3
fi
exit 1
EOF
    chmod +x "$MOCK_BIN/systemctl"

    run mosy doctor
    assert_failure

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[ERR\].*Mount Point ($MOSY_MOUNT_POINT): NOT MOUNTED"
    echo "$clean_out" | grep -q "\[WARN\].*Systemd service (mosy-mount): INACTIVE"
}

@test "Doctor: Network timeout in rclone about flags as WARN and does not abort" {
    # Mock rclone about with timeout
    cat <<'EOF' > "$MOCK_BIN/rclone"
#!/bin/bash
if [[ "$1" == "about" ]]; then
    echo "Failed to about: connection timed out" >&2
    exit 124
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/rclone"

    mkdir -p "$MOSY_CLOUD_DIR/config"
    touch "$MOSY_CLOUD_DIR/config/app"
    echo "config/app|config/app" > "$MOSY_MAP_FILE"
    mkdir -p "$HOME/config"
    ln -s "$MOSY_CLOUD_DIR/config/app" "$HOME/config/app"

    run mosy doctor
    assert_success

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[WARN\].*Cloud connectivity.*Offline or timeout"
    echo "$clean_out" | grep -q "\[OK\] config/app"
    echo "$clean_out" | grep -q "Warnings: 1"
    echo "$clean_out" | grep -q "Errors: 0"
}

@test "Doctor: Remote auth failure in rclone about flags as ERR" {
    # Mock rclone about with auth error
    cat <<'EOF' > "$MOCK_BIN/rclone"
#!/bin/bash
if [[ "$1" == "about" ]]; then
    echo "oauth2: token expired and refresh failed (invalid_grant)" >&2
    exit 1
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/rclone"

    run mosy doctor
    assert_failure

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[ERR\].*Cloud connectivity.*Authentication failed"
    echo "$clean_out" | grep -q "Errors: 1"
}

@test "Doctor: Detects read-only or permission-denied vault directory" {
    chmod 500 "$MOSY_CLOUD_DIR"

    run mosy doctor
    # Restore permissions so teardown succeeds
    chmod 700 "$MOSY_CLOUD_DIR"

    assert_failure
    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[ERR\].*Vault storage.*Read-only or write failed"
    echo "$clean_out" | grep -q "Errors: 1"
}

@test "Doctor: Detects broken dangling symlinks in sync-map.conf" {
    echo "config/app|config/app" > "$MOSY_MAP_FILE"
    mkdir -p "$HOME/config"
    ln -s "$MOSY_CLOUD_DIR/config/app" "$HOME/config/app"
    # Note: target in $MOSY_CLOUD_DIR does not exist

    run mosy doctor
    assert_failure

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[ERR\] config/app (Broken link: cloud source missing)"
    echo "$clean_out" | grep -q "Errors: 1"
}

@test "Doctor: Detects missing local symlinks when cloud source exists" {
    mkdir -p "$MOSY_CLOUD_DIR/config"
    touch "$MOSY_CLOUD_DIR/config/app"
    echo "config/app|config/app" > "$MOSY_MAP_FILE"

    # Local symlink is not created

    run mosy doctor
    assert_success

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[WARN\] config/app (Missing link: cloud source exists)"
    echo "$clean_out" | grep -q "Warnings: 1"
    echo "$clean_out" | grep -q "Errors: 0"
}

@test "Doctor: Handles missing or empty sync-map.conf gracefully" {
    rm -f "$MOSY_MAP_FILE"

    run mosy doctor
    assert_success

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "No items are currently being managed"
    echo "$clean_out" | grep -q "Errors: 0"
}

@test "Doctor: Respects active profile (-p <profile>) in diagnostics" {
    export MOSY_WORK_DIR="$MOSY_CLOUD_DIR/profiles/work"
    mkdir -p "$MOSY_WORK_DIR/config"
    touch "$MOSY_WORK_DIR/config/work_app"
    echo "config/work_app|config/work_app" > "$MOSY_WORK_DIR/sync-map.conf"

    mkdir -p "$HOME/config"
    ln -s "$MOSY_WORK_DIR/config/work_app" "$HOME/config/work_app"

    run mosy -p work doctor
    assert_success

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[OK\] config/work_app"
    echo "$clean_out" | grep -q "Vault storage ($MOSY_WORK_DIR): READ/WRITE"
}

@test "Doctor --fix: Starts inactive systemd service successfully" {
    # Systemctl initially inactive, but starting it works
    cat <<'EOF' > "$MOCK_BIN/systemctl"
#!/bin/bash
STATUS_FILE="$TEST_HOME/.systemd_status"
if [[ "$1" == "--user" ]] && [[ "$2" == "is-active" ]]; then
    if [ -f "$STATUS_FILE" ]; then
        echo "active"
        exit 0
    else
        echo "inactive"
        exit 3
    fi
elif [[ "$1" == "--user" ]] && [[ "$2" == "start" ]]; then
    touch "$STATUS_FILE"
    echo "Started service $3"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/systemctl"

    run mosy doctor --fix
    assert_success

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[FIXED\].*Started mosy-mount.service"
    echo "$clean_out" | grep -q "Errors: 0"
}

@test "Doctor --fix: Creates missing mount point directory" {
    export MOSY_MOUNT_POINT="$HOME/NewMountPoint"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    rm -rf "$MOSY_MOUNT_POINT"

    run mosy doctor --fix

    assert_dir_exists "$MOSY_MOUNT_POINT"
    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[FIXED\].*Created missing mount directory"
}

@test "Doctor --fix: Recreates missing valid symlinks safely" {
    mkdir -p "$MOSY_CLOUD_DIR/config"
    echo "sample content" > "$MOSY_CLOUD_DIR/config/app.conf"
    echo "config/app.conf|config/app.conf" > "$MOSY_MAP_FILE"

    # Link missing locally
    assert_file_not_exists "$HOME/config/app.conf"

    run mosy doctor --fix
    assert_success

    assert_link_exists "$HOME/config/app.conf"
    assert_equal "$(readlink "$HOME/config/app.conf")" "$MOSY_CLOUD_DIR/config/app.conf"

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[FIXED\].*Recreated symlink for config/app.conf"
    echo "$clean_out" | grep -q "Errors: 0"
}

@test "Doctor --fix: Non-destructive when cloud target is missing" {
    mkdir -p "$HOME/config"
    echo "local important content" > "$HOME/config/app.conf"
    echo "config/app.conf|config/app.conf" > "$MOSY_MAP_FILE"
    # Target in cloud does not exist

    run mosy doctor --fix
    assert_failure

    # Local file must NOT be deleted or overwritten
    assert_file_exists "$HOME/config/app.conf"
    assert_equal "$(cat "$HOME/config/app.conf")" "local important content"

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "Cannot auto-fix config/app.conf (cloud target missing)"
    echo "$clean_out" | grep -q "Errors: 1"
}

@test "Doctor: Returns exit code 0 when all OK, 1 when errors present" {
    echo "missing/item|missing/item" > "$MOSY_MAP_FILE"

    run mosy doctor
    assert_failure
    [ "$status" -eq 1 ]

    # Fix the issue
    mkdir -p "$MOSY_CLOUD_DIR/missing"
    touch "$MOSY_CLOUD_DIR/missing/item"
    mkdir -p "$HOME/missing"
    ln -s "$MOSY_CLOUD_DIR/missing/item" "$HOME/missing/item"

    run mosy doctor
    assert_success
    [ "$status" -eq 0 ]
}

@test "Doctor --fix: Returns exit code 0 after resolving issues" {
    mkdir -p "$MOSY_CLOUD_DIR/data"
    touch "$MOSY_CLOUD_DIR/data/file"
    echo "data/file|data/file" > "$MOSY_MAP_FILE"

    # Local link is missing. With --fix, it should resolve and return exit code 0
    run mosy doctor --fix
    assert_success
    [ "$status" -eq 0 ]

    clean_out=$(strip_colors "$output")
    echo "$clean_out" | grep -q "\[FIXED\].*Recreated symlink for data/file"
    echo "$clean_out" | grep -q "Errors: 0"
}
