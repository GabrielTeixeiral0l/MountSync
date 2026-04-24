#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Initialize counters
TOTAL=0
OK=0
WARN=0
ERR=0

status_callback() {
    local local_rel=$1
    local cloud_rel=$2
    local local_path="${HOME}/${local_rel}"
    local cloud_path="${SYNC_DIR}/${cloud_rel}"
    
    ((TOTAL++))

    if [ -L "$local_path" ]; then
        local target
        target=$(readlink "$local_path")
        if [ "$target" == "$cloud_path" ]; then
            if [ -e "$cloud_path" ]; then
                echo -e "${GREEN}[OK]${NC} $local_rel"
                ((OK++))
            else
                echo -e "${RED}[ERR]${NC} $local_rel (Broken link: cloud source missing)"
                ((ERR++))
            fi
        else
            echo -e "${RED}[ERR]${NC} $local_rel (Wrong target: points to $target)"
            ((ERR++))
        fi
    else
        if [ -e "$cloud_path" ]; then
            echo -e "${YELLOW}[WARN]${NC} $local_rel (Missing link: cloud source exists)"
            ((WARN++))
        else
            echo -e "${RED}[ERR]${NC} $local_rel (Both local and cloud sources missing)"
            ((ERR++))
        fi
    fi
}

cmd_status() {
    echo -e "--- System Status ---"
    
    # Check Mount
    if mount | grep -q "$MOUNT_POINT"; then
        echo -e "Mount Point ($MOUNT_POINT): ${GREEN}MOUNTED${NC}"
    else
        echo -e "Mount Point ($MOUNT_POINT): ${RED}NOT MOUNTED${NC}"
    fi

    # Check Systemd
    local service_status
    service_status=$(systemctl --user is-active mosy-mount.service 2>/dev/null || echo "inactive")
    if [ "$service_status" == "active" ]; then
        echo -e "Systemd Service (mosy-mount): ${GREEN}ACTIVE${NC}"
    else
        echo -e "Systemd Service (mosy-mount): ${YELLOW}INACTIVE ($service_status)${NC}"
    fi

    echo -e "\n--- File Integrity ---"
    
    TOTAL=0
    OK=0
    WARN=0
    ERR=0

    if [ ! -f "$MAP_FILE" ]; then
        echo "No items are currently being managed (map file missing)."
    else
        foreach_mapping status_callback
    fi

    echo -e "\n--- Summary ---"
    echo -e "Total: $TOTAL"
    echo -e "${GREEN}OK: $OK${NC}"
    echo -e "${YELLOW}Warnings: $WARN${NC}"
    echo -e "${RED}Errors: $ERR${NC}"
}
