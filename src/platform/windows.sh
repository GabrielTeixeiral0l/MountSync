#!/usr/bin/env bash
# MountSync - src/platform/windows.sh
# Platform adapter for Windows (Git Bash / MSYS2 / Native Shims)

# Enable native Windows NTFS symlinks in Git Bash
export MSYS="winsymlinks:nativestrict"

platform_is_mounted() {
    local target="${1:-$MOSY_MOUNT_POINT}"
    if [ -d "$target" ]; then
        if pgrep -f "rclone.*mount.*${MOSY_REMOTE_NAME:-}" >/dev/null 2>&1; then
            return 0
        elif [ -f "$target/.mountsync_keep" ] || [ -d "$target/mosy_vault" ]; then
            return 0
        fi
    fi
    return 1
}

platform_service_type() {
    echo "windows-background"
}

platform_service_status() {
    if pgrep -f "rclone.*mount" >/dev/null 2>&1; then
        echo "active"
    else
        echo "inactive"
    fi
}

platform_service_start() {
    local runner_vbs="${HOME}/.config/mosy/mount-runner.vbs"
    local runner_cmd="${HOME}/.config/mosy/mount-runner.cmd"
    if [ -f "$runner_vbs" ] && command -v wscript.exe >/dev/null 2>&1; then
        wscript.exe "$runner_vbs" >/dev/null 2>&1 || return 1
    elif [ -f "$runner_cmd" ]; then
        if command -v cmd.exe >/dev/null 2>&1; then
            cmd.exe /c start "" /min "$runner_cmd" >/dev/null 2>&1 || return 1
        else
            bash "$runner_cmd" &
        fi
    fi
}

platform_service_stop() {
    pkill -f "rclone.*mount" >/dev/null 2>&1 || true
}

platform_service_enable() {
    local runner_vbs="${HOME}/.config/mosy/mount-runner.vbs"
    if [ -f "$runner_vbs" ] && command -v cmd.exe >/dev/null 2>&1; then
        local startup_dir
        startup_dir=$(cmd.exe /c "echo %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup" 2>/dev/null | tr -d '\r\n')
        if [ -n "$startup_dir" ] && [ -d "$startup_dir" ]; then
            cp "$runner_vbs" "$startup_dir/mosy-mount.vbs" 2>/dev/null || true
        fi
    fi
}

platform_service_disable() {
    if command -v cmd.exe >/dev/null 2>&1; then
        local startup_dir
        startup_dir=$(cmd.exe /c "echo %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup" 2>/dev/null | tr -d '\r\n')
        if [ -n "$startup_dir" ] && [ -d "$startup_dir" ]; then
            rm -f "$startup_dir/mosy-mount.vbs" 2>/dev/null || true
        fi
    fi
}

platform_service_reload() {
    true
}

platform_service_file() {
    echo "${HOME}/.config/mosy/mount-runner.cmd"
}

platform_service_hint() {
    echo "Try running: ${HOME}/.config/mosy/mount-runner.cmd"
}

platform_create_service() {
    local remote="$1"
    local mount_pt="$2"
    local config_dir="${HOME}/.config/mosy"
    local runner_cmd="$config_dir/mount-runner.cmd"
    local runner_vbs="$config_dir/mount-runner.vbs"
    local rclone_bin
    rclone_bin=$(command -v rclone 2>/dev/null || echo "rclone")

    mkdir -p "$config_dir" || return 1
    mkdir -p "$mount_pt" 2>/dev/null || true

    cat <<EOF > "$runner_cmd" || return 1
@echo off
REM MountSync Windows Background Mount Runner
"$rclone_bin" mount "${remote}:" "${mount_pt}" --vfs-cache-mode writes
EOF

    # VBScript for invisible silent execution on Windows login/startup
    cat <<EOF > "$runner_vbs" || return 1
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run chr(34) & "${runner_cmd}" & chr(34), 0
Set WshShell = Nothing
EOF
}

platform_uninstall_service() {
    platform_service_stop
    platform_service_disable
    rm -f "${HOME}/.config/mosy/mount-runner.cmd" "${HOME}/.config/mosy/mount-runner.vbs"
}

platform_create_shims() {
    local bin_dir="$1"
    local mosy_script="$2"

    mkdir -p "$bin_dir" || return 1

    # Windows Command Prompt shim (mosy.cmd)
    cat <<'EOF' > "$bin_dir/mosy.cmd"
@echo off
setlocal
set MSYS=winsymlinks:nativestrict
bash "%~dp0mosy" %*
EOF
    chmod +x "$bin_dir/mosy.cmd" 2>/dev/null || true

    # Windows PowerShell shim (mosy.ps1)
    cat <<'EOF' > "$bin_dir/mosy.ps1"
$env:MSYS = "winsymlinks:nativestrict"
& bash "$PSScriptRoot/mosy" @args
EOF
}
