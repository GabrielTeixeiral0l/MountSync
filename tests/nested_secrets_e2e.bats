#!/usr/bin/env bats

load 'test_helper.bash'

setup() {
    common_setup
    export SHARED_CLOUD="$TEST_HOME/SharedCloud"
    export MOSY_MOUNT_POINT="$SHARED_CLOUD"
    export MOSY_CLOUD_DIR="$SHARED_CLOUD/mosy_vault"
    mkdir -p "$MOSY_CLOUD_DIR"

    export PC1_HOME="$TEST_HOME/pc1"
    export PC2_HOME="$TEST_HOME/pc2"
    mkdir -p "$PC1_HOME" "$PC2_HOME"
}

# Scaffold deeply nested directory structure with secrets and cache interspersed
scaffold_deep_nested_app() {
    local base_dir="$1"
    local app_dir="$base_dir/.config/deep_app"
    mkdir -p "$app_dir"/core/auth/tokens "$app_dir"/core/auth/cache "$app_dir"/plugins/analytics

    # Global and local ignore patterns
    echo -e "*.secret\n*.key\ncache\ncache/*\n*.tmp" > "$app_dir/.mosyignore"

    # Top-level files
    echo "app_name: deep_app" > "$app_dir/config.yaml"
    echo "MASTER_KEY=pc1_super_secret" > "$app_dir/master.key"

    # Deeply nested files
    echo "export const AuthProvider = {};" > "$app_dir/core/auth/provider.js"
    echo "TOKEN=jwt_secret_token_123" > "$app_dir/core/auth/tokens/auth.secret"
    echo "CERTIFICATE_DATA" > "$app_dir/core/auth/tokens/public_cert.pem"
    echo "CACHED_BINARY_BLOB" > "$app_dir/core/auth/cache/session.tmp"

    # Plugin files
    echo "analytics_version: 1" > "$app_dir/plugins/analytics/plugin.json"
}

@test "NestedSecrets: Scenario 1 - Deeply nested app syncs permitted files and keeps all secrets local on PC1" {
    scaffold_deep_nested_app "$PC1_HOME"
    local app_dir="$PC1_HOME/.config/deep_app"

    # 1. PC1 runs mosy add on the deeply nested app
    HOME="$PC1_HOME" run ./mosy add "$app_dir"
    [ "$status" -eq 0 ]

    # 2. Verify PC1 local state: permitted files are symlinks, ignored files are REAL LOCAL FILES
    [ -L "$app_dir/config.yaml" ]
    [ -L "$app_dir/core/auth/provider.js" ]
    [ -L "$app_dir/core/auth/tokens/public_cert.pem" ]
    [ -L "$app_dir/plugins/analytics/plugin.json" ]

    # Ignored files MUST remain real local files (NOT symlinks)
    [ -f "$app_dir/master.key" ]
    [ ! -L "$app_dir/master.key" ]
    [ -f "$app_dir/core/auth/tokens/auth.secret" ]
    [ ! -L "$app_dir/core/auth/tokens/auth.secret" ]
    [ -f "$app_dir/core/auth/cache/session.tmp" ]
    [ ! -L "$app_dir/core/auth/cache/session.tmp" ]

    # 3. Verify Cloud Vault state: only permitted files exist in cloud
    [ -f "$MOSY_CLOUD_DIR/.config/deep_app/config.yaml" ]
    [ -f "$MOSY_CLOUD_DIR/.config/deep_app/core/auth/provider.js" ]
    [ -f "$MOSY_CLOUD_DIR/.config/deep_app/core/auth/tokens/public_cert.pem" ]
    [ -f "$MOSY_CLOUD_DIR/.config/deep_app/plugins/analytics/plugin.json" ]

    # Secrets MUST NOT exist in cloud
    [ ! -e "$MOSY_CLOUD_DIR/.config/deep_app/master.key" ]
    [ ! -e "$MOSY_CLOUD_DIR/.config/deep_app/core/auth/tokens/auth.secret" ]
    [ ! -e "$MOSY_CLOUD_DIR/.config/deep_app/core/auth/cache" ]
}

@test "NestedSecrets: Scenario 2 - PC2 inits from cloud: receives code tree but does NOT receive PC1 secrets" {
    scaffold_deep_nested_app "$PC1_HOME"
    HOME="$PC1_HOME" run ./mosy add "$PC1_HOME/.config/deep_app"
    [ "$status" -eq 0 ]

    # PC2 runs mosy init
    HOME="$PC2_HOME" run ./mosy init
    [ "$status" -eq 0 ]
    local pc2_app="$PC2_HOME/.config/deep_app"

    # PC2 has the nested directory structure and symlinks to cloud files
    [ -L "$pc2_app/config.yaml" ]
    [ -L "$pc2_app/core/auth/provider.js" ]
    [ -L "$pc2_app/core/auth/tokens/public_cert.pem" ]
    [ -L "$pc2_app/plugins/analytics/plugin.json" ]

    # PC2 DOES NOT have PC1's secrets
    [ ! -e "$pc2_app/master.key" ]
    [ ! -e "$pc2_app/core/auth/tokens/auth.secret" ]
    [ ! -e "$pc2_app/core/auth/cache" ]

    # PC2 creates its own local secret
    echo "PC2_EXCLUSIVE_SECRET=999" > "$pc2_app/master.key"
    [ -f "$pc2_app/master.key" ]
    [ ! -L "$pc2_app/master.key" ]
    [ ! -e "$MOSY_CLOUD_DIR/.config/deep_app/master.key" ]
}

@test "NestedSecrets: Scenario 3 - Full removal on PC1 preserves all nested local secrets without data loss" {
    scaffold_deep_nested_app "$PC1_HOME"
    local app_dir="$PC1_HOME/.config/deep_app"

    HOME="$PC1_HOME" run ./mosy add "$app_dir"
    [ "$status" -eq 0 ]

    # PC1 runs mosy remove
    HOME="$PC1_HOME" run ./mosy remove "$app_dir"
    [ "$status" -eq 0 ]

    # Permitted files are reverted to regular local files
    [ ! -L "$app_dir/config.yaml" ]
    [ -f "$app_dir/config.yaml" ]
    [ ! -L "$app_dir/core/auth/provider.js" ]
    [ -f "$app_dir/core/auth/provider.js" ]
    [ ! -L "$app_dir/core/auth/tokens/public_cert.pem" ]
    [ -f "$app_dir/core/auth/tokens/public_cert.pem" ]

    # All nested ignored secrets remain 100% intact and uncorrupted
    [ -f "$app_dir/master.key" ]
    [ "$(cat "$app_dir/master.key")" = "MASTER_KEY=pc1_super_secret" ]
    [ -f "$app_dir/core/auth/tokens/auth.secret" ]
    [ "$(cat "$app_dir/core/auth/tokens/auth.secret")" = "TOKEN=jwt_secret_token_123" ]
    [ -f "$app_dir/core/auth/cache/session.tmp" ]
    [ "$(cat "$app_dir/core/auth/cache/session.tmp")" = "CACHED_BINARY_BLOB" ]
}
