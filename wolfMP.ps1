# Define variables
$webAddress = "https://maps.oksii.eu/rtcwpro/"
$tempFolder = "temp"
$executableName = "wolfMP.exe"
$subdirectoryName = "rtcwpro"

# Use current working directory as local folder
$localFolder = Get-Location

# Construct full paths
$tempPath = Join-Path -Path $localFolder -ChildPath $tempFolder
$executablePath = Join-Path -Path $localFolder -ChildPath $executableName
$subdirectoryPath = Join-Path -Path $localFolder -ChildPath $subdirectoryName

# Download the web index
$webIndex = Invoke-WebRequest -Uri $webAddress

# Extract version from the file name on the web index
$matches = [regex]::Matches($webIndex.Content, 'rtcwpro_(\d+)_client.zip')
if ($matches.Count -eq 0) {
    Write-Host "Error: No matching file found on the web index."
    exit
}

$webVersion = $matches[0].Groups[1].Value

# Check if local version matches
if (Test-Path $executablePath -PathType Leaf) {
    $localVersion = [regex]::Match($executablePath, 'wolfMP_(\d+).exe').Groups[1].Value

    if ($localVersion -eq $webVersion) {
        Write-Host "Local version is up to date. Launching $executablePath"
        Start-Process $executablePath -ArgumentList "+set fs_game rtcwpro"
        exit
    }
}

# Create the temp folder
New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

# Delete rtcwpro_*.pk3 files if updating wolfMP_<version>.exe
if (Test-Path $executablePath -PathType Leaf) {
    Write-Host "Deleting rtcwpro_*.pk3 files from $subdirectoryPath..."
    Get-ChildItem -Path $subdirectoryPath -Filter "rtcwpro_*.pk3" | Remove-Item -Force
}

# Download and extract the updated executable
$executableUrl = "$webAddress/rtcwpro_$($webVersion)_client.zip"
$archiveTempPath = Join-Path -Path $tempPath -ChildPath "rtcwpro_$($webVersion)_client.zip"

Write-Host "Downloading $executableUrl..."
Invoke-WebRequest -Uri $executableUrl -OutFile $archiveTempPath

# Extract the contents of the downloaded archive
Expand-Archive -Path $archiveTempPath -DestinationPath $tempPath -Force

# Rename "wolfMP.exe" to "wolfMP_<version>.exe"
$downloadedExecutablePath = Join-Path -Path $tempPath -ChildPath "wolfMP.exe"
if (Test-Path $downloadedExecutablePath -PathType Leaf) {
    $newExecutableName = "wolfMP_$webVersion.exe"
    Rename-Item -Path $downloadedExecutablePath -NewName $newExecutableName -Force
}

# Move files to the root folder
Get-ChildItem -Path $tempPath | Move-Item -Destination $localFolder -Force

# Remove temp folder
Remove-Item -Path $tempPath -Recurse -Force

# Clean up: Delete the downloaded .zip archive
Remove-Item -Path "$localFolder\rtcwpro_$($webVersion)_client.zip" -Force

# Clean up: Delete any .exe files that do not match "wolfMP_<version>.exe" (excluding <version> MINUS 1)
Get-ChildItem -Path $localFolder -Filter "wolfMP_*.exe" | ForEach-Object {
    $currentVersion = [regex]::Match($_.Name, 'wolfMP_(\d+).exe').Groups[1].Value
    if ($currentVersion -ne $webVersion -and $currentVersion -ne ($webVersion - 1)) {
        Remove-Item -Path $_.FullName -Force
    }
}

# Launch the newly downloaded executable
$launchedExecutablePath = Join-Path -Path $localFolder -ChildPath $newExecutableName
Write-Host "Launching $launchedExecutablePath"
Start-Process $launchedExecutablePath -ArgumentList "+set fs_game rtcwpro"
