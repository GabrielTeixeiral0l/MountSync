#!/bin/bash

# MountSync - run_docker_tests.sh

IMAGE_NAME="mountsync-tester"

echo "Building Docker image..."
docker build -t $IMAGE_NAME tests/docker/

echo "Running tests in Docker..."
# --privileged is needed for fuse (mount) mocking/testing
docker run --rm --privileged \
    -v "$(pwd):/home/tester/mountsync" \
    $IMAGE_NAME \
    ./tests/libs/bats-core/bin/bats tests/backup.bats tests/clean.bats tests/commands.bats tests/config.bats tests/core.bats tests/diff.bats tests/doctor.bats tests/e2e_multi_machine.bats tests/edge_cases.bats tests/edit.bats tests/history_rollback.bats tests/ignore.bats tests/info.bats tests/install.bats tests/list_status.bats tests/logging.bats tests/nested_secrets_e2e.bats tests/real_app_system.bats tests/regressions.bats tests/remove.bats tests/safety.bats tests/secrets.bats tests/settings.bats tests/status_json.bats tests/tags_groups.bats tests/tree.bats tests/uninstall.bats tests/which.bats
