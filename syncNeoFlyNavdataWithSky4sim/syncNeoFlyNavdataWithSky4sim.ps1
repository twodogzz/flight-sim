# SET FOLDER TO WATCH + FILES TO WATCH + SUBFOLDERS NO
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "C:\Users\wayne\AppData\Local\Programs\Sky4Sim NG"
$watcher.Filter = "navdata.sqlite"
$watcher.IncludeSubdirectories = $false  # Subdirectories are not needed as the file is specific
$watcher.EnableRaisingEvents = $true

# Define the backup directory
$backupDir = "F:\MSFS Addon-Library\Neofly"

# DEFINE ACTIONS AFTER AN EVENT IS DETECTED
$action = {
    $path = $Event.SourceEventArgs.FullPath
    $changeType = $Event.SourceEventArgs.ChangeType
    $currentDate = Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'
    
    # Create a new filename with a timestamp before copying
    $backupFileName = "navdata_$currentDate.sqlite"
    $backupFilePath = Join-Path $backupDir $backupFileName
    
    # Copy the file to the backup directory with the new name
    Copy-Item $path -Destination $backupFilePath

    # Get all backup files in the directory, sorted by last write time
    $backupFiles = Get-ChildItem -Path $backupDir -Filter "navdata_*.sqlite" | Sort-Object LastWriteTime -Descending

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
Register-ObjectEvent $watcher "Changed" -Action $action  # Only trigger on changes

# Run an infinite loop to keep the script active
while ($true) {sleep 5}
