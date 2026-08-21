#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    load 'test_helper.bash'
    common_setup
    export MOSY_MOUNT_POINT="$HOME/Cloud"
    export MOSY_CLOUD_DIR="$MOSY_MOUNT_POINT/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"
}

@test "Secrets: By default (MOSY_SCAN_SECRETS=false), adds file with secret without prompt" {
    cat <<EOF > "$HOME/id_rsa"
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
-----END OPENSSH PRIVATE KEY-----
EOF

    run mosy add "$HOME/id_rsa"
    assert_success
    assert_output --partial "Success! id_rsa is now synced."
    [ -f "$MOSY_CLOUD_DIR/id_rsa" ]
    [ -L "$HOME/id_rsa" ]
}

@test "Secrets: --scan-secrets flag detects private key and aborts in non-interactive mode" {
    cat <<EOF > "$HOME/my_rsa_key"
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0Yq...
-----END RSA PRIVATE KEY-----
EOF

    run bash -c "mosy add --scan-secrets '$HOME/my_rsa_key' < /dev/null"
    assert_failure
    assert_output --partial "Potential secret detected"
    assert_output --partial "Unencrypted Private Key"
    assert_output --partial "Aborting sync to prevent cloud secret leak"
    [ ! -e "$MOSY_CLOUD_DIR/my_rsa_key" ]
    [ ! -L "$HOME/my_rsa_key" ]
}

@test "Secrets: --scan flag detects AWS access key (AKIA...)" {
    local prefix="AKIA"
    cat <<EOF > "$HOME/aws_config"
[default]
aws_access_key_id = ${prefix}IOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
EOF

    run bash -c "mosy add --scan '$HOME/aws_config' < /dev/null"
    assert_failure
    assert_output --partial "AWS Access Key ID"
    [ ! -e "$MOSY_CLOUD_DIR/aws_config" ]
}

@test "Secrets: --scan flag detects GitHub PAT tokens" {
    local prefix="ghp_"
    cat <<EOF > "$HOME/gh_token.txt"
GITHUB_TOKEN="${prefix}123456789012345678901234567890123456"
EOF

    run bash -c "mosy add --scan '$HOME/gh_token.txt' < /dev/null"
    assert_failure
    assert_output --partial "GitHub Access Token"
    [ ! -e "$MOSY_CLOUD_DIR/gh_token.txt" ]
}

@test "Secrets: --scan flag detects Slack token and Stripe secret key" {
    local slack_pre="xoxb-"
    local stripe_pre="sk_live_"
    cat <<EOF > "$HOME/tokens.txt"
SLACK_BOT_TOKEN="${slack_pre}123456789012-1234567890123-abcdefghijklmnopqrstuvwx"
STRIPE_SECRET="${stripe_pre}1234567890abcdefghijklmn"
EOF

    run bash -c "mosy add --scan '$HOME/tokens.txt' < /dev/null"
    assert_failure
    assert_output --partial "Slack API Token"
    [ ! -e "$MOSY_CLOUD_DIR/tokens.txt" ]
}

@test "Secrets: Sensitive filenames (.env, id_rsa, id_ed25519) trigger warning" {
    touch "$HOME/.env"
    touch "$HOME/id_ed25519"

    run bash -c "mosy add --scan '$HOME/.env' < /dev/null"
    assert_failure
    assert_output --partial "High-risk sensitive filename pattern"

    run bash -c "mosy add --scan '$HOME/id_ed25519' < /dev/null"
    assert_failure
    assert_output --partial "High-risk sensitive filename pattern"
}

@test "Secrets: Interactive prompt accepts 'y' and syncs single file" {
    cat <<EOF > "$HOME/test_secret.txt"
api_key = "abcdef123456"
EOF

    # Simulate typing 'y' into stdin
    run bash -c "echo 'y' | mosy add --scan '$HOME/test_secret.txt'"
    assert_success
    assert_output --partial "Success! test_secret.txt is now synced."
    [ -f "$MOSY_CLOUD_DIR/test_secret.txt" ]
    [ -L "$HOME/test_secret.txt" ]
}

@test "Secrets: Interactive prompt rejects 'n' and aborts addition" {
    cat <<EOF > "$HOME/test_secret.txt"
api_key = "abcdef123456"
EOF

    # Simulate typing 'n' into stdin
    run bash -c "echo 'n' | mosy add --scan '$HOME/test_secret.txt'"
    assert_failure
    assert_output --partial "Sync cancelled by user."
    [ ! -e "$MOSY_CLOUD_DIR/test_secret.txt" ]
    [ ! -L "$HOME/test_secret.txt" ]
}

@test "Secrets: Directory addition - user chooses 's' (skip) to keep secret files local and sync others" {
    mkdir -p "$HOME/myapp"
    echo "normal config" > "$HOME/myapp/config.json"
    echo "SECRET_KEY=supersecret12345" > "$HOME/myapp/.env"
    echo "normal readme" > "$HOME/myapp/README.md"

    # Simulate typing 's' (skip) into stdin
    run bash -c "echo 's' | mosy add --scan '$HOME/myapp'"
    assert_success
    assert_output --partial "Skipping secret file (kept local): .env"
    assert_output --partial "Success! myapp is now synced."

    # Normal files synced & linked
    [ -f "$MOSY_CLOUD_DIR/myapp/config.json" ]
    [ -L "$HOME/myapp/config.json" ]
    [ -f "$MOSY_CLOUD_DIR/myapp/README.md" ]
    [ -L "$HOME/myapp/README.md" ]

    # Secret file preserved locally, NOT in cloud vault, NOT a symlink
    [ ! -e "$MOSY_CLOUD_DIR/myapp/.env" ]
    [ ! -L "$HOME/myapp/.env" ]
    [ -f "$HOME/myapp/.env" ]
    grep -q "supersecret12345" "$HOME/myapp/.env"
}

@test "Secrets: Directory addition - user chooses 'y' syncs everything including secrets" {
    mkdir -p "$HOME/myapp_all"
    echo "normal config" > "$HOME/myapp_all/config.json"
    echo "SECRET_KEY=supersecret12345" > "$HOME/myapp_all/.env"

    # Simulate typing 'y' into stdin
    run bash -c "echo 'y' | mosy add --scan '$HOME/myapp_all'"
    assert_success
    assert_output --partial "Success! myapp_all is now synced."

    [ -f "$MOSY_CLOUD_DIR/myapp_all/config.json" ]
    [ -L "$HOME/myapp_all/config.json" ]
    [ -f "$MOSY_CLOUD_DIR/myapp_all/.env" ]
    [ -L "$HOME/myapp_all/.env" ]
}

@test "Secrets: Directory addition - user chooses 'n' cancels entire operation" {
    mkdir -p "$HOME/myapp_cancel"
    echo "normal config" > "$HOME/myapp_cancel/config.json"
    echo "SECRET_KEY=supersecret12345" > "$HOME/myapp_cancel/.env"

    # Simulate typing 'n' into stdin
    run bash -c "echo 'n' | mosy add --scan '$HOME/myapp_cancel'"
    assert_failure
    assert_output --partial "Sync cancelled by user."

    [ ! -e "$MOSY_CLOUD_DIR/myapp_cancel" ]
    [ ! -L "$HOME/myapp_cancel/config.json" ]
    [ ! -L "$HOME/myapp_cancel/.env" ]
}

@test "Secrets: --force / -f flag bypasses scan prompt" {
    cat <<EOF > "$HOME/forced_key.pem"
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0Yq...
-----END RSA PRIVATE KEY-----
EOF

    run mosy add --scan --force "$HOME/forced_key.pem"
    assert_success
    assert_output --partial "Success! forced_key.pem is now synced."
    [ -f "$MOSY_CLOUD_DIR/forced_key.pem" ]
    [ -L "$HOME/forced_key.pem" ]
}

@test "Secrets: --no-scan flag bypasses scanning when MOSY_SCAN_SECRETS=true" {
    export MOSY_SCAN_SECRETS="true"
    touch "$HOME/.env"

    run mosy add --no-scan "$HOME/.env"
    assert_success
    assert_output --partial "Success! .env is now synced."
    [ -f "$MOSY_CLOUD_DIR/.env" ]
    [ -L "$HOME/.env" ]
}

@test "Secrets: config set MOSY_SCAN_SECRETS true enables scanning globally" {
    run mosy config set MOSY_SCAN_SECRETS true
    assert_success

    touch "$HOME/.env"
    run bash -c "mosy add '$HOME/.env' < /dev/null"
    assert_failure
    assert_output --partial "Potential secret detected"
}

@test "Secrets: custom patterns in ~/.config/mosy/secrets.conf are honored" {
    mkdir -p "$HOME/.config/mosy"
    cat <<EOF > "$HOME/.config/mosy/secrets.conf"
# Custom secret patterns
file:custom_secret.conf
MY_CUSTOM_SECRET_[0-9]+
EOF

    echo "normal content" > "$HOME/custom_secret.conf"
    echo "MY_CUSTOM_SECRET_987654" > "$HOME/app.conf"

    run bash -c "mosy add --scan '$HOME/custom_secret.conf' < /dev/null"
    assert_failure
    assert_output --partial "High-risk sensitive filename pattern (custom_secret.conf)"

    run bash -c "mosy add --scan '$HOME/app.conf' < /dev/null"
    assert_failure
    assert_output --partial "Custom Secret Pattern"
}

@test "Secrets: skips binary files safely without error" {
    # Create mock binary file with null bytes
    printf "hello\x00world\x00password='123456'" > "$HOME/binary_file.bin"

    run mosy add --scan "$HOME/binary_file.bin"
    assert_success
    assert_output --partial "Success! binary_file.bin is now synced."
}

@test "Secrets: Directory addition aborts in non-interactive mode when secrets present" {
    mkdir -p "$HOME/dir_non_interactive"
    touch "$HOME/dir_non_interactive/config.txt"
    echo "password = 'secretpassword123'" > "$HOME/dir_non_interactive/secrets.txt"

    run bash -c "mosy add --scan '$HOME/dir_non_interactive' < /dev/null"
    assert_failure
    assert_output --partial "Potential secrets detected in directory"
    assert_output --partial "secrets.txt (Generic High-Risk Secret Assignment)"
    assert_output --partial "Aborting sync to prevent cloud secret leak (non-interactive)"
    [ ! -e "$MOSY_CLOUD_DIR/dir_non_interactive" ]
}

@test "Secrets: skips files larger than 1MB safely" {
    # Create a 1.2MB file containing secret string
    dd if=/dev/zero of="$HOME/large_file.txt" bs=1024 count=1200 2>/dev/null
    echo "password = 'secretpassword123'" >> "$HOME/large_file.txt"

    run mosy add --scan "$HOME/large_file.txt"
    assert_success
    assert_output --partial "Success! large_file.txt is now synced."
}

@test "Secrets: detects EC private key, OpenSSH key, and PGP private key block" {
    cat <<EOF > "$HOME/ec_key"
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEI...
-----END EC PRIVATE KEY-----
EOF
    run bash -c "mosy add --scan '$HOME/ec_key' < /dev/null"
    assert_failure
    assert_output --partial "Unencrypted Private Key"

    cat <<EOF > "$HOME/pgp_key"
-----BEGIN PGP PRIVATE KEY BLOCK-----
Version: GnuPG v2
-----END PGP PRIVATE KEY BLOCK-----
EOF
    run bash -c "mosy add --scan '$HOME/pgp_key' < /dev/null"
    assert_failure
    assert_output --partial "Unencrypted Private Key"
}

@test "Secrets: detects credentials.json, service_account.json, *.p12, and *.key" {
    touch "$HOME/credentials.json"
    touch "$HOME/service_account.json"
    touch "$HOME/server.p12"
    touch "$HOME/ssl.key"

    run bash -c "mosy add --scan '$HOME/credentials.json' < /dev/null"
    assert_failure
    assert_output --partial "High-risk sensitive filename pattern (credentials.json)"

    run bash -c "mosy add --scan '$HOME/service_account.json' < /dev/null"
    assert_failure
    assert_output --partial "High-risk sensitive filename pattern (service_account.json)"

    run bash -c "mosy add --scan '$HOME/server.p12' < /dev/null"
    assert_failure
    assert_output --partial "High-risk sensitive filename pattern (*.p12)"

    run bash -c "mosy add --scan '$HOME/ssl.key' < /dev/null"
    assert_failure
    assert_output --partial "High-risk sensitive filename pattern (*.key)"
}

@test "Secrets: config set MOSY_SCAN_SECRETS rejects invalid boolean" {
    run mosy config set MOSY_SCAN_SECRETS invalid_val
    assert_failure
    assert_output --partial "Error: Invalid value for MOSY_SCAN_SECRETS (expected true or false)"
}
