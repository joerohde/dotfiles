using namespace System.Collections.Generic

$TypeAlias = [PowerShell].Assembly.GetType("System.Management.Automation.TypeAccelerators")
$TypeAlias::Add("accelerators", $TypeAlias)
$TypeAlias::Add("TypeAlias", [accelerators])

[TypeAlias]::Add("ReadLine", [Microsoft.PowerShell.PSConsoleReadLine])
[TypeAlias]::Add("CompletionResult", [System.Management.Automation.CompletionResult])
[TypeAlias]::Add("CompletionResultType", [System.Management.Automation.CompletionResultType])

[Console]::OutputEncoding = [Text.Encoding]::UTF8
Import-Module posh-git
Import-Module FormatTools

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

Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Ctrl+Backspace -Function BackwardDeleteWord
Set-PSReadlineKeyHandler -Chord "Escape,Escape" -Function DeleteLine

Set-PSReadlineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
Set-PSReadlineKeyHandler -Key Alt+LeftArrow -Function BackwardWord
Set-PSReadlineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
Set-PSReadlineKeyHandler -Key Alt+RightArrow -Function ForwardWord

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
            if ($menu_item.Length -eq 0 -or $menu_item -eq $cancel) {
                return;
            }
            elseif ($menu_item -eq $ok) {
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

Set-PSReadlineKeyHandler -Key Shift-LeftArrow -ScriptBlock { cd_back }
Set-PSReadlineKeyHandler -Key Shift-RightArrow -ScriptBlock { cd_forward }
Set-PSReadlineKeyHandler -Key Shift-UpArrow -ScriptBlock { cd_up }
Set-PSReadlineKeyHandler -Key Shift-DownArrow -ScriptBlock { cd_down }

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

function Set-PoshInfo {
    # any extra work can go here
}
New-Alias -Name 'Set-PoshContext' -Value 'Set-PoshInfo' -Scope Global -Force


$env:PAGER = "bat.exe -p"
$env:LESS = '-X -i -M -s -S -x4 -j2 -R'

New-Alias -Force -Name more -Value bat
New-Alias -Force -Name less -Value bat
New-Alias -Force -Name d -Value Get-ChildItem

Remove-Item -force -ErrorAction Ignore alias:ls
function ls { Get-ChildItem $args | Format-Wide -AutoSize }
function which { Get-Command $args -all }

function New-DriveAlias([string] $Name, [string] $Root) {
    if (-not $(Test-Path -PathType Container -Path $Root)) {
        return
    }
    Remove-PSDrive -Force -Name $Name -ErrorAction Ignore
    New-PSDrive -Scope 1  -Name $Name -PSProvider FileSystem -Root $Root # | Out-Null
}

New-DriveAlias -Name Mega -Root ~\MegaSync\
New-DriveAlias -Name Down -Root ~\Downloads\

# get rid of inverse video directories
$PSStyle.FileInfo.Directory = "`e[34m"

# hack to change default color outputs
if ($PSVersionTable.PSVersion -ge [version] '7.2.0') {
    Update-FormatData -PrependPath "$((Get-ChildItem $Profile).DirectoryName)/pwsh_formatting.ps1xml"
}

function Expand-DriveAlias([string] $Path) {
    # TODO: WIP
    $result = ${env:CommonProgramFiles(x86)}
    $device = (split-path -ErrorAction Ignore -Qualifier "$Path")?.TrimEnd(":")
    if ($device.Length -eq 0) {
        return $result
    }
    #$result.ExpandedPath = $device
    #$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("S")
}

Expand-DriveAlias -Path Mega:\backup\PowerShell
