#!/bin/bash

# MountSync - run_docker_tests.sh

IMAGE_NAME="mountsync-tester"

echo "Building Docker image..."
docker build -t $IMAGE_NAME tests/docker/

echo "Running tests in Docker..."
# --privileged is needed for fuse (mount) mocking/testing
docker run --rm --privileged \
    -v "$(pwd):/home/tester/mountsync" \
    $IMAGE_NAME
