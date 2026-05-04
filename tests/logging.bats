#!/usr/bin/env bats
setup() { source src/core.sh; export MOSY_REMOTE_NAME="test"; load_settings; }

@test "logging: log_info prints in INFO level" {
    export MOSY_LOG_LEVEL="INFO"
    run log_info "test message"
    [ "$output" == "test message" ]
}

@test "logging: log_debug is silent in INFO level" {
    export MOSY_LOG_LEVEL="INFO"
    run log_debug "secret"
    [ "$output" == "" ]
}

@test "logging: log_error always prints to stderr" {
    run log_error "error message"
    [ "${lines[0]}" == "error message" ]
}
