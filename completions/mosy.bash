_mosy_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="add init pull list status remove uninstall config version update"

    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
        return 0
    fi

    case "${COMP_WORDS[1]}" in
        config)
            if [ $COMP_CWORD -eq 2 ]; then
                COMPREPLY=( $(compgen -W "set" -- "$cur") )
            elif [ $COMP_CWORD -eq 3 ] && [ "$prev" == "set" ]; then
                local keys="MOSY_REMOTE_NAME MOSY_MOUNT_POINT MOSY_VFS_CACHE MOSY_CLOUD_DIR MOSY_BACKUP_EXT MOSY_LOG_LEVEL MOSY_DRY_RUN"
                COMPREPLY=( $(compgen -W "$keys" -- "$cur") )
            fi
            ;;
    esac
}
complete -F _mosy_completions mosy
