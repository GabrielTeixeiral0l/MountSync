#!/bin/bash

cmd_version() {
    local local_ver="v1.2.0"
    echo "MountSync $local_ver"
    
    # Query GitHub releases silently with timeout
    latest_ver=$(curl -s -m 2 "https://api.github.com/repos/GabrielTeixeiral0l/MountSync/releases/latest" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p')
    
    if [ -n "$latest_ver" ]; then
        if [ "$local_ver" != "$latest_ver" ]; then
            echo "A new version is available: $latest_ver"
            echo "Run 'mosy update' to update."
        else
            echo "You are running the latest version."
        fi
    fi
}
