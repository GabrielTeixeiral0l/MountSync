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

# Helper simulating a real CLI tool that reads/writes configs in ~/.config/mytool/config.ini
create_mock_app_binary() {
    local bin_dir="$1"
    mkdir -p "$bin_dir"
    cat << 'APP_EOF' > "$bin_dir/mytool"
#!/bin/bash
# Mock application simulating a real CLI tool
CONFIG_FILE="${HOME}/.config/mytool/config.ini"

if [[ "$1" == "--get-theme" ]]; then
    if [ -e "$CONFIG_FILE" ]; then
        grep "^theme=" "$CONFIG_FILE" | cut -d'=' -f2
        exit 0
    else
        echo "default"
        exit 0
    fi
elif [[ "$1" == "--set-theme" ]]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    if [ -e "$CONFIG_FILE" ]; then
        sed -i --follow-symlinks "s/^theme=.*/theme=$2/" "$CONFIG_FILE" 2>/dev/null || echo "theme=$2" > "$CONFIG_FILE"
    else
        echo "theme=$2" > "$CONFIG_FILE"
    fi
    exit 0
elif [[ "$1" == "--init-default" ]]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo -e "theme=factory_default\nversion=1.0.0" > "$CONFIG_FILE"
    exit 0
fi
APP_EOF
    chmod +x "$bin_dir/mytool"
}

@test "RealApp: Scenario 1 - Configs synced before app installation, app discovers configs on first launch" {
    local pc1_bin="$TEST_HOME/pc1_bin"
    local pc2_bin="$TEST_HOME/pc2_bin"
    create_mock_app_binary "$pc1_bin"
    # Note: pc2_bin is NOT created yet (app is NOT installed on PC2)

    # 1. PC1 configures app theme to 'cyberpunk' and syncs with mosy
    PATH="$pc1_bin:$PATH" HOME="$PC1_HOME" mytool --set-theme "cyberpunk"
    [ "$(PATH="$pc1_bin:$PATH" HOME="$PC1_HOME" mytool --get-theme)" = "cyberpunk" ]

    HOME="$PC1_HOME" run ./mosy add "$PC1_HOME/.config/mytool"
    [ "$status" -eq 0 ]
    [ -L "$PC1_HOME/.config/mytool/config.ini" ]

    # 2. PC2 runs mosy init BEFORE installing the app
    HOME="$PC2_HOME" run ./mosy init
    [ "$status" -eq 0 ]
    [ -L "$PC2_HOME/.config/mytool/config.ini" ]

    # 3. Now the user installs the app on PC2
    create_mock_app_binary "$pc2_bin"

    # 4. App is executed for the very first time on PC2
    local pc2_theme
    pc2_theme=$(PATH="$pc2_bin:$PATH" HOME="$PC2_HOME" mytool --get-theme)
    [ "$pc2_theme" = "cyberpunk" ]
}

@test "RealApp: Scenario 2 - App installed first on PC2 with factory defaults, mosy init safely backs up factory config" {
    local pc1_bin="$TEST_HOME/pc1_bin"
    local pc2_bin="$TEST_HOME/pc2_bin"
    create_mock_app_binary "$pc1_bin"
    create_mock_app_binary "$pc2_bin"

    # 1. PC1 sets custom config
    PATH="$pc1_bin:$PATH" HOME="$PC1_HOME" mytool --set-theme "dracula"
    HOME="$PC1_HOME" run ./mosy add "$PC1_HOME/.config/mytool"
    [ "$status" -eq 0 ]

    # 2. PC2 installs and runs the app FIRST (generating factory default configs)
    PATH="$pc2_bin:$PATH" HOME="$PC2_HOME" mytool --init-default
    [ "$(PATH="$pc2_bin:$PATH" HOME="$PC2_HOME" mytool --get-theme)" = "factory_default" ]
    [ ! -L "$PC2_HOME/.config/mytool/config.ini" ]

    # 3. PC2 connects to MountSync via mosy init
    HOME="$PC2_HOME" run ./mosy init
    [ "$status" -eq 0 ]

    # 4. Verify cloud config is active on PC2
    [ -L "$PC2_HOME/.config/mytool/config.ini" ]
    [ "$(PATH="$pc2_bin:$PATH" HOME="$PC2_HOME" mytool --get-theme)" = "dracula" ]

    # 5. Verify factory default config was NOT lost (saved to .bak)
    local bak_file
    bak_file=$(find "$PC2_HOME/.config/mytool" -name "config.ini.bak_*" | head -n 1)
    [ -n "$bak_file" ]
    [ -f "$bak_file" ]
    run grep "factory_default" "$bak_file"
    [ "$status" -eq 0 ]
}

@test "RealApp: Scenario 3 - Live settings modification propagated between running apps on both PCs" {
    local pc1_bin="$TEST_HOME/pc1_bin"
    local pc2_bin="$TEST_HOME/pc2_bin"
    create_mock_app_binary "$pc1_bin"
    create_mock_app_binary "$pc2_bin"

    # Setup synced app on both machines
    PATH="$pc1_bin:$PATH" HOME="$PC1_HOME" mytool --set-theme "solarized"
    HOME="$PC1_HOME" run ./mosy add "$PC1_HOME/.config/mytool"
    [ "$status" -eq 0 ]

    HOME="$PC2_HOME" run ./mosy init
    [ "$status" -eq 0 ]

    # PC1 changes theme to 'nord'
    PATH="$pc1_bin:$PATH" HOME="$PC1_HOME" mytool --set-theme "nord"

    # PC2 app reads theme immediately
    [ "$(PATH="$pc2_bin:$PATH" HOME="$PC2_HOME" mytool --get-theme)" = "nord" ]

    # PC2 changes theme to 'gruvbox'
    PATH="$pc2_bin:$PATH" HOME="$PC2_HOME" mytool --set-theme "gruvbox"

    # PC1 app reads theme immediately
    [ "$(PATH="$pc1_bin:$PATH" HOME="$PC1_HOME" mytool --get-theme)" = "gruvbox" ]
}
