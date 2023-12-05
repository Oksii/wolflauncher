# Define variables
$repoOwner = "rtcwmp-com"
$repoName = "rtcwPro"
$releaseApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
$executableNamePrefix = "wolfMP"
$tempFolder = "temp"

# Use the current working directory as the local folder
$localFolder = Get-Location

# Fetch the release information
$releaseInfo = Invoke-RestMethod -Uri $releaseApiUrl

# Extract the version from the asset name
$asset = $releaseInfo.assets | Where-Object { $_.name -match 'rtcwpro_(\d+)_client.zip' }

if ($asset) {
    $assetVersion = $matches[1]

    # Construct the local executable path
    $localExecutablePath = Join-Path -Path $localFolder -ChildPath "$executableNamePrefix_$assetVersion.exe"

    # Check if local version matches
    $localVersions = Get-ChildItem -Path $localFolder -Filter "wolfMP_*.exe" | ForEach-Object {
        [regex]::Match($_.Name, 'wolfMP_(\d+).exe').Groups[1].Value
    }

    if ($localVersions -contains $assetVersion) {
        Write-Host "Local version is up to date. Launching wolfMP_$assetVersion.exe"
        Start-Process "$localFolder\wolfMP_$assetVersion.exe" -ArgumentList "+set fs_game rtcwpro"
        exit
    }


    # Create the temp folder
    $tempPath = Join-Path -Path $localFolder -ChildPath $tempFolder
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

    # Download the asset
    $downloadUrl = $asset.browser_download_url
    Write-Host "Downloading $asset.name..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile (Join-Path -Path $tempPath -ChildPath $asset.name)

    # Extract the contents of the downloaded archive
    Expand-Archive -Path (Join-Path -Path $tempPath -ChildPath $asset.name) -DestinationPath $tempPath -Force

    # Delete rtcwpro_*.pk3 files if updating wolfMP_<version>.exe
    $rtcwproPath = Join-Path -Path $localFolder -ChildPath "rtcwpro"
    if (Test-Path $rtcwproPath -PathType Container) {
        Write-Host "Deleting rtcwpro_*.pk3 files from $rtcwproPath..."
        Get-ChildItem -Path $rtcwproPath -Filter "rtcwpro_*.pk3" | Remove-Item -Force
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
