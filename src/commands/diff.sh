#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

_run_colored_diff() {
    local f1="$1"
    local f2="$2"
    local label1="${3:-$f1}"
    local label2="${4:-$f2}"

    if diff --color=always -u --label "$label1" --label "$label2" "$f1" "$f2" 2>/dev/null; then
        return 0
    else
        local code=$?
        if [ $code -eq 1 ]; then
            return 0
        fi

        # Fallback manual line colorizer if diff --color is unsupported
        diff -u "$f1" "$f2" 2>/dev/null | while IFS= read -r line; do
            case "$line" in
                ---*|+++*) echo -e "${BOLD}${line}${NC}" ;;
                @@*) echo -e "${CYAN}${line}${NC}" ;;
                -*) echo -e "${RED}${line}${NC}" ;;
                +*) echo -e "${GREEN}${line}${NC}" ;;
                *) echo "$line" ;;
            esac
        done
        return 0
    fi
}

_diff_item() {
    local raw_target="$1"
    local backup_spec="$2"
    local compare_profile="$3"

    local rel_path="$raw_target"
    if [[ "$raw_target" == "$HOME/"* ]]; then
        rel_path="${raw_target#$HOME/}"
    elif [[ "$raw_target" == /* ]]; then
        rel_path=$(get_relative_home_path "$raw_target")
    fi
    local local_path="${HOME}/${rel_path}"
    local cloud_path="${MOSY_PROFILE_DIR}/${rel_path}"

    # 1. Cross-profile diff
    if [ -n "$compare_profile" ]; then
        local target_profile_dir
        if [ "$compare_profile" = "default" ]; then
            target_profile_dir="$MOSY_CLOUD_DIR"
        else
            target_profile_dir="$MOSY_CLOUD_DIR/profiles/$compare_profile"
        fi
        local target_profile_file="${target_profile_dir}/${rel_path}"

        if [ ! -e "$local_path" ] && [ ! -e "$cloud_path" ]; then
            echo "Error: File $rel_path not found in active profile ($MOSY_PROFILE)." >&2
            return 1
        fi
        if [ ! -e "$target_profile_file" ]; then
            echo "Error: File $rel_path not found in target profile ($compare_profile)." >&2
            return 1
        fi

        local active_file="$local_path"
        [ -e "$active_file" ] || active_file="$cloud_path"

        echo -e "${BOLD}=== Diff: Profile '$MOSY_PROFILE' vs Profile '$compare_profile' for $rel_path ===${NC}"
        _run_colored_diff "$active_file" "$target_profile_file" "$MOSY_PROFILE:$rel_path" "$compare_profile:$rel_path"
        return 0
    fi

    # 2. Physical local file vs Cloud Vault (unlinked/divergent state)
    if [ -e "$local_path" ] && [ ! -L "$local_path" ] && [ -e "$cloud_path" ]; then
        echo -e "${BOLD}=== Diff: Local physical file vs Cloud Vault ($rel_path) ===${NC}"
        _run_colored_diff "$cloud_path" "$local_path" "vault:$rel_path" "local:$rel_path"
        return 0
    fi

    # 3. Backup diff
    if [ ! -e "$local_path" ] && [ ! -e "$cloud_path" ]; then
        echo "Error: File $rel_path not found." >&2
        return 1
    fi

    local backup_file=""
    if [ -n "$backup_spec" ]; then
        if [ -f "$backup_spec" ]; then
            backup_file="$backup_spec"
        elif [ -f "${local_path}${MOSY_BACKUP_EXT}_${backup_spec}" ]; then
            backup_file="${local_path}${MOSY_BACKUP_EXT}_${backup_spec}"
        elif [ -f "${local_path}.${backup_spec}" ]; then
            backup_file="${local_path}.${backup_spec}"
        else
            local candidate
            candidate=$(find "$(dirname "$local_path")" -maxdepth 1 -name "$(basename "$local_path")${MOSY_BACKUP_EXT}_*${backup_spec}*" 2>/dev/null | sort | tail -n 1)
            if [ -n "$candidate" ] && [ -f "$candidate" ]; then
                backup_file="$candidate"
            fi
        fi

        if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
            echo "Error: Backup snapshot matching '$backup_spec' not found for $rel_path." >&2
            return 1
        fi
    else
        local latest_backup
        latest_backup=$(find "$(dirname "$local_path")" -maxdepth 1 -name "$(basename "$local_path")${MOSY_BACKUP_EXT}_*" 2>/dev/null | sort | tail -n 1)
        if [ -z "$latest_backup" ] && [ -f "${local_path}${MOSY_BACKUP_EXT}" ]; then
            latest_backup="${local_path}${MOSY_BACKUP_EXT}"
        fi

        if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
            backup_file="$latest_backup"
        fi
    fi

    if [ -n "$backup_file" ]; then
        echo -e "${BOLD}=== Diff: Backup ($(basename "$backup_file")) vs Current ($rel_path) ===${NC}"
        local active_file="$local_path"
        [ -e "$active_file" ] || active_file="$cloud_path"
        _run_colored_diff "$backup_file" "$active_file" "$(basename "$backup_file")" "current:$rel_path"
        return 0
    else
        if [ -L "$local_path" ]; then
            echo "Info: $rel_path is linked to the cloud vault. No local backup snapshots (.bak_*) found."
            return 0
        else
            echo "Info: No backup snapshot (.bak_*) found for $rel_path."
            return 0
        fi
    fi
}

cmd_diff() {
    local target_path=""
    local backup_spec=""
    local compare_profile=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --backup|-b)
                if [ -n "$2" ] && [[ "$2" != -* ]]; then
                    backup_spec="$2"
                    shift 2
                else
                    shift 1
                fi
                ;;
            --compare-profile|--profile-target|-c)
                compare_profile="$2"
                shift 2
                ;;
            --tag|-t)
                export MOSY_FILTER_TAG="$2"
                shift 2
                ;;
            --group|-g)
                export MOSY_FILTER_GROUP="$2"
                shift 2
                ;;
            -*)
                echo "Unknown flag: $1" >&2
                return 1
                ;;
            *)
                if [ -z "$target_path" ]; then
                    target_path="$1"
                fi
                shift
                ;;
        esac
    done

    if [ -n "$target_path" ]; then
        _diff_item "$target_path" "$backup_spec" "$compare_profile"
        return $?
    fi

    # All items mode
    if [ ! -f "$MOSY_MAP_FILE" ]; then
        echo "No items are currently being managed (map file missing)."
        return 0
    fi

    local count=0
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        IFS="|" read -r l_rel c_rel tags groups <<< "$line"
        [ -z "$l_rel" ] && continue

        if [ -n "${MOSY_FILTER_TAG:-}" ]; then
            local tag_matched=false
            IFS=',' read -ra filter_tags <<< "$MOSY_FILTER_TAG"
            for ft in "${filter_tags[@]}"; do
                if [[ ",${tags:-}," == *",$ft,"* ]]; then
                    tag_matched=true
                    break
                fi
            done
            if [ "$tag_matched" = false ]; then continue; fi
        fi

        if [ -n "${MOSY_FILTER_GROUP:-}" ]; then
            local group_matched=false
            IFS=',' read -ra filter_groups <<< "$MOSY_FILTER_GROUP"
            for fg in "${filter_groups[@]}"; do
                if [[ ",${groups:-}," == *",$fg,"* ]]; then
                    group_matched=true
                    break
                fi
            done
            if [ "$group_matched" = false ]; then continue; fi
        fi

        _diff_item "$l_rel" "$backup_spec" "$compare_profile"
        ((count++))
    done < "$MOSY_MAP_FILE"

    if [ $count -eq 0 ]; then
        echo "No managed items matched filter criteria."
    fi

    return 0
}
