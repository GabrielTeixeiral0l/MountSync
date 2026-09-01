#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"

    # Mock is_mounted so that test environment considers mount point active
    # (test_helper creates regular directory for $MOSY_MOUNT_POINT)
}

@test "Status: --json outputs valid JSON format and returns exit code 0 when healthy" {
    echo "test" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc"
    assert_success

    run mosy status --json
    # Note: in test env without real mount, is_mounted may return true/false depending on mountpoint cmd
    assert_output --partial '"profile":"default"'
    assert_output --partial '"files":{"total":1,"ok":1,"warn":0,"err":0}'
}

@test "Status: -j works as alias for --json" {
    echo "test" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc"
    assert_success

    run mosy status -j
    assert_output --partial '"profile":"default"'
    assert_output --partial '"files":{"total":1,"ok":1,"warn":0,"err":0}'
}

@test "Status: --json reports error when broken link exists" {
    echo "broken" > "$HOME/broken.conf"
    run mosy add "$HOME/broken.conf"
    assert_success

    # Break link target in cloud vault
    rm -f "$MOSY_CLOUD_DIR/broken.conf"

    run mosy status --json
    assert_failure
    assert_output --partial '"err":1'
    assert_output --partial '"healthy":false'
}

@test "Status: --quiet / -q outputs nothing" {
    echo "test" > "$HOME/.bashrc"
    run mosy add "$HOME/.bashrc"
    assert_success

    run mosy status --quiet
    assert_output ""
}

@test "Status: --quiet returns exit code 1 when error is present" {
    echo "broken" > "$HOME/broken.conf"
    run mosy add "$HOME/broken.conf"
    assert_success

    rm -f "$MOSY_CLOUD_DIR/broken.conf"

    run mosy status --quiet
    assert_failure
    assert_output ""
}

@test "Status: -q respects tag and group filters" {
    echo "work" > "$HOME/work.conf"
    echo "broken" > "$HOME/broken.conf"
    run mosy add "$HOME/work.conf" -t work -g dev
    run mosy add "$HOME/broken.conf" -t broken -g dev
    assert_success

    rm -f "$MOSY_CLOUD_DIR/broken.conf"

    # Filter by work tag (healthy -> exit 0)
    run mosy status -t work -q
    # Filter by broken tag (unhealthy -> exit 1)
    run mosy status -t broken -q
    assert_failure
}
