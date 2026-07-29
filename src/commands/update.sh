#!/bin/bash

command_update() {
    echo "Updating MountSync..."
    local repo_dir="$HOME/.mountsync"
    if [ ! -d "$repo_dir" ]; then
        echo "Error: installation repository not found at $repo_dir"
        exit 1
    fi
    cd "$repo_dir"
    local current_commit=$(git rev-parse HEAD)
    if ! git pull origin main; then
        echo "Error: Pull failed. Rolling back..."
        git reset --hard "$current_commit"
        exit 1
    fi
    if ! bash install.sh --update; then
        echo "Error: Installation failed. Rolling back..."
        git reset --hard "$current_commit"
        bash install.sh --update
        exit 1
    fi
    echo "Update complete!"
}
