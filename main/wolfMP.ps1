# Localpath 
$localFolder = Get-Location

# Load configurations from wolfMP.config if available
$configFilePath = Join-Path -Path $localFolder -ChildPath "wolfMP.config"
if (Test-Path $configFilePath) {
    Write-Host "Loading configurations from wolfMP.config..."
    
    # Read the content of the file
    $configContent = Get-Content -Path $configFilePath -Raw | Out-String
    
    # Execute the content as PowerShell code
    Invoke-Expression $configContent
}

# Default values
if ($null -eq $repoOwner) { $repoOwner = "rtcwmp-com" }
if ($null -eq $repoName) { $repoName = "rtcwPro" }
if ($null -eq $releaseApiUrl) { $releaseApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest" }
if ($null -eq $gitHubPk3Url) { $gitHubPk3Url = "https://raw.githubusercontent.com/Oksii/autoexec_timer/main/README.md" }
if ($null -eq $pk3DownloadUrlBase) { $pk3DownloadUrlBase = "http://rtcw.life/files/mapdb/" }
if ($null -eq $executableNamePrefix) { $executableNamePrefix = "wolfMP" }

# backups 
if ($null -eq $backupDateFormat) { $backupDateFormat = "yyyy-MM-dd" }
if ($null -eq $backupDate) { $backupDate = Get-Date -Format $backupDateFormat }

# Directories
if ($null -eq $tempFolder) { $tempFolder = "temp" }
if ($null -eq $mainSubPath) { $mainSubPath = "Main" }
if ($null -eq $rtcwproSubPath) { $rtcwproSubPath = "rtcwpro" }

# rtcw 
if ($null -eq $rtcwArgs) { $rtcwArgs = "+set fs_game rtcwpro" }

# Check if Additional Process is enabled in the config
if ($null -ne $AdditionalProcess) {
    $additionalProcessEnabled = $true

    # Set Additional Process Path
    $additionalProcessPath = $AdditionalProcessPath

    # Set Additional Process Delay (use default if not provided)
    $additionalProcessDelay = $AdditionalProcessDelay
    if (-not $additionalProcessDelay) {
        $additionalProcessDelay = 3
    }

    # Set Additional Process (with full path)
    $additionalProcessExecutable = Join-Path -Path $additionalProcessPath -ChildPath $AdditionalProcess

    Write-Host "Additional Process Path: $additionalProcessPath"
    Write-Host "Additional Process: $additionalProcessExecutable"

    # Set Additional Process Arguments (use default if not provided)
    $additionalProcessArgs = $AdditionalProcessArgs
    if (-not $additionalProcessArgs) {
        $additionalProcessArgs = @()
    }
}

# Fetch the release information
$releaseInfo = Invoke-RestMethod -Uri $releaseApiUrl

# Extract the version from the asset name
$asset = $releaseInfo.assets | Where-Object { $_.name -match 'rtcwpro_(\d+)_client.zip' }

if ($asset) {
    $assetVersion = $matches[1]

    # Construct paths
    $localExecutablePath = Join-Path -Path $localFolder -ChildPath "$executableNamePrefix_$assetVersion.exe"
    $rtcwproFullPath = Join-Path -Path $localFolder -ChildPath $rtcwproSubPath
    $mainFullPath = Join-Path -Path $localFolder -ChildPath $mainSubPath
    $rtcwproBackupFileName = "backup_${assetVersion}_${backupDate}.cfg"
    $mainBackupFileName = "backup_${assetVersion}_${backupDate}.cfg"
    $rtcwproBackupPath = Join-Path -Path $rtcwproFullPath -ChildPath $rtcwproBackupFileName
    $mainBackupPath = Join-Path -Path $mainFullPath -ChildPath $mainBackupFileName
    $tempPath = Join-Path -Path $localFolder -ChildPath $tempFolder

    # Check if local version matches
    $localVersions = Get-ChildItem -Path $localFolder -Filter "wolfMP_*.exe" | ForEach-Object {
        [regex]::Match($_.Name, 'wolfMP_(\d+).exe').Groups[1].Value
    }

    if ($localVersions -contains $assetVersion) {
        Write-Host "Local version is up to date. Launching wolfMP_$assetVersion.exe"
        Start-Process "$localFolder\wolfMP_$assetVersion.exe" -ArgumentList $rtcwArgs
        
        # Additional Process (if enabled)
        if ($additionalProcessEnabled) {
            Write-Host "Launching Additional Process: $additionalProcessExecutable"
            Start-Sleep -Seconds $additionalProcessDelay
        
            if ($additionalProcessArgs) {
                Write-Host "Arguments for Additional Process: $additionalProcessArgs"
                Start-Process -FilePath $additionalProcessExecutable -ArgumentList $additionalProcessArgs
            } else {
                Write-Host "Launching Additional Process without arguments."
                Start-Process -FilePath $additionalProcessExecutable
            }
        }
        exit
    }

    # Backup configuration files
    Copy-Item -Path "$rtcwproFullPath\wolfconfig_mp.cfg" -Destination "$rtcwproBackupPath" -Force
    Copy-Item -Path "$mainFullPath\wolfconfig_mp.cfg" -Destination "$mainBackupPath" -Force

    # Create temp folder
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

    # Download the asset
    $downloadUrl = $asset.browser_download_url
    Write-Host "Downloading $asset.name..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile (Join-Path -Path $tempPath -ChildPath $asset.name)

    # Extract contents of the downloaded archive
    Expand-Archive -Path (Join-Path -Path $tempPath -ChildPath $asset.name) -DestinationPath $tempPath -Force

    function Get-GitHubPk3ListFromReadme {
        param (
            [string]$ReadmeUrl
        )
    
        $readmeContent = Invoke-RestMethod -Uri $ReadmeUrl
    
        $supportedMapsIndex = $readmeContent.IndexOf("### Supported custom maps")
        if ($supportedMapsIndex -ge 0) {
            $pk3Section = $readmeContent.Substring($supportedMapsIndex)
            $pk3Files = $pk3Section -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and $_ -match '\.pk3$' }
            return $pk3Files
        } else {
            Write-Host "Error: Unable to find the '### Supported custom maps' section in the Readme."
            return @()
        }
    }

    # Download and parse list of .pk3 files from GitHub README.md
    $gitHubPk3List = Get-GitHubPk3ListFromReadme -ReadmeUrl $gitHubPk3Url

    # Compare with .pk3 files in the Main directory
    $mainPk3Path = Join-Path -Path $localFolder -ChildPath $mainSubPath
    $missingPk3Files = $gitHubPk3List | Where-Object { -not (Test-Path (Join-Path -Path $mainPk3Path -ChildPath $_)) }

    # Download missing .pk3 files and move them to the Main directory
    if ($missingPk3Files.Count -gt 0) {
        Write-Host "Downloading and moving missing .pk3 files to Main directory..."
        foreach ($missingPk3File in $missingPk3Files) {
            $pk3DownloadUrl = "$pk3DownloadUrlBase$missingPk3File"
            $pk3DownloadPath = Join-Path -Path $mainPk3Path -ChildPath $missingPk3File

            try {
                Invoke-WebRequest -Uri $pk3DownloadUrl -OutFile $pk3DownloadPath -ErrorAction Stop
                Write-Host ("Downloaded: {0}" -f $missingPk3File)
            } catch {
                $errorMessage = $_.Exception.Message
                Write-Host ("Error downloading {0}: {1}" -f $pk3DownloadUrl, $errorMessage -replace ':', '_')
            }
        }
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
    Start-Process $launchedExecutablePath -ArgumentList $rtcwArgs

    # Additional Process (if enabled)
    if ($additionalProcessEnabled) {
        Write-Host "Launching Additional Process: $additionalProcessExecutable"
        Start-Sleep -Seconds $additionalProcessDelay
    
        if ($additionalProcessArgs) {
            Write-Host "Arguments for Additional Process: $additionalProcessArgs"
            Start-Process -FilePath $additionalProcessExecutable -ArgumentList $additionalProcessArgs
        } else {
            Write-Host "Launching Additional Process without arguments."
            Start-Process -FilePath $additionalProcessExecutable
        }
    }
} else {
    Write-Host "Error: No matching asset found."
}
