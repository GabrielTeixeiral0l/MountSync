# MountSync - PowerShell Tab Completion Script
# Automatically registers tab autocompletion for mosy in PowerShell 5.1+ and 7+

Register-ArgumentCompleter -Native -CommandName mosy -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $subcommands = @(
        'add', 'init', 'pull', 'list', 'status', 'doctor', 'info', 'diff',
        'history', 'rollback', 'backup', 'snapshot', 'edit', 'which',
        'clean', 'tree', 'remove', 'uninstall', 'config', 'version', 'update', 'link'
    )

    $astText = $commandAst.ToString()
    $tokens = $astText -split '\s+' | Where-Object { $_ -ne "" }

    if ($tokens.Count -le 1 -or ($tokens.Count -eq 2 -and $tokens[0] -eq 'mosy' -and $astText -notmatch '\s$')) {
        return $subcommands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }

    $subcommand = if ($tokens.Count -gt 1) { $tokens[1] } else { "" }
    $options = switch ($subcommand) {
        'add'      { @('--tag', '-t', '--group', '-g', '--link', '--target', '--to', '--force', '-f', '--scan-secrets', '--scan', '--no-scan', '--guard', '--no-guard') }
        'link'     {
            if ($tokens.Count -ge 2 -and ($tokens[-1] -eq '--app' -or $tokens[-1] -eq '-a')) {
                @('vscode', 'nvim', 'starship', 'git', 'windows-terminal')
            } else {
                @('--app', '-a', '--tag', '-t', '--group', '-g', '--force', '-f')
            }
        }
        'status'   { @('--json', '-j', '--quiet', '-q', '--tag', '-t', '--group', '-g') }
        'doctor'   { @('--fix', '-f') }
        'info'     { @('--json', '-j') }
        'diff'     { @('--backup', '-b', '--compare-profile', '-c', '--tag', '-t', '--group', '-g') }
        'history'  { @('--json', '-j', '--tag', '-t', '--group', '-g') }
        'rollback' { @('--force', '-f') }
        'backup'   { @('--tag', '-t', '--group', '-g') }
        'snapshot' { @('--tag', '-t', '--group', '-g') }
        'edit'     { @('--no-backup', '--tag', '-t', '--group', '-g') }
        'which'    { @('--json', '-j') }
        'clean'    { @('--older-than', '--dry-run', '-n', '--force', '-f', '--tag', '-t', '--group', '-g') }
        'tree'     { @('--all-profiles', '-a', '--by-group', '--no-color', '--json', '--tag', '-t', '--group', '-g') }
        'config'   {
            if ($tokens.Count -eq 2) {
                @('set')
            } elseif ($tokens.Count -ge 3 -and $tokens[2] -eq 'set') {
                @('MOSY_REMOTE_NAME', 'MOSY_MOUNT_POINT', 'MOSY_VFS_CACHE', 'MOSY_CLOUD_DIR', 'MOSY_BACKUP_EXT', 'MOSY_LOG_LEVEL', 'MOSY_DRY_RUN', 'MOSY_SCAN_SECRETS', 'MOSY_SAFETY_GUARD')
            }
        }
        default    { @() }
    }

    return $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
