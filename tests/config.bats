#!/usr/bin/env bats
setup() {
    load 'test_helper'
    common_setup
    source src/core.sh
    load_settings
}

@test "config: listing shows all Phase 1 variables with defaults" {
    run ./mosy config
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOSY_REMOTE_NAME"* ]]
    [[ "$output" == *"MOSY_LOG_LEVEL"* ]]
    [[ "$output" == *"Verbosity: INFO, DEBUG, SILENT"* ]]
    [[ "$output" == *"(Default: INFO)"* ]]
    [[ "$output" == *"(Default: false)"* ]]
}

@test "config: set updates MOSY_LOG_LEVEL with valid value" {
    run ./mosy config set MOSY_LOG_LEVEL DEBUG
    [ "$status" -eq 0 ]
    grep -q "MOSY_LOG_LEVEL=\"DEBUG\"" "$HOME/.config/mosy/config"
}

@test "config: set rejects invalid value for MOSY_LOG_LEVEL" {
    run ./mosy config set MOSY_LOG_LEVEL INVALID
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Invalid value"* ]]
}

@test "config: set rejects invalid boolean for MOSY_DRY_RUN" {
    run ./mosy config set MOSY_DRY_RUN maybe
    [ "$status" -eq 1 ]
}

@test "config: set updates MOSY_DRY_RUN with valid boolean" {
    run ./mosy config set MOSY_DRY_RUN true
    [ "$status" -eq 0 ]
    grep -q "MOSY_DRY_RUN=\"true\"" "$HOME/.config/mosy/config"
}

@test "config: set rejects unknown key" {
    run ./mosy config set UNKNOWN_KEY value
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Unknown configuration key 'UNKNOWN_KEY'"* ]]
}

@test "config: set updates MOSY_BACKUP_EXT (string)" {
    run ./mosy config set MOSY_BACKUP_EXT .bak2
    [ "$status" -eq 0 ]
    grep -q "MOSY_BACKUP_EXT=\".bak2\"" "$HOME/.config/mosy/config"
}

@test "config: set shows usage when args missing" {
    run ./mosy config set
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: mosy config set <KEY> <VALUE>"* ]]
}

@test "config: set handles values with double quotes" {
    run ./mosy config set MOSY_BACKUP_EXT 'quote"test'
    [ "$status" -eq 0 ]
    # Check the file content (escaped)
    grep -q 'MOSY_BACKUP_EXT="quote\\"test"' "$HOME/.config/mosy/config"
    
    # Verify it can be loaded back correctly and displayed
    unset MOSY_BACKUP_EXT
    run ./mosy config
    [ "$status" -eq 0 ]
    [[ "$output" == *'quote"test'* ]]
}
