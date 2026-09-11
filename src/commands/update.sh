#!/bin/bash

cmd_update() {
    echo "Updating MountSync..."

    # If running on Windows installed via PowerShell archive
    if [ "${MOSY_OS:-}" = "windows" ] && [ ! -d "$HOME/.mountsync/.git" ]; then
        if command -v powershell.exe >/dev/null 2>&1; then
            echo "Fetching latest MountSync package for Windows..."
            powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '
                $b = if ($env:MOSY_BRANCH) { $env:MOSY_BRANCH } else { "test-windows" }
                & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/GabrielTeixeiral0l/MountSync/$b/install.ps1"))) -Branch $b -NonInteractive
            '
            return $?
        fi
    fi

    local repo_dir="$HOME/.mountsync"
    if [ ! -d "$repo_dir" ]; then
        echo "Error: installation repository not found at $repo_dir"
        exit 1
    fi
    cd "$repo_dir"
    local current_commit
    current_commit=$(git rev-parse HEAD 2>/dev/null || echo "")
    local target_branch="main"
    if git branch -r | grep -q "origin/test-windows"; then
        target_branch="test-windows"
    fi
    if ! git pull origin "$target_branch" 2>/dev/null && ! git pull origin main; then
        echo "Error: Pull failed. Rolling back..."
        [ -n "$current_commit" ] && git reset --hard "$current_commit"
        exit 1
    fi
    if [ -f "install.sh" ]; then
        if ! bash install.sh --update; then
            echo "Error: Installation failed. Rolling back..."
            [ -n "$current_commit" ] && git reset --hard "$current_commit"
            bash install.sh --update
            exit 1
        fi
    fi
    echo "Update complete!"
}
