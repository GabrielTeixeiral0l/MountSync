#!/bin/bash
# src/commands/version.sh

command_version() {
    local install_dir
    install_dir=$(dirname "$(realpath "$0")")
    # Need to go up one level since this script is in src/commands/
    install_dir=$(dirname "$(dirname "$install_dir")")
    local git_version
    git_version=$(git -C "$install_dir" describe --tags --always 2>/dev/null || echo "unknown")
    
    echo "MountSync version: $git_version"
    echo "Installed at: $install_dir"
}
