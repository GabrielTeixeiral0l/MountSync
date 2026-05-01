#!/bin/bash
# src/commands/update.sh

command_update() {
    local install_dir
    install_dir=$(dirname "$(realpath "$0")")
    
    # 1. Safety check
    if ! git -C "$install_dir" diff-index --quiet HEAD --; then
        echo "Error: Local changes detected in $install_dir. Please commit or stash them first."
        return 1
    fi
    
    local old_sha
    old_sha=$(git -C "$install_dir" rev-parse HEAD)
    
    echo "Checking for updates..."
    git -C "$install_dir" fetch origin main
    
    local remote_sha
    remote_sha=$(git -C "$install_dir" rev-parse origin/main)
    
    if [ "$old_sha" == "$remote_sha" ]; then
        echo "MountSync is already up to date."
        return 0
    fi
    
    echo "New version available. Updating..."
    
    # 2. Execution block
    if git -C "$install_dir" pull origin main && bash "$install_dir/install.sh" --update; then
        echo "Update successful!"
    else
        echo "Error: Update failed. Rolling back..."
        git -C "$install_dir" reset --hard "$old_sha"
        bash "$install_dir/install.sh" --update
        return 1
    fi
}
