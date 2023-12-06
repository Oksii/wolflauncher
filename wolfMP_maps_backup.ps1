# Define variables
$repoOwner = "rtcwmp-com"
$repoName = "rtcwPro"
$releaseApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
$executableNamePrefix = "wolfMP"
$tempFolder = "temp"

# Define subdirectories
$rtcwproSubPath = "rtcwpro"
$mainSubPath = "Main"

# Use the current working directory as the local folder
$localFolder = Get-Location

# Define the format for the backup date
$backupDateFormat = "yyyy-MM-dd"
$backupDate = Get-Date -Format $backupDateFormat

# Define the maps URL
$websiteUrl = "https://maps.oksii.eu/"

# Fetch the release information
$releaseInfo = Invoke-RestMethod -Uri $releaseApiUrl

# Extract the version from the asset name
$asset = $releaseInfo.assets | Where-Object { $_.name -match 'rtcwpro_(\d+)_client.zip' }

if ($asset) {
    $assetVersion = $matches[1]

    # Construct the local executable path
    $localExecutablePath = Join-Path -Path $localFolder -ChildPath "$executableNamePrefix_$assetVersion.exe"

    # Construct the subdirectories
    $rtcwproFullPath = Join-Path -Path $localFolder -ChildPath $rtcwproSubPath
    $mainFullPath = Join-Path -Path $localFolder -ChildPath $mainSubPath
    
    # Check if local version matches
    $localVersions = Get-ChildItem -Path $localFolder -Filter "wolfMP_*.exe" | ForEach-Object {
        [regex]::Match($_.Name, 'wolfMP_(\d+).exe').Groups[1].Value
    }

    if ($localVersions -contains $assetVersion) {
        Write-Host "Local version is up to date. Launching wolfMP_$assetVersion.exe"
        Start-Process "$localFolder\wolfMP_$assetVersion.exe" -ArgumentList "+set fs_game rtcwpro"
        exit
    }
    
    # Construct the backup paths
    $rtcwproBackupFileName = "backup_${assetVersion}_${backupDate}.cfg"
    $mainBackupFileName = "backup_${assetVersion}_${backupDate}.cfg"
    
    $rtcwproBackupPath = Join-Path -Path $rtcwproFullPath -ChildPath $rtcwproBackupFileName
    $mainBackupPath = Join-Path -Path $mainFullPath -ChildPath $mainBackupFileName
    
    # Directly specify the paths without using Join-Path
    Copy-Item -Path "$rtcwproFullPath\wolfconfig_mp.cfg" -Destination "$rtcwproBackupPath" -Force
    Copy-Item -Path "$mainFullPath\wolfconfig_mp.cfg" -Destination "$mainBackupPath" -Force
    
    # Create the temp folder
    $tempPath = Join-Path -Path $localFolder -ChildPath $tempFolder
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

    # Download the asset
    $downloadUrl = $asset.browser_download_url
    Write-Host "Downloading $asset.name..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile (Join-Path -Path $tempPath -ChildPath $asset.name)

    # Extract the contents of the downloaded archive
    Expand-Archive -Path (Join-Path -Path $tempPath -ChildPath $asset.name) -DestinationPath $tempPath -Force
	
    # Download and parse the list of .pk3 files from the website
    function Get-WebsitePk3List {
        $webpageContent = Invoke-WebRequest -Uri $websiteUrl
        $pk3Files = $webpageContent.AllElements | Where-Object { $_.TagName -eq "a" -and $_.href -like "*.pk3" } | ForEach-Object {
            [System.IO.Path]::GetFileName($_.href)
        }

        return $pk3Files
    }

    # Check if local version matches
    $localVersions = Get-ChildItem -Path $localFolder -Filter "wolfMP_*.exe" | ForEach-Object {
        [regex]::Match($_.Name, 'wolfMP_(\d+).exe').Groups[1].Value
    }

    if ($localVersions -contains $assetVersion) {
        Write-Host "Local version is up to date. Launching wolfMP_$assetVersion.exe"
        Start-Process "$localFolder\wolfMP_$assetVersion.exe" -ArgumentList "+set fs_game rtcwpro"
        exit
    }

    # Download and parse the list of .pk3 files from the website
    $websitePk3List = Get-WebsitePk3List

    # Compare with the list of .pk3 files in the Main directory
    $mainPk3Path = Join-Path -Path $localFolder -ChildPath $mainSubPath
    $missingPk3Files = $websitePk3List | Where-Object { -not (Test-Path (Join-Path -Path $mainPk3Path -ChildPath $_)) }
    
    # Download missing .pk3 files and move them to the Main directory
    if ($missingPk3Files.Count -gt 0) {
        Write-Host "Downloading and moving missing .pk3 files to Main directory..."
        foreach ($missingPk3File in $missingPk3Files) {
            $pk3DownloadUrl = "$websiteUrl$missingPk3File"
            $pk3DownloadPath = Join-Path -Path $mainPk3Path -ChildPath $missingPk3File
    
            if (-not (Test-Path $pk3DownloadPath)) {
                Invoke-WebRequest -Uri $pk3DownloadUrl -OutFile $pk3DownloadPath
            }
        }
    }

    # Delete rtcwpro_*.pk3 files if updating wolfMP_<version>.exe
    if (Test-Path $rtcwproFullPath -PathType Container) {
        Write-Host "Deleting rtcwpro_*.pk3 files from $rtcwproFullPath..."
        Get-ChildItem -Path $rtcwproFullPath -Filter "rtcwpro_*.pk3" | Remove-Item -Force
    }
    
    
    # Rename "wolfMP.exe" to "wolfMP_<version>.exe"
    $downloadedExecutablePath = Join-Path -Path $tempPath -ChildPath "wolfMP.exe"
    if (Test-Path $downloadedExecutablePath -PathType Leaf) {
        $newExecutableName = "wolfMP_$assetVersion.exe"
        Rename-Item -Path $downloadedExecutablePath -NewName $newExecutableName -Force
    }

    # Move files to the root folder
    Get-ChildItem -Path $tempPath | Move-Item -Destination $localFolder -Force

    # Clean up: Delete rtcwpro_<version>_client.zip
    Remove-Item -Path (Join-Path -Path $localFolder -ChildPath $asset.name) -Force

    # Clean up: Delete temp folder
    Remove-Item -Path $tempPath -Recurse -Force

    # Clean up: Delete any .exe files that do not match "wolfMP_<version>.exe" (excluding <version> MINUS 1)
    Get-ChildItem -Path $localFolder -Filter "wolfMP_*.exe" | ForEach-Object {
        $currentVersion = [regex]::Match($_.Name, 'wolfMP_(\d+).exe').Groups[1].Value
        if ($currentVersion -ne $assetVersion -and $currentVersion -ne ($assetVersion - 1)) {
            Remove-Item -Path $_.FullName -Force
        }
    }

    # Launch the newly downloaded executable
    $launchedExecutablePath = Join-Path -Path $localFolder -ChildPath $newExecutableName
    Write-Host "Launching $launchedExecutablePath"
    Start-Process $launchedExecutablePath -ArgumentList "+set fs_game rtcwpro"
}
else {
    Write-Host "Error: No matching asset found."
}
