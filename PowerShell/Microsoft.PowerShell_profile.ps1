using namespace System.Collections.Generic
$TypeAlias = [PowerShell].Assembly.GetType("System.Management.Automation.TypeAccelerators")
$TypeAlias::Add("accelerators", $TypeAlias)
$TypeAlias::Add("TypeAlias", [accelerators])

[TypeAlias]::Add("CompletionResult", [System.Management.Automation.CompletionResult])
[TypeAlias]::Add("CompletionResultType", [System.Management.Automation.CompletionResultType])
$HasReadline = $True
try {
    $ErrorActionPreference = 'SilentlyContinue'
    [TypeAlias]::Add("ReadLine", [Microsoft.PowerShell.PSConsoleReadLine])
}
catch { $HasReadline = $False }

[Console]::OutputEncoding = [Text.Encoding]::UTF8

# Waits until there are no keys down, waits for a key-down,
# holds until there is a key-up.
function Get-Key {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [int]$Delay = 5,

        [Parameter(Position = 1, ValueFromPipeline)]
        [string]$Prompt = "Waiting %% seconds..."
    )

    begin {
        $milliseconds = [int]$Delay * 1000
        $result = {} | Select-Object -Property KeyInfo
        $result.KeyInfo = $null
    }
    process {
        $host.UI.RawUI.FlushInputBuffer()
        While ( (0 -lt $milliseconds)) {
            if ($host.UI.RawUI.KeyAvailable) {
                $keyinfo = $host.UI.RawUI.ReadKey(0xF)
                if ($keyinfo.KeyDown) {
                    $result.KeyInfo = $keyinfo
                    while ($host.UI.RawUI.ReadKey(0xF).KeyDown) {
                        $true
                    }
                    break
                }
            }
            $out = $prompt -Replace "%%", [int]($milliseconds / 1000)
            Write-Host "`r$out" -NoNewline
            Start-Sleep -Milliseconds 100
            $milliseconds = $milliseconds - 100
        }
    }
    end {
        $result
    }
}

$IsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($IsAdmin) {
    if (!$HasReadline -or $null -eq (Get-Key -Delay 3 -Prompt "Removing Admin priviledge in %% seconds...Press a key to retain...")) {
        Write-Host "`nLowering Admin Elevation..."
        gsudo -i Medium
        Stop-Process -Force -Id $PID
    }
    else {
        Write-Host "`nWarning: Root access retained."
    }
}

Import-Module posh-git
# don't really need these loaded and kind of slow
#Import-Module FormatTools
#Import-Module PackageManagement
#Import-Module PoshFunctions

Set-PSReadLineOption `
    -EditMode Emacs `
    -BellStyle Visual `
    -HistorySearchCursorMovesToEnd `
    -HistoryNoDuplicates `

#Fix up OS differences that are easy
$os = $IsWindows ? 'win' : $IsMacOS ? 'mac' : 'nix'

$slash = [IO.Path]::DirectorySeparatorChar
$Env:SLASH = $slash
$Env:ARCH = switch ($os) { 'win' { $Env:PROCESSOR_ARCHITECTURE } default { $(arch) } }


# Do this after radline options. Transient prompt binds Enter key, but 'EditMode emacs' will overwrite/set it also.
#& $Env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh --config "$PSScriptRoot\joe.omp.json" init pwsh | Invoke-Expression
oh-my-posh completion powershell | Out-String | Invoke-Expression
& oh-my-posh --config "$PSScriptRoot\joe.omp.json" init pwsh | Invoke-Expression
$env:POSH_GIT_ENABLED = $true

function cd_back() {
    Set-Location - ; [ReadLine]::InvokePrompt()
}

function cd_forward() {
    Set-Location + ; [ReadLine]::InvokePrompt()
}

function cd_up() {
    Set-Location .. ; [ReadLine]::InvokePrompt()
}

function cd_down() {
    $ok = "`u{00a0}[OK] "
    $cancel = " [Cancel] "
    function 🐚() {
        param
        (
            [ArgumentCompleter({
                    [OutputType([System.Management.Automation.CompletionResult])]
                    param(
                        [string] $CommandName,
                        [string] $ParameterName,
                        [string] $WordToComplete,
                        [System.Management.Automation.Language.CommandAst] $CommandAst,
                        [System.Collections.IDictionary] $FakeBoundParameters
                    )
                    $help_string = "Choose Child-Item or$cancel"
                    $completion_type = [CompletionResultType]::ParameterValue
                    $CompletionResults = [List[CompletionResult]]::new()

                    if ($WordToComplete.Length -eq 0) {
                        $WordToComplete = "." + $slash
                    }
                    else {
                        $help_string = "${ok}to accept,${cancel}or Esc to abort`nSet-Location `"$WordToComplete`""
                        $CompletionResults.Add([CompletionResult]::new($ok, $ok, $completion_type, $help_string))
                    }
                    $CompletionResults.Add([CompletionResult]::new($cancel, $cancel, $completion_type, $help_string))

                    $children = Get-ChildItem $WordToComplete -Depth 0 | Where-Object { $_.PSIsContainer -eq $true }
                    foreach ($child in $children) {
                        $child_path = $WordToComplete + $child.Name + $slash
                        $result = [CompletionResult]::new($child_path, $child.Name, $completion_type, $help_string)
                        $CompletionResults.Add($result)
                    }

                    return $CompletionResults
                })]
            [string]
            $path
        )
        Set-Location "$path"
    }

    # when there are 0 or 1 subdirectory when the keyhandler is first entered, just
    # do the work and get out so the prompt does not flicker or delay.
    function short_circuited() {
        [OutputType([bool])]
        # Some weird logic
        # use the .net enumeration directly so we can generate a result quickly
        # without needing to load every dirent in large directories.
        # Select first 2 so we have a count Don't bother with measure-object
        # Select first 1 to get the name of the 1st file
        $count = 0
        (Get-Item -Path ".").EnumerateDirectories() | ForEach-Object {
            $count += 1
            $_.FullName
        } | Select-Object -First 2
        | Select-Object -First 1 -Wait | New-Variable -name subdir -scope local

        switch ($count) {
            0 { return $true }
            1 {
                Set-Location $subdir
                [ReadLine]::InvokePrompt()
                return $true
            }
        }
        return $false
    }

    if (short_circuited -eq $true) {
        return
    }

    try {
        $line = $cursor = $new_dir = $null
        $cd_cmd = '🐚 '
        $pre_menu = $post_menu = $cd_cmd
        [ReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [ReadLine]::DeleteLine()
        [ReadLine]::Insert($pre_menu)
        do {
            $pre_menu = $post_menu
            [ReadLine]::MenuComplete()
            [ReadLine]::GetBufferState([ref]$post_menu, [ref]$null)
            $menu_item = $post_menu.Substring($cd_cmd.Length)
            if ( $menu_item -eq $cancel) {
                return
            }
            elseif ($menu_item.Length -eq 0 -or $menu_item -eq $ok) {
                break
            }
        } while ($post_menu -ne $pre_menu)
        $new_dir = $pre_menu.Substring($cd_cmd.Length)
        if ($new_dir.Length -gt 0) {
            & $cd_cmd.TrimEnd() "$new_dir"
        }

        #Wait-Debugger
    }
    catch {
        Write-Host ($_ | Format-List | Out-String)
        Start-Sleep 0.5
        Wait-Debugger
    }
    finally {
        [ReadLine]::DeleteLine()
        [ReadLine]::Insert($line)
        [ReadLine]::SetCursorPosition($cursor)
        [ReadLine]::InvokePrompt()
    }
}

function New-DriveAlias([string] $Name, [string] $Root, [string] $Scope = 1) {
    if ($null -ne $Scope -as [int]) {
        $Scope = [int]$Scope + 1 # add in this fn's scope
    }
    if (-not $(Test-Path -PathType Container -Path $Root)) {
        return
    }
    Remove-PSDrive -Force -Name $Name -ErrorAction Ignore
    New-PSDrive -Scope $Scope -Name $Name -PSProvider FileSystem -Root $Root # | Out-Null
}

# Resolve/Expand paths that aren't understood by Win32
function Expand-DriveAlias {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Path
    )

    begin {
        $result = {} | Select-Object -Property ExpandedName, OriginalName
        $result.OriginalName = $Path
        $result.ExpandedName = $Path
    }

    process {
        $ErrorActionPreference = 'Stop'
        try {
            $device = (Split-Path -ErrorAction Ignore -Qualifier "$Path")?.TrimEnd(":")
            if ($device.Length -eq 0) {
                return # No qualifier
            }

            $psdrive = Get-PSDrive -Name "$device"
            $ps_rootdrive = ($psdrive.Root)?.TrimEnd(":")
            $psprovider = $psdrive.Provider

            if ($ps_rootdrive -eq $device) {
                return # The drive is the drive. i.e.: c:\foo\bar as opposed to aliasDrive:\baz
            }

            # If we are here we want the mapping. We didn't want it earlier because
            # if the cwd of c: is c:\foo, and $path is c:boo, we don't want to convert it
            # to c:\foo\boo since win32 handles c:boo just fine already
            $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$psprovider, [ref]$psdrive)
            if ($resolved.Length -gt 0) {
                $result.ExpandedName = $resolved
            }
        }
        catch {
            if (-not $_.FullyQualifiedErrorId.StartsWith("GetLocationNoMatchingDrive")) {
                $src = $_.InvocationInfo
                Write-Error "$(Split-Path -Leaf $src.ScriptName):$($src.ScriptLineNumber)`n$($_.FullyQualifiedErrorId): $_"
            }
        }
    }

    end { $result }
}

# If the cursor is on/in a
function expand_virtual_drives([string] $NextCommand) {
    begin {
        $commit = $false
        $line = $cursor = $null
        [ReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    }

    process {
        # attempt the expansion
        $tokens = $null
        [ReadLine]::GetBufferState([ref] $null, [ref] $tokens, [ref]$null, [ref]$null)
        $target_path = $start_pos = $length = $null
        $command = $null
        $CommandFlag = [Management.Automation.Language.TokenFlags]::CommandName

        #Wait-Debugger

        foreach ($token in $tokens[$tokens.Length..0]) {
            # backwards
            if ($Token.HasError -eq $true) {
                return
            }
            if ($token.Text.Length -eq 0) {
                continue
            }
            $extent = $token.Extent
            if ($cursor -in $extent.StartOffset..$extent.EndOffset) {
                $start_pos = $extent.StartOffset
                $length = $extent.EndOffset - $start_pos
                $target_path = $token.Text
            }

            elseif ($token.TokenFlags.HasFlag($CommandFlag) -and $target_path.Length -gt 0) {
                $command = $token.Text
                break
            }
        }

        # If command or last_text are empty, bail
        if ($target_path.Length -eq 0 -or $command.Length -eq 0) {
            return
        }

        # If the command is not an Application, bail (only external apps need Win32 paths)
        if ((Get-Command -Name "$command" -ErrorAction Ignore)?.CommandType -ne "Application") {
            return
        }

        # comes back the same if no win32 drive expansion
        $replacement = (Expand-DriveAlias -Path $target_path).ExpandedName
        if ($replacement -eq $target_path) {
            return
        }
        $commit = $true
    }

    end {
        if ($commit -eq $true) {
            [readline]::Replace($start_pos, $length, $replacement)
        }
        elseif ($NextCommand.Length -gt 0) {
            #[ReadLine]::MenuComplete()
            [ReadLine]::$NextCommand()
        }
    }
}



function Set-PoshInfo {
    # any extra work can go here
}
New-Alias -Name 'Set-PoshContext' -Value 'Set-PoshInfo' -Scope Global -Force
New-Alias -Force -Name more -Value bat
New-Alias -Force -Name less -Value bat
New-Alias -Force -Name d -Value Get-ChildItem
New-Alias -Force -Name es -Value C:\win32app\TakeCommand\es.exe

Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Ctrl+Backspace -Function BackwardDeleteWord
Set-PSReadlineKeyHandler -Chord "Escape,Escape" -Function DeleteLine

Set-PSReadlineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
Set-PSReadlineKeyHandler -Key Alt+LeftArrow -Function BackwardWord
Set-PSReadlineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
Set-PSReadlineKeyHandler -Key Alt+RightArrow -Function ForwardWord

Set-PSReadlineKeyHandler -Key Alt+z -Function Undo
Set-PSReadlineKeyHandler -Key Ctrl+z -Function Undo

Set-PSReadlineKeyHandler -Key Shift-LeftArrow -ScriptBlock { cd_back }
Set-PSReadlineKeyHandler -Key Shift-RightArrow -ScriptBlock { cd_forward }
Set-PSReadlineKeyHandler -Key Shift-UpArrow -ScriptBlock { cd_up }
Set-PSReadlineKeyHandler -Key Shift-DownArrow -ScriptBlock { cd_down }

Set-PSReadlineKeyHandler -Key Tab -ScriptBlock { expand_virtual_drives "MenuComplete" } # Menu-Complete
Set-PSReadlineKeyHandler -Key Ctrl+Spacebar -ScriptBlock { expand_virtual_drives "Complete" }

$process_name = (Get-Process -PID $PID).Name
$parent_process = (Get-Process -PID $PID).Parent
$Env:SHLVL = 1
while ($null -ne $parent_process) {
    if ($parent_process.Name -ne $process_name) {
        break
    }
    $Env:SHLVL = [int]$Env:SHLVL + 1
    $parent_process = $parent_process.Parent
}

$env:PAGER = "bat.exe -p"
$env:LESS = '-X -i -M -s -S -x4 -j2 -R'


Remove-Item -force -ErrorAction Ignore alias:ls
function ls { Get-ChildItem $args | Format-Wide -AutoSize }
function which { Get-Command $args -all -ErrorAction SilentlyContinue }
function psport { Get-Process -Id (Get-NetTCPConnection -LocalPort $Args).OwningProcess }

(& {
    New-DriveAlias -Name Mega -Scope 1 -Root ~\MegaSync\
    New-DriveAlias -Name Down -Scope 1 -Root ~\Downloads\
    New-DriveAlias -Name Src  -Scope 1 -Root ~\Source\
}) | ForEach-Object { "$($_.Name): => $($_.Root)" }

# get rid of inverse video directories
$PSStyle.FileInfo.Directory = "`e[34m"

# hack to change default color outputs
if ($PSVersionTable.PSVersion -ge [version] '7.2.0') {
    Update-FormatData -PrependPath "$((Get-ChildItem $Profile).DirectoryName)/pwsh_formatting.ps1xml"
}
