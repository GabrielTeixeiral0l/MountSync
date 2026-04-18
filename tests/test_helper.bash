#!/usr/bin/env bash

setup() {
    # 1. Load BATS helpers
    load 'libs/bats-support/load'
    load 'libs/bats-assert/load'
    load 'libs/bats-file/load'

    # 2. Virtual Home Isolation
    export TEST_HOME=$(mktemp -d)
    export HOME="$TEST_HOME"
    
    # 3. Path setup for testing
    export PROJECT_ROOT="$(pwd)"
    export PATH="$PROJECT_ROOT/tests/mock_bin:$PROJECT_ROOT:$PATH"
    
    # We DON'T export CSYNC variables by default here to test fallbacks
}

teardown() {
    rm -rf "$TEST_HOME"
}
