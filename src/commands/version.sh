#!/bin/bash

cmd_version() {
    local local_ver="v1.0.0"
    echo "MountSync $local_ver"
    
    # Query GitHub releases silently with timeout
    local latest_ver
    latest_ver=$(curl -s -m 2 "https://api.github.com/repos/GabrielTeixeiral0l/MountSync/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -n "$latest_ver" ]; then
        if [ "$local_ver" != "$latest_ver" ]; then
            echo "A new version is available: $latest_ver"
            echo "Run 'mosy update' to update."
        else
            echo "You are running the latest version."
        fi
    fi
}
