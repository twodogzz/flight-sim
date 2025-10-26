# SET FOLDER TO WATCH + FILES TO WATCH + SUBFOLDERS YES/NO
# Keeps the latest 20 backup files - earlier files are deleted
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "F:\MSFS Addon-Library\Neofly"
$watcher.Filter = "*.bak"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Define the backup directory
$backupDir = "C:\Users\wayne\OneDrive\Documents\Neofly backups" #previous "E:\Neofly backups" "C:\Users\wayne\OneDrive\Documents\Neofly backups"

# DEFINE ACTIONS AFTER AN EVENT IS DETECTED
$action = {
    $path = $Event.SourceEventArgs.FullPath
    $changeType = $Event.SourceEventArgs.ChangeType
    $logline = "$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss')_$($Event.SourceEventArgs.Name)"
    Copy-Item $path -Destination (Join-Path $backupDir $logline)

    # Get all backup files in the directory, sorted by last write time
    $backupFiles = Get-ChildItem -Path $backupDir -Filter "*.bak" | Sort-Object LastWriteTime -Descending

    # If there are more than 20 backup files
    if ($backupFiles.Count -gt 20) {
        # Select the files to remove (all but the 20 most recent)
        $filesToRemove = $backupFiles | Select-Object -Skip 20

        # Loop over each file to remove
        foreach ($file in $filesToRemove) {
            # Delete the file
            Remove-Item -Path $file.FullName
        }
    }
}

# DECIDE WHICH EVENTS SHOULD BE WATCHED
Register-ObjectEvent $watcher "Created" -Action $action
Register-ObjectEvent $watcher "Changed" -Action $action
Register-ObjectEvent $watcher "Deleted" -Action $action
Register-ObjectEvent $watcher "Renamed" -Action $action

while ($true) {sleep 5}