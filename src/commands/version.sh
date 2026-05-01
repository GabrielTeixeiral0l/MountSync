#!/bin/bash
# src/commands/version.sh

command_version() {
    local install_dir
    install_dir=$(dirname "$(realpath "$0")")
    local git_version
    git_version=$(git -C "$install_dir" describe --tags --always 2>/dev/null || echo "unknown")
    
    echo "MountSync version: $git_version"
    echo "Installed at: $install_dir"
}
