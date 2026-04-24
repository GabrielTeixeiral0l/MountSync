#!/usr/bin/env bash

common_setup() {
    # 1. Load BATS helpers
    load 'libs/bats-support/load'
    load 'libs/bats-assert/load'
    load 'libs/bats-file/load'

    # 2. Virtual Home Isolation
    export TEST_HOME=$(mktemp -d)
    export HOME="$TEST_HOME"
    
    # 3. Path setup for testing
    export PROJECT_ROOT="$(pwd)"
    export MOCK_BIN="$TEST_HOME/mock_bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PROJECT_ROOT:$PATH"
    
    # 4. Mock mount command
    cat <<EOF > "$MOCK_BIN/mount"
#!/bin/bash
if [ \$# -eq 0 ]; then
    # Return a dummy mount list
    if [[ "\$MOSY_MOUNT_POINT" == *"NotMounted"* ]]; then
        echo "sysfs on /sys type sysfs (rw,nosuid,nodev,noexec,relatime)"
        exit 0
    fi
    echo "rclone on /home/gabrielteixeira/GoogleDrive type fuse.rclone"
    echo "rclone on \$HOME/Cloud type fuse.rclone"
    echo "rclone on \$MOSY_MOUNT_POINT type fuse.rclone"
    exit 0
fi
# Minimal support for grep checks in tests
exit 1
EOF
    chmod +x "$MOCK_BIN/mount"
}

teardown() {
    rm -rf "$TEST_HOME"
}
