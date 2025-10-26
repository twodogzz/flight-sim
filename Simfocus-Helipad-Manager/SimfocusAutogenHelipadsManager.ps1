<#
.SYNOPSIS
  Simfocus Autogen Helipads Manager (PowerShell, Windows 10/11)

.DESCRIPTION
  Semi-automated management of Simfocus Autogen helipad BGL scenery files for MSFS 2020/2024.
  Toggles helipad states (ON/OFF) by renaming file extensions (.bgl <-> .OFF).
  Includes config initialization, managed list updates (search/add/remove/batch), and state application.
  Persistent UTF-8 logging, reversible operations, clear user prompts.

.NOTES
  - Managed list contains helipad file names to keep OFF (e.g., FR_5XZ53.bgl).
  - Config stores Community folder path and managed list path; optional SimVersion.
  - Safe operations: no destructive deletes; only reversible renames.

.VERSION
  0.0.3α
#>

#region Globals
$Script:AppName        = 'Helipad Manager'
$Script:AppId          = 'Simfocus-Helipad-Manager'
$Script:Version        = '0.0.3α'
$Script:BaseDir        = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$Script:ConfigPath     = Join-Path $Script:BaseDir "$($Script:AppId)-config.json"
$Script:ManagedList    = Join-Path $Script:BaseDir "$($Script:AppId)-managed-list.txt"
$Script:LogPath        = Join-Path $Script:BaseDir "$($Script:AppId)-log.txt"
$Script:Encoding       = New-Object System.Text.UTF8Encoding($false) # UTF8 without BOM
#endregion Globals

#region Utilities
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')][string]$Level = 'INFO'
    )
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    $color = switch ($Level) {
        'INFO'    { 'Gray' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
        default   { 'White' }
    }

    [System.IO.File]::AppendAllText($Script:LogPath, $line + [Environment]::NewLine, $Script:Encoding)
    Write-Host $line -ForegroundColor $color
}

function New-FileIfMissing {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [string]$InitialContent = ''
    )
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path $Path)) {
        Set-Content -Path $Path -Value $InitialContent -Encoding UTF8
        Write-Log "Created file: $Path" 'INFO'
    }
}

function Wait-ForKey {
    Write-Host
    Write-Host 'Press Enter to continue...' -ForegroundColor Cyan
    [void][System.Console]::ReadLine()
}

function Read-Choice {
    param(
        [string]$Prompt,
        [int[]]$Valid = @(1,2,3)
    )
    while ($true) {
        $userInput = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($userInput)) { return $null }
        if ($userInput -as [int] -and ($Valid -contains [int]$userInput)) { return [int]$userInput }
        Write-Host "Please enter one of: $($Valid -join ', ')" -ForegroundColor Yellow
    }
}
#endregion Utilities

#region Config
class HelipadConfig {
    [string]$CommunityPath
    [string]$ManagedListPath
    [string]$SimVersion
}

function Get-Config {
    if (Test-Path $Script:ConfigPath) {
        try {
            $json = Get-Content -Path $Script:ConfigPath -Raw
            $obj  = $json | ConvertFrom-Json
            $cfg  = [HelipadConfig]::new()
            $cfg.CommunityPath   = $obj.CommunityPath
            $cfg.ManagedListPath = $obj.ManagedListPath
            $cfg.SimVersion      = $obj.SimVersion

            # Reuse the same null-checking logic
            $cfg = Ensure-ConfigValues -Config $cfg
            Save-Config -Config $cfg
            return $cfg
        } catch {
            Write-Log "Failed to read config: $($_.Exception.Message)" 'ERROR'
            return $null
        }
    }
    return $null
}

function Save-Config {
    param([Parameter(Mandatory)][HelipadConfig]$Config)
    $payload = [pscustomobject]@{
        CommunityPath   = $Config.CommunityPath
        ManagedListPath = $Config.ManagedListPath
        SimVersion      = $Config.SimVersion
        UpdatedAt       = (Get-Date).ToString('s')
        App             = $Script:AppId
        Version         = $Script:Version
    } | ConvertTo-Json -Depth 3
    New-FileIfMissing -Path $Script:ConfigPath
    Set-Content -Path $Script:ConfigPath -Value $payload -Encoding UTF8
    Write-Log "Saved config to: $($Script:ConfigPath)" 'SUCCESS'
}

function Initialize-Config {
    Write-Host "=== Initialization ===" -ForegroundColor Cyan

    $cfg = Get-Config
    if (-not $cfg) { $cfg = [HelipadConfig]::new() }

    # Reuse the same null-checking logic
    $cfg = Ensure-ConfigValues -Config $cfg
    Save-Config -Config $cfg
    return $cfg
}

function Ensure-ConfigValues {
    param([Parameter(Mandatory)][HelipadConfig]$Config)

    # CommunityPath
    if ([string]::IsNullOrWhiteSpace($Config.CommunityPath) -or -not (Test-Path $Config.CommunityPath)) {
        Write-Host "Enter the MSFS Community folder path e.g. ...\LocalCache\Packages\Community\ <-" -ForegroundColor Yellow
        $Config.CommunityPath = Read-Host 'Community folder path'
        if ([string]::IsNullOrWhiteSpace($Config.CommunityPath) -or -not (Test-Path $Config.CommunityPath)) {
            Write-Log 'Community folder path invalid or not provided. Quitting.' 'ERROR'
            throw 'Community path required'
        }
    }

    # ManagedListPath
    if ([string]::IsNullOrWhiteSpace($Config.ManagedListPath)) {
        $Config.ManagedListPath = $Script:ManagedList
        Write-Log "Defaulting managed list to: $($Config.ManagedListPath)" 'INFO'
    }
    New-FileIfMissing -Path $Config.ManagedListPath -InitialContent "# Managed helipads to keep OFF`n# One filename per line (e.g., FR_5XZ53.bgl)`n"

    # SimVersion (optional)
    if ([string]::IsNullOrWhiteSpace($Config.SimVersion)) {
        $sv = Read-Host 'Sim version (2020/2024, optional)'
        if ($sv -match '^(2020|2024)$') { $Config.SimVersion = $sv }
    }

    return $Config
}

#endregion Config

#region Managed list
function Read-ManagedList {
    param([Parameter(Mandatory)][string]$ManagedListPath)

    if (-not (Test-Path $ManagedListPath)) { return @() }

    # Force array context on read
    $lines = @(Get-Content -Path $ManagedListPath -ErrorAction SilentlyContinue) |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and ($_ -notmatch '^\s*#')
        }

    $normalized = $lines | ForEach-Object {
        $name = $_.Trim()
        if ($name.EndsWith('.OFF')) {
            $name = $name.Substring(0, $name.Length - 4) + '.bgl'
        }
        $name
    }

    # Return as array, even for 0 or 1 item
    return @($normalized | Sort-Object -Unique)
}

function Save-ManagedList {
    param([string]$ManagedListPath,[string[]]$Items)

    $Items = @($Items | ForEach-Object { $_.Trim() })

    $content = @(
        '# Managed helipads to keep OFF'
        '# One filename per line (e.g., FR_5XZ53.bgl)'
        ''
    ) + $Items

    # Each array element becomes a line; explicit array context
    Out-File -FilePath $ManagedListPath -InputObject $content -Encoding UTF8
    Write-Log "Managed list saved: $ManagedListPath (count=$($Items.Count))" 'SUCCESS'
}

function Update-ManagedList {
    param(
        [Parameter(Mandatory)][HelipadConfig]$Config
    )

    Write-Host "=== Update Managed List (OFF targets) ==="

    # Always load as array
    $ManagedList = @(Read-ManagedList -ManagedListPath $Config.ManagedListPath)

    $count = $ManagedList.Count
    Write-Host "Current entries: $count"

    if ($count -gt 0) {
        for ($i = 0; $i -lt $count; $i++) {
            Write-Host ("{0}. {1}" -f ($i + 1), $ManagedList[$i])
        }
    }

    $input = Read-Host 'Enter search text (filename fragment, e.g., "FR_", "5XZ") OR index(es)/ranges of current entries to delete'
    if ([string]::IsNullOrWhiteSpace($input)) { return }

    # --- Delete branch ---
    if ($input -match '^[\d,\-\s]+$') {
        $parts = $input -split '[ ,]+' | Where-Object { $_ -ne '' }
        $indexes = @()
        foreach ($part in $parts) {
            if ($part -match '^\d+$') {
                $indexes += ([int]$part - 1)
            }
            elseif ($part -match '^(\d+)-(\d+)$') {
                $start = [int]$matches[1]
                $end   = [int]$matches[2]
                if ($end -ge $start) {
                    $indexes += ($start..$end | ForEach-Object { $_ - 1 })
                }
            }
        }
        $toRemove = @()
        foreach ($idx in $indexes) {
            if ($idx -ge 0 -and $idx -lt $ManagedList.Count) {
                $toRemove += $ManagedList[$idx]
            }
        }
        if ($toRemove.Count -gt 0) {
            # User-facing confirmations
            foreach ($item in $toRemove) {
                $line = "[{0}] [SUCCESS] Removed from managed list: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $item
                Write-Host $line -ForegroundColor Yellow
            }
            Write-Log "Removed from managed list: $($toRemove -join ', ')" 'INFO'
            $ManagedList = @($ManagedList | Where-Object { $toRemove -notcontains $_ })
        }
        else {
            Write-Host "No valid indexes selected for removal."
        }
    }
    # --- Add branch ---
    else {
        # Treat input as search fragment(s)
        $fragments = $input -split '[ ,]+' | Where-Object { $_.Trim() -ne '' }

        $found = @()
        foreach ($frag in $fragments) {
            $frag = $frag.Trim()
            $found += Get-ChildItem -Path $Config.CommunityPath -Recurse -Filter "*.bgl" -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*$frag*" -and $_.DirectoryName -match "simfocus-autogen-helipads" }
        }

        if ($found) {
            $found = $found | Sort-Object Name -Unique

            Write-Host "`nFound potential matches:`n"
            for ($i = 0; $i -lt $found.Count; $i++) {
                Write-Host ("{0}. {1}" -f ($i + 1), $found[$i].Name)
            }

            $confirm = Read-Host "`nEnter index(es)/ranges to add (e.g. 1,3,5 or 2-6) OR 'A' to add all, or press Enter to cancel"
            $toAdd = @()

            if ($confirm -match '^[Aa]$') {
                $toAdd = $found | Select-Object -ExpandProperty Name
            }
            elseif ($confirm -match '^[\d,\-\s]+$') {
                $parts = $confirm -split '[ ,]+' | Where-Object { $_ -ne '' }
                $indexes = @()
                foreach ($part in $parts) {
                    if ($part -match '^\d+$') {
                        $indexes += ([int]$part - 1)
                    }
                    elseif ($part -match '^(\d+)-(\d+)$') {
                        $start = [int]$matches[1]
                        $end   = [int]$matches[2]
                        if ($end -ge $start) {
                            $indexes += ($start..$end | ForEach-Object { $_ - 1 })
                        }
                    }
                }
                foreach ($idx in $indexes) {
                    if ($idx -ge 0 -and $idx -lt $found.Count) {
                        $toAdd += $found[$idx].Name
                    }
                }
            }

            if ($toAdd.Count -gt 0) {
                $ManagedList = @($ManagedList + $toAdd) | Sort-Object -Unique
                Write-Log "Added to managed list: $($toAdd -join ', ')" 'INFO'

                # --- Consolidated user-facing confirmation ---
                $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Write-Host ("[{0}] [SUCCESS] Added to managed list:" -f $timestamp) -ForegroundColor Green
                $toAdd | ForEach-Object { Write-Host $_ -ForegroundColor Green }
            }
            else {
                Write-Host "No entries added."
            }
        }
        else {
            Write-Host "No matches found for '$($fragments -join ', ')'."
        }
    }

    Save-ManagedList -ManagedListPath $Config.ManagedListPath -Items $ManagedList

    # --- Pause so user can review confirmations before returning ---
    Write-Host "`nPress Enter to return to the menu..." -ForegroundColor Cyan
    [void](Read-Host)
}
#endregion Managed list

#region File state management
function Get-HelipadSceneryRoot {
    param([Parameter(Mandatory)][HelipadConfig]$Config)

    $roots = @()

    switch ($Config.SimVersion) {
        '2020' {
            $roots += Join-Path -Path $Config.CommunityPath `
                -ChildPath 'simfocus-autogen-helipads-world\Scenery\simfocus-autogen-helipads-World\scenery'
        }
        '2024' {
            $roots += Join-Path -Path $Config.CommunityPath `
                -ChildPath 'simfocus-autogen-helipads-world-2024\Scenery\simfocus-autogen-helipads-World-2024\scenery'
        }
        default {
            # Fallback: check both if SimVersion not set
            $roots += Join-Path -Path $Config.CommunityPath `
                -ChildPath 'simfocus-autogen-helipads-world\Scenery\simfocus-autogen-helipads-World\scenery'
            $roots += Join-Path -Path $Config.CommunityPath `
                -ChildPath 'simfocus-autogen-helipads-world-2024\Scenery\simfocus-autogen-helipads-World-2024\scenery'
        }
    }

    return $roots | Where-Object { Test-Path $_ }
}

function Get-HelipadFiles {
    param([Parameter(Mandatory)][string[]]$SceneryRoots)
    $files = @()
    foreach ($root in $SceneryRoots) {
        $files += Get-ChildItem -Path $root -Filter '*.bgl' -File -ErrorAction SilentlyContinue
        $files += Get-ChildItem -Path $root -Filter '*.OFF' -File -ErrorAction SilentlyContinue
    }
    return $files
}

function Set-HelipadStates {
    param([Parameter(Mandatory)][HelipadConfig]$Config)

    $roots = Get-HelipadSceneryRoot -Config $Config
    if ($roots.Count -eq 0) {
        Write-Log 'No Simfocus helipad scenery folders found under Community.' 'ERROR'
        Write-Host "No Simfocus helipad scenery folders found under Community." -ForegroundColor Red
        return
    }

    $managed  = Read-ManagedList -ManagedListPath $Config.ManagedListPath
    $allFiles = Get-HelipadFiles -SceneryRoots $roots

    $toOff = @()
    $toOn  = @()
    $skipped = 0

    foreach ($file in $allFiles) {
        $name = $file.Name
        $baseName = if ($name.EndsWith('.OFF')) {
            $name.Substring(0, $name.Length - 4) + '.bgl'
        } else {
            $name
        }

        $isManagedOff = $managed -contains $baseName

        if ($isManagedOff) {
            if ($name.EndsWith('.bgl')) {
                $newName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) + '.OFF'
                try {
                    Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop
                    Write-Log "Set OFF: $($file.Name) -> $newName" 'SUCCESS'
                    $toOff += $file.Name
                } catch {
                    Write-Log "Failed to set OFF: $($file.FullName) - $($_.Exception.Message)" 'ERROR'
                    $skipped++
                }
            } else {
                $skipped++
            }
        } else {
            if ($name.EndsWith('.OFF')) {
                $newName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) + '.bgl'
                try {
                    Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop
                    Write-Log "Set ON: $($file.Name) -> $newName" 'SUCCESS'
                    $toOn += $file.Name
                } catch {
                    Write-Log "Failed to set ON: $($file.FullName) - $($_.Exception.Message)" 'ERROR'
                    $skipped++
                }
            } else {
                $skipped++
            }
        }
    }

    # --- User-facing summary ---
    Write-Host "`n=== Helipad State Update Summary ===" -ForegroundColor Cyan

    if ($toOff.Count -eq 0 -and $toOn.Count -eq 0) {
        Write-Host "No changes needed. All helipads already in correct state." -ForegroundColor Green
    } else {
        if ($toOff.Count -gt 0) {
            Write-Host ("Turned OFF : {0}" -f $toOff.Count) -ForegroundColor Yellow
            $toOff | ForEach-Object { Write-Host "  - $_" }
        }
        if ($toOn.Count -gt 0) {
            Write-Host ("Turned ON  : {0}" -f $toOn.Count) -ForegroundColor Green
            $toOn | ForEach-Object { Write-Host "  - $_" }
        }
    }

    Write-Log "Summary: OFF applied=$($toOff.Count), ON applied=$($toOn.Count), unchanged/skipped=$skipped" 'INFO'

    # --- Pause so user can review confirmations before returning ---
    Write-Host "`nPress Enter to return to the menu..." -ForegroundColor Cyan
    [void](Read-Host)
}
#endregion File state management

#region Menu and interaction
function Show-Banner {
    param([HelipadConfig]$Config)

    $simVer = if (-not [string]::IsNullOrWhiteSpace($Config.SimVersion)) {
        $Config.SimVersion
    } else {
        'Not set'
    }

@"
$($Script:AppName) v$($Script:Version)
---------------------------------------
Simulator Version: $simVer
Community Folder : $($Config.CommunityPath)

1. Update Managed List
2. Update Helipad States
3. Update Config
Enter choice (1-3), or press Enter to quit.
"@ | Write-Host
}

function Update-ConfigInteractive {
    $cfg = Get-Config
    if (-not $cfg) { $cfg = [HelipadConfig]::new() }

    Write-Host "=== Update Config ===" -ForegroundColor Cyan

    $community = Read-Host "Community folder path [current: $($cfg.CommunityPath)]"
    if (-not [string]::IsNullOrWhiteSpace($community)) {
        if (Test-Path $community) {
            $cfg.CommunityPath = $community
        } else {
            Write-Log "Provided community path not found: $community" 'WARN'
        }
    }

    $ml = Read-Host "Managed list path [current: $($cfg.ManagedListPath)]"
    if (-not [string]::IsNullOrWhiteSpace($ml)) {
        $cfg.ManagedListPath = $ml
        New-FileIfMissing -Path $cfg.ManagedListPath
    }

    $sv = Read-Host "Sim version (2020/2024) [current: $($cfg.SimVersion)]"
    if ($sv -match '^(2020|2024)$') { $cfg.SimVersion = $sv }

    Save-Config -Config $cfg
    Write-Host 'Config updated.' -ForegroundColor Green
}

function Main {
    try {
        New-FileIfMissing -Path $Script:LogPath
        Write-Log "Starting $($Script:AppName) v$($Script:Version)" 'INFO'

        $cfg = Initialize-Config

        while ($true) {
            Clear-Host
            Show-Banner -Config $cfg
            $choice = Read-Choice -Prompt 'Your choice' -Valid @(1,2,3)
            if (-not $choice) {
                Write-Log 'No choice entered. Exiting.' 'INFO'
                break
            }

            switch ($choice) {
                1 {
                    Update-ManagedList -Config $cfg
                    Wait-ForKey
                }
                2 {
                    Set-HelipadStates -Config $cfg
                    Wait-ForKey
                }
                3 {
                    Update-ConfigInteractive
                    $cfg = Get-Config
                    Wait-ForKey
                }
            }
        }
    } catch {
        Write-Log "Fatal error: $($_.Exception.Message)" 'ERROR'
        Write-Host 'An error occurred. See log for details.' -ForegroundColor Red
    } finally {
        Write-Log "Exiting $($Script:AppName)" 'INFO'
    }
}

Main
#endregion Menu and interaction