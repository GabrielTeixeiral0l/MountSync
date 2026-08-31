#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}

@test "Tree: Default view renders managed items with [OK] status" {
    echo "test" > "$HOME/.bashrc"
    echo "alias" > "$HOME/.bash_aliases"
    run mosy add "$HOME/.bashrc" -t shell -g env
    assert_success
    run mosy add "$HOME/.bash_aliases"
    assert_success

    run mosy tree --no-color
    assert_success
    assert_output --partial "MountSync (Profile: default)"
    assert_output --partial ".bashrc [OK] (tags: shell | group: env)"
    assert_output --partial ".bash_aliases [OK]"
}

@test "Tree: Detects broken link and unlinked status" {
    echo "broken" > "$HOME/broken.conf"
    echo "unlinked" > "$HOME/unlinked.conf"
    run mosy add "$HOME/broken.conf"
    assert_success
    run mosy add "$HOME/unlinked.conf"
    assert_success

    # Break broken.conf vault target
    rm -f "$MOSY_CLOUD_DIR/broken.conf"

    # Turn unlinked.conf into physical file
    rm -f "$HOME/unlinked.conf"
    echo "physical" > "$HOME/unlinked.conf"

    run mosy tree --no-color
    assert_success
    assert_output --partial "broken.conf [BROKEN]"
    assert_output --partial "unlinked.conf [UNLINKED]"
}

@test "Tree: Detects missing local file" {
    echo "missing" > "$HOME/missing.conf"
    run mosy add "$HOME/missing.conf"
    assert_success

    # Remove local symlink without touching vault
    rm -f "$HOME/missing.conf"

    run mosy tree --no-color
    assert_success
    assert_output --partial "missing.conf [MISSING]"
}

@test "Tree: --by-group groups items under group nodes" {
    echo "work" > "$HOME/work.conf"
    echo "home" > "$HOME/home.conf"
    run mosy add "$HOME/work.conf" -t dev -g workgroup
    run mosy add "$HOME/home.conf" -t env -g homegroup
    assert_success

    run mosy tree --by-group --no-color
    assert_success
    assert_output --partial "[group: workgroup]"
    assert_output --partial "~/work.conf [OK] (tags: dev)"
    assert_output --partial "[group: homegroup]"
    assert_output --partial "~/home.conf [OK] (tags: env)"
}

@test "Tree: --all-profiles renders all profiles" {
    mkdir -p "$MOSY_CLOUD_DIR/profiles/work"
    echo "default item" > "$HOME/def.conf"
    echo "work item" > "$HOME/work.conf"

    run mosy add "$HOME/def.conf"
    assert_success
    run mosy -p work add "$HOME/work.conf"
    assert_success

    run mosy tree --all-profiles --no-color
    assert_success
    assert_output --partial "MountSync (Profile: default)"
    assert_output --partial "def.conf [OK]"
    assert_output --partial "MountSync (Profile: work)"
    assert_output --partial "work.conf [OK]"
}

@test "Tree: --json outputs valid JSON structure" {
    echo "test" > "$HOME/app.conf"
    run mosy add "$HOME/app.conf" -t app -g tools
    assert_success

    run mosy tree --json
    assert_success
    assert_output --partial '"profiles":['
    assert_output --partial '"profile":"default"'
    assert_output --partial '"path":"~/.app.conf"' || assert_output --partial '"path":"~/app.conf"'
    assert_output --partial '"status":"OK"'
    assert_output --partial '"tags":["app"]'
    assert_output --partial '"groups":["tools"]'
}

@test "Tree: Respects tag and group filters" {
    echo "work" > "$HOME/work.conf"
    echo "home" > "$HOME/home.conf"
    run mosy add "$HOME/work.conf" -t work -g dev
    run mosy add "$HOME/home.conf" -t home -g dev
    assert_success

    run mosy tree -t work --no-color
    assert_success
    assert_output --partial "work.conf"
    refute_output --partial "home.conf"
}

@test "Tree: Empty profile reports no managed items" {
    run mosy tree --no-color
    assert_success
    assert_output --partial "MountSync (Profile: default)"
    assert_output --partial "(no managed items)"
}
