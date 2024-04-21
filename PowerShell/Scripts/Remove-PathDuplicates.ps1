function Remove-PathRegistryDuplicates {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [switch]$MachineReadOnly = $false,
        [Switch]$Force,
        [Switch]$NoBackup
    )

    begin {
        $ErrorActionPreference = 'Inquire'
        $result = {} | Select-Object -Property OriginalMachinePath, OriginalUserPath, UpdatedMachinePath, UpdatedUserPath

        $raw_machine_path = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
        $result.OriginalMachinePath = $raw_machine_path
        $machine_paths = $raw_machine_path.Split(";")

        $raw_user_path = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
        $result.OriginalUserPath = $raw_user_path
        $user_paths = $raw_user_path.Split(";")
        $machine_dups = ($machine_paths | Group-Object -NoElement | Where-Object { $_.Count -gt 1 }).Name

        $user_dups_from_machine = $machine_path | Where-Object { $_ -in $machine_paths }
        $user_dups = ($user_paths | Group-Object -NoElement | Where-Object { $_.Count -gt 1 }).Name

        $total_dup_count = $user_dups_from_machine.Length + $user_dups.Length
        if (-not $MachineReadOnly) {
            $total_dup_count = $total_dup_count + $machine_dups.Length
        }
    }
    process {
        if ($total_dup_count -eq 0) {
            Write-Host "No Duplicates"
            return
        }

        $paths = ""
        if (-not $MachineReadOnly -and $machine_dups.Length -gt 0) {
            $paths += "Remove Duplicates found in MACHINE`n`t"
            $paths += (($machine_dups -Join "`n`t") + "`n")
        }

        if ($user_dups_from_machine.Length -gt 0) {
            $paths += "Remove from USER (Duplicated in MACHINE)`n`t"
            $paths += (($user_dups_from_machine -Join "`n`t") + "`n")
        }

        if ($user_dups.Length -gt 0) {
            $paths += "Remove Duplicates found in USER`n`t"
            $paths += (($user_dups -Join "`n`t") + "`n")
        }

        # Really should check the legnths of the 3 arrays

        if ($Force -or $WhatIfPreference -or $PSCmdlet.ShouldProcess(
            ("Removing Duplicated Paths:`n`t{0}" -f $paths),
            ("OK to Remove?`n{0}" -f $paths),
                "Remove Duplcates Within SYSTEM PATH Registry"
            )
        ) {
            # actually remove them
            if ($user_dups.Length + $user_dups_from_machine.length -gt 0) {
                $new_user_paths = $user_paths | Select-Object -Unique
                $new_user_paths = $new_user_paths | Where-Object { $_ -notin $machine_paths }
                $new_user = $new_user_paths -join ";"

                if ($WhatIfPreference) {
                    Write-Host "-WhatIf: USER Path Modified: $new_user"
                }
                else {
                    if (-Not $NoBackup) {
                        [Environment]::SetEnvironmentVariable("Path.Backup", $raw_user_path,
                            [EnvironmentVariableTarget]::User)
                    }
                    [Environment]::SetEnvironmentVariable("Path", $new_user,
                        [EnvironmentVariableTarget]::User)
                    $result.UpdatedUserPath = $new_user
                }
            }

            if (-Not $MachineReadOnly -and $machine_dups.Length -gt 0) {
                $new_machine_paths = $machine_paths | Select-Object -Unique
                $new_machine = $new_machine_paths -join ";"

                if ($WhatIfPreference) {
                    Write-Host "-WhatIf: MACHINE Path Modified: $new_machine"
                }
                else {
                    if (-Not $NoBackup) {
                        [Environment]::SetEnvironmentVariable("Path.Backup", $raw_machine_path,
                            [EnvironmentVariableTarget]::Machine)
                    }

                    [Environment]::SetEnvironmentVariable("Path", $new_machine,
                        [EnvironmentVariableTarget]::Machine)
                    $result.UpdatedMachinePath = $new_machine
                }
            }
        }
    }
    end {
        $result
    }
}

Remove-PathRegistryDuplicates @Args
