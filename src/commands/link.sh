#!/bin/bash
# MountSync - src/commands/link.sh
# Map a local divergent path to an existing cloud vault item across platforms

cmd_link() {
    check_mount
    local RAW_LOCAL=""
    local RAW_CLOUD=""
    local APP_PRESET=""
    local FORCE=false
    parse_filter_flags "$@"
    local TAGS="$MOSY_FILTER_TAG"
    local ITEM_GROUPS="$MOSY_FILTER_GROUP"

    local positional_args=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --tag|-t|--group|-g)
                shift 2
                ;;
            --force|-f)
                FORCE=true
                shift
                ;;
            --app|-a)
                APP_PRESET="$2"
                shift 2
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done

    local default_cloud=""
    if [ -n "$APP_PRESET" ]; then
        case "$APP_PRESET" in
            vscode)
                case "${MOSY_OS:-linux}" in
                    windows) RAW_LOCAL="AppData/Roaming/Code/User/settings.json" ;;
                    darwin)  RAW_LOCAL="Library/Application Support/Code/User/settings.json" ;;
                    *)       RAW_LOCAL=".config/Code/User/settings.json" ;;
                esac
                default_cloud=".config/Code/User/settings.json"
                ;;
            nvim)
                case "${MOSY_OS:-linux}" in
                    windows) RAW_LOCAL="AppData/Local/nvim" ;;
                    *)       RAW_LOCAL=".config/nvim" ;;
                esac
                default_cloud=".config/nvim"
                ;;
            starship)
                RAW_LOCAL=".config/starship.toml"
                default_cloud=".config/starship.toml"
                ;;
            git)
                RAW_LOCAL=".gitconfig"
                default_cloud=".gitconfig"
                ;;
            windows-terminal)
                case "${MOSY_OS:-linux}" in
                    windows) RAW_LOCAL="AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json" ;;
                    *)       RAW_LOCAL=".config/windows-terminal/settings.json" ;;
                esac
                default_cloud=".config/windows-terminal/settings.json"
                ;;
            *)
                echo "Error: Unknown application preset '$APP_PRESET'." >&2
                echo "Supported presets: vscode, nvim, starship, git, windows-terminal" >&2
                exit 1
                ;;
        esac

        if [ ${#positional_args[@]} -ge 1 ]; then
            RAW_CLOUD="${positional_args[0]}"
        elif [ -e "$MOSY_CLOUD_DIR/$default_cloud" ]; then
            RAW_CLOUD="$default_cloud"
        fi
    else
        if [ ${#positional_args[@]} -ge 1 ]; then
            RAW_LOCAL="${positional_args[0]}"
        fi
        if [ ${#positional_args[@]} -ge 2 ]; then
            RAW_CLOUD="${positional_args[1]}"
        fi
    fi

    if [ -z "$RAW_LOCAL" ]; then
        echo "Usage: mosy link <local_path> [cloud_vault_target] [--tag <tags>] [--group <groups>] [--force]"
        echo "       mosy link --app <preset> [cloud_vault_target] [--tag <tags>] [--group <groups>] [--force]"
        echo "Supported presets: vscode, nvim, starship, git, windows-terminal"
        echo "Example: mosy link ~/AppData/Roaming/Code/User/settings.json .config/Code/User/settings.json"
        echo "Example: mosy link --app vscode"
        exit 1
    fi

    # Normalize local path relative to HOME
    local local_abs=""
    if [ "${RAW_LOCAL:0:2}" = "~/" ]; then
        local_abs="${HOME}/${RAW_LOCAL:2}"
    elif [ "${RAW_LOCAL:0:1}" = "/" ]; then
        local_abs="$RAW_LOCAL"
    else
        local_abs="${HOME}/${RAW_LOCAL}"
    fi

    # Disallow paths outside HOME
    if [[ "$local_abs" != "$HOME"* ]]; then
        echo "Error: Local path must be inside your HOME directory ($HOME)."
        exit 1
    fi

    local local_rel="${local_abs#$HOME/}"
    local cloud_rel="$RAW_CLOUD"

    # If cloud target is not explicitly given, discover candidates in vault
    if [ -z "$cloud_rel" ]; then
        local base_name
        base_name=$(basename "$local_abs")
        local candidates=()
        while IFS= read -r f; do
            [ -n "$f" ] && candidates+=("${f#$MOSY_CLOUD_DIR/}")
        done < <(find "$MOSY_CLOUD_DIR" \( -type f -o -type d \) -name "$base_name" 2>/dev/null | sort)

        if [ ${#candidates[@]} -eq 0 ]; then
            if [ -n "$default_cloud" ]; then
                echo "Error: Cloud vault target '$default_cloud' does not exist in $MOSY_CLOUD_DIR."
            else
                echo "Error: No matching item named '$base_name' found in cloud vault."
                echo "Specify the target explicitly: mosy link $RAW_LOCAL <cloud_target>"
            fi
            exit 1
        elif [ ${#candidates[@]} -eq 1 ]; then
            cloud_rel="${candidates[0]}"
        else
            if [ -t 0 ] && [ -z "${MOSY_NO_TTY:-}" ] && [ "$FORCE" != true ]; then
                echo "Multiple candidates found in vault for '$base_name':"
                local idx=1
                for c in "${candidates[@]}"; do
                    echo "  [$idx] $c"
                    ((idx++))
                done
                local choice=""
                read -r -p "Select cloud target [1-${#candidates[@]}, default: 1]: " choice
                if [ -z "$choice" ]; then
                    cloud_rel="${candidates[0]}"
                elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#candidates[@]} ]; then
                    cloud_rel="${candidates[$((choice - 1))]}"
                else
                    echo "Invalid selection. Aborting."
                    exit 1
                fi
            else
                cloud_rel="${candidates[0]}"
            fi
        fi
    fi

    # Normalize cloud_rel (strip leading slashes or vault path prefix)
    cloud_rel="${cloud_rel#$MOSY_CLOUD_DIR/}"
    cloud_rel="${cloud_rel#/}"

    local cloud_full_path="$MOSY_CLOUD_DIR/$cloud_rel"
    if [ ! -e "$cloud_full_path" ]; then
        echo "Error: Cloud vault target '$cloud_rel' does not exist in $MOSY_CLOUD_DIR."
        exit 1
    fi

    # Set default platform tag if none provided
    if [ -z "$TAGS" ]; then
        TAGS="${MOSY_DEFAULT_TAG:-linux}"
    fi

    # Inherit group from existing map entry for the same cloud target if not provided
    if [ -z "$ITEM_GROUPS" ] && [ -f "$MOSY_MAP_FILE" ]; then
        while IFS="|" read -r _l _c _t _g; do
            if [ "$_c" = "$cloud_rel" ] && [ -n "$_g" ]; then
                ITEM_GROUPS="$_g"
                break
            fi
        done < "$MOSY_MAP_FILE"
    fi

    # Prepare local destination
    mkdir -p "$(dirname "$local_abs")"

    # If already a symlink pointing to the cloud target
    if [ -L "$local_abs" ]; then
        local current_link
        current_link=$(readlink "$local_abs" 2>/dev/null || true)
        if [ "$current_link" != "$cloud_full_path" ]; then
            rm -f "$local_abs"
        fi
    elif [ -e "$local_abs" ]; then
        echo "Backing up existing local file to $(basename "$local_abs").bak..."
        mosy_backup "$local_abs"
    fi

    # Create symlink
    if [ ! -L "$local_abs" ]; then
        ln -s "$cloud_full_path" "$local_abs"
    fi

    # Update sync-map.conf
    mkdir -p "$(dirname "$MOSY_MAP_FILE")"
    touch "$MOSY_MAP_FILE"

    # Remove previous mapping for this exact local_rel if it exists
    update_map_remove_entry "$local_rel"

    # Append new mapping
    echo "${local_rel}|${cloud_rel}|${TAGS}|${ITEM_GROUPS}" >> "$MOSY_MAP_FILE"

    echo "Success! Linked ~/$local_rel -> vault/$cloud_rel (tags: $TAGS)."
}
