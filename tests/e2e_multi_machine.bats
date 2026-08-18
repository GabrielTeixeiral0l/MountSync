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

# Helper to scaffold a real full application
scaffold_real_app() {
    local base_dir="$1"
    local app_dir="$base_dir/my_large_app"
    mkdir -p "$app_dir"/{config,src/controllers,src/models,src/services,src/utils,public,logs,node_modules/lodash,dist}

    # 1. Private / Ignored files
    echo "DB_PASS=supersecret" > "$app_dir/.env"
    echo "SECRET_KEY=local_key" > "$app_dir/.env.local"
    echo -e ".env*\ndist\ndist/*\nlogs\nlogs/*\n*.tmp" > "$app_dir/.mosyignore"
    echo "bundle minified" > "$app_dir/dist/bundle.js"
    echo "temp build" > "$app_dir/dist/build.tmp"
    echo "[INFO] server running" > "$app_dir/logs/server.log"
    echo "module.exports = {};" > "$app_dir/node_modules/lodash/index.js"

    # 2. Configs
    echo '{"database": "production", "port": 5432}' > "$app_dir/config/database.json"
    echo 'theme: dark' > "$app_dir/config/settings.yaml"
    echo '{"api": "/v1"}' > "$app_dir/config/routes.json"
    echo '{"name": "my-large-app", "version": "1.0.0"}' > "$app_dir/package.json"

    # 3. Source code files
    echo 'import { UserController } from "./controllers/user";' > "$app_dir/src/index.js"
    echo 'export const UserController = { get: () => {} };' > "$app_dir/src/controllers/user.js"
    echo 'export const AuthController = { login: () => {} };' > "$app_dir/src/controllers/auth.js"
    echo 'export const UserModel = { find: () => {} };' > "$app_dir/src/models/user.js"
    echo 'export const ApiService = { request: () => {} };' > "$app_dir/src/services/api.js"
    echo 'export const sum = (a, b) => a + b;' > "$app_dir/src/utils/math.js"
    echo '<!DOCTYPE html><html><body>App</body></html>' > "$app_dir/public/index.html"

    # 4. Git repo
    (
        cd "$app_dir"
        git init -b main >/dev/null 2>&1
        git config user.email "tester@example.com"
        git config user.name "Tester"
        git add . >/dev/null 2>&1
        git commit -m "Initial real app commit" >/dev/null 2>&1
    )
}

@test "E2E: Scenario 1 - Full real-app lifecycle (add on PC1, init on PC2, remove on PC1, independence on PC2)" {
    # 1. PC1 scaffolds large app and runs mosy add
    scaffold_real_app "$PC1_HOME"
    
    HOME="$PC1_HOME" run ./mosy add "$PC1_HOME/my_large_app"
    [ "$status" -eq 0 ]

    # Verify PC1 local state
    [ -d "$PC1_HOME/my_large_app/.git" ]
    [ -f "$PC1_HOME/my_large_app/.env" ]
    [ ! -L "$PC1_HOME/my_large_app/.env" ]
    [ -d "$PC1_HOME/my_large_app/node_modules/lodash" ]
    [ ! -L "$PC1_HOME/my_large_app/node_modules/lodash/index.js" ]
    [ -L "$PC1_HOME/my_large_app/src/index.js" ]
    [ -L "$PC1_HOME/my_large_app/config/database.json" ]

    # Verify Cloud Vault state (only non-ignored items uploaded)
    [ ! -e "$MOSY_CLOUD_DIR/my_large_app/.git" ]
    [ ! -e "$MOSY_CLOUD_DIR/my_large_app/.env" ]
    [ ! -e "$MOSY_CLOUD_DIR/my_large_app/node_modules" ]
    [ ! -e "$MOSY_CLOUD_DIR/my_large_app/logs" ]
    [ -f "$MOSY_CLOUD_DIR/my_large_app/src/index.js" ]
    [ -f "$MOSY_CLOUD_DIR/my_large_app/config/database.json" ]

    # 2. PC2 synchronizes from cloud vault via mosy init
    HOME="$PC2_HOME" run ./mosy init
    [ "$status" -eq 0 ]

    # Verify PC2 received cloud files as symlinks
    [ -L "$PC2_HOME/my_large_app/src/index.js" ]
    [ -L "$PC2_HOME/my_large_app/config/database.json" ]
    [ -L "$PC2_HOME/my_large_app/src/controllers/user.js" ]
    # Verify PC2 did NOT get PC1's private files
    [ ! -e "$PC2_HOME/my_large_app/.env" ]
    [ ! -e "$PC2_HOME/my_large_app/.git" ]

    # 3. PC1 removes app from MountSync (mosy remove)
    HOME="$PC1_HOME" run ./mosy remove "$PC1_HOME/my_large_app"
    [ "$status" -eq 0 ]

    # Verify PC1 files are reverted to regular local files
    [ ! -L "$PC1_HOME/my_large_app/src/index.js" ]
    [ -f "$PC1_HOME/my_large_app/src/index.js" ]
    [ -f "$PC1_HOME/my_large_app/.env" ]
    [ -d "$PC1_HOME/my_large_app/.git" ]

    # Verify Cloud Vault still has the files for PC2!
    [ -f "$MOSY_CLOUD_DIR/my_large_app/src/index.js" ]
    [ -L "$PC2_HOME/my_large_app/src/index.js" ]
    [ "$(cat "$PC2_HOME/my_large_app/src/index.js")" = "$(cat "$PC1_HOME/my_large_app/src/index.js")" ]

    # 4. PC2 independently unmanages app
    # First re-ensure map is present for PC2 test
    echo "my_large_app|my_large_app" > "$MOSY_CLOUD_DIR/sync-map.conf"
    HOME="$PC2_HOME" run ./mosy remove "$PC2_HOME/my_large_app"
    [ "$status" -eq 0 ]
    [ ! -L "$PC2_HOME/my_large_app/src/index.js" ]
    [ -f "$PC2_HOME/my_large_app/src/index.js" ]
}

@test "E2E: Scenario 2 - Live bi-directional synchronization propagation between PC1 and PC2" {
    scaffold_real_app "$PC1_HOME"
    HOME="$PC1_HOME" run ./mosy add "$PC1_HOME/my_large_app"
    [ "$status" -eq 0 ]

    HOME="$PC2_HOME" run ./mosy init
    [ "$status" -eq 0 ]

    # PC1 modifies src/index.js
    echo '// Modified by PC1' >> "$PC1_HOME/my_large_app/src/index.js"

    # PC2 reads src/index.js immediately
    run grep "// Modified by PC1" "$PC2_HOME/my_large_app/src/index.js"
    [ "$status" -eq 0 ]

    # PC2 modifies config/settings.yaml
    echo "custom_pc2_setting: true" >> "$PC2_HOME/my_large_app/config/settings.yaml"

    # PC1 reads config/settings.yaml immediately
    run grep "custom_pc2_setting: true" "$PC1_HOME/my_large_app/config/settings.yaml"
    [ "$status" -eq 0 ]
}

@test "E2E: Scenario 3 - Conflict resolution with automatic backup on PC2 during init" {
    scaffold_real_app "$PC1_HOME"
    HOME="$PC1_HOME" run ./mosy add "$PC1_HOME/my_large_app"
    [ "$status" -eq 0 ]

    # PC2 already has an existing local file with old config
    mkdir -p "$PC2_HOME/my_large_app/config"
    echo '{"database": "OLD_LOCAL_PC2_CONFIG"}' > "$PC2_HOME/my_large_app/config/database.json"

    # PC2 runs mosy init
    HOME="$PC2_HOME" run ./mosy init
    [ "$status" -eq 0 ]

    # Verify PC2 has the new cloud symlink
    [ -L "$PC2_HOME/my_large_app/config/database.json" ]

    # Verify PC2 old local file was backed up with .bak extension
    local backup_file
    backup_file=$(find "$PC2_HOME/my_large_app/config" -name "database.json.bak_*" | head -n 1)
    [ -n "$backup_file" ]
    [ -f "$backup_file" ]
    run grep "OLD_LOCAL_PC2_CONFIG" "$backup_file"
    [ "$status" -eq 0 ]
}

@test "E2E: Scenario 4 - Incremental file additions synced cleanly with mosy pull" {
    scaffold_real_app "$PC1_HOME"
    HOME="$PC1_HOME" run ./mosy add "$PC1_HOME/my_large_app"
    [ "$status" -eq 0 ]

    HOME="$PC2_HOME" run ./mosy init
    [ "$status" -eq 0 ]

    # Later, a new service is added directly to cloud vault
    mkdir -p "$MOSY_CLOUD_DIR/my_large_app/src/services"
    echo "export const AnalyticsService = {};" > "$MOSY_CLOUD_DIR/my_large_app/src/services/analytics.js"

    # PC2 runs mosy pull
    HOME="$PC2_HOME" run ./mosy pull
    [ "$status" -eq 0 ]

    # PC2 receives the new linked file
    [ -L "$PC2_HOME/my_large_app/src/services/analytics.js" ]
    run grep "AnalyticsService" "$PC2_HOME/my_large_app/src/services/analytics.js"
    [ "$status" -eq 0 ]
}

@test "E2E: Scenario 5 - Selective syncing using tags and groups between machines" {
    scaffold_real_app "$PC1_HOME"
    HOME="$PC1_HOME" run ./mosy add "$PC1_HOME/my_large_app" --tag dev,backend --group workstations
    [ "$status" -eq 0 ]

    # PC2 only wants 'backend' tag
    HOME="$PC2_HOME" run ./mosy init --tag backend
    [ "$status" -eq 0 ]
    [ -d "$PC2_HOME/my_large_app" ]

    # Machine 3 only asks for 'mobile' tag (should skip)
    export PC3_HOME="$TEST_HOME/pc3"
    mkdir -p "$PC3_HOME"
    HOME="$PC3_HOME" run ./mosy init --tag mobile
    [ "$status" -eq 0 ]
    [ ! -d "$PC3_HOME/my_large_app" ]
}

@test "E2E: Scenario 6 - Multi-profile isolation (-p work vs -p personal)" {
    mkdir -p "$PC1_HOME/work_app" "$PC1_HOME/personal_app"
    echo "work_config" > "$PC1_HOME/work_app/config.txt"
    echo "personal_config" > "$PC1_HOME/personal_app/config.txt"

    # Add to work profile
    HOME="$PC1_HOME" run ./mosy -p work add "$PC1_HOME/work_app"
    [ "$status" -eq 0 ]

    # Add to personal profile
    HOME="$PC1_HOME" run ./mosy -p personal add "$PC1_HOME/personal_app"
    [ "$status" -eq 0 ]

    # Verify vault isolation in separate profile directories
    [ -f "$MOSY_CLOUD_DIR/profiles/work/work_app/config.txt" ]
    [ -f "$MOSY_CLOUD_DIR/profiles/work/sync-map.conf" ]
    [ -f "$MOSY_CLOUD_DIR/profiles/personal/personal_app/config.txt" ]
    [ -f "$MOSY_CLOUD_DIR/profiles/personal/sync-map.conf" ]

    # PC2 inits work profile only
    HOME="$PC2_HOME" run ./mosy -p work init
    [ "$status" -eq 0 ]
    [ -L "$PC2_HOME/work_app/config.txt" ]
    [ ! -e "$PC2_HOME/personal_app" ]
}

@test "E2E: Scenario 7 - Safe error handling when cloud drive is unmounted" {
    scaffold_real_app "$PC1_HOME"
    
    # Simulate unmounted drive
    export MOSY_MOUNT_POINT="$TEST_HOME/NotMountedDrive"

    HOME="$PC1_HOME" run ./mosy add "$PC1_HOME/my_large_app"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Cloud drive is not mounted" ]]

    # Ensure local directory was NOT touched or modified
    [ ! -L "$PC1_HOME/my_large_app/src/index.js" ]
    [ -f "$PC1_HOME/my_large_app/src/index.js" ]
}
