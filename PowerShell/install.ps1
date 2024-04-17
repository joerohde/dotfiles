# Note: Installing powershell
# Windows: winget winget install --id Microsoft.Powershell --source winget
# MacOS:   brew install --cask powershell
# Ubuntu:  sudo snap install --classic powershell
#
$os = $IsWindows ? 'win' : $IsMacOS ? 'mac' : 'nix'

if ($Profile.Length -eq 0) {
    Write-Host "No `$Profile set"
    return
}

. $PSScriptRoot\dotbot.ps1

# New profiles paths often point to a directory that doesn't exist yet.
# dotbot should handle it now: New-Item -ItemType File -Path "$Profile" -Force | Out-Null
$ProfilePath = Split-Path "$Profile"

function PrettyHomePath([string]$path) {
    $relative = $(Resolve-Path($path) -Relative -RelativeBasePath ~)
    if ($relative.StartsWith("..")) {
        return $path
    }

    return "~$($relative.Substring(1))"
}

Write-Host "Installing From: $(PrettyHomePath $PSScriptRoot)"
Write-Host "  Installing To: $(PrettyHomePath $ProfilePath)`n"

# Dotbot's job now
#(Copy-Item -PassThru "$PSScriptRoot\Microsoft.PowerShell_profile.ps1" "$Profile").FullName
#(Copy-Item -PassThru "$PSScriptRoot\joe.omp.json" "$ProfilePath/").FullName
#(Copy-Item -PassThru "$PSScriptRoot\pwsh_formatting.ps1xml" "$ProfilePath/").FullName

Get-PackageProvider -Name "NuGet" -ForceBootstrap -ErrorAction SilentlyContinue | Out-Null
if (-not (Get-PSRepository PSGallery).Trusted) {
    Set-PSRepository PSGallery -InstallationPolicy Trusted | Out-Null
}

function Install-MissingPackage([string] $Name) {
    switch ($os) {
        "win" {
            if (-not $(Get-WinGetPackage -Id "$Name")) {
                Write-Host -NoNewline "Installing Package $Name..."
                Install-WinGetPackage -id "$Name" -Force -Source WinGet
                Write-Host "Done"
            }
            else {
                Write-Host "Package Already Installed: $Name"
            }
        }
        "mac" {
            brew ls "$Name" | out-null || & {
                Write-Host "Installing $Name..."
                brew install -q -f "$Name"
            }
        }
        default {
            dpkg-query -f '${}' --show "$Name" || & {
                Write-Host "Installing $Name..."
                sudo apt-get install -qq -y "$Name"
            }
        }
    }
}

function Install-MissingModule([string] $Name, [hashtable] $extras = @{}) {
    if (-not (Get-Module -ListAvailable -Name "$Name")) {
        Write-Host -NoNewline "Installing Module $Name..."
        $options = ${

        }
        if ($Version.Length -gt 0) {
            $options.Version = $Version
        }
        Install-Module  -Force -Repository 'PSGallery' -AcceptLicense -Name "$Name" @extras
        Write-Host "Done"
    }
    else {
        Write-Host "Module Already Installed: $Name"
    }
}

switch ($os) {
    "win" {
        Install-MissingModule -Name Microsoft.WinGet.Client
        Install-MissingPackage -Name "jftuga.less"
        Install-MissingPackage -Name "sharkdp.bat"
        Install-MissingPackage -Name "JanDeDobbeleer.OhMyPosh"
    }
    "mac" {
        Install-MissingPackage -Name less
        Install-MissingPackage -Name bat
        Install-MissingPackage -Name "jandedobbeleer/oh-my-posh/oh-my-posh"
    }
    "nix" {
        Get-Command -ErrorAction Ignore oh-my-posh | out-null || curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
        Install-MissingPackage -Name bat
    }
}

Install-MissingModule -Name PackageManagement
Install-MissingModule -Name posh-git
Install-MissingModule -Name FormatTools
$options = @{ MaximumVersion = '2.2.10' }; Install-MissingModule -Name PoshFunctions $options
. $Profile
