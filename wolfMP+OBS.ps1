# Define variables
$repoOwner = "rtcwmp-com"
$repoName = "rtcwPro"
$releaseApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
$executableNamePrefix = "wolfMP"
$tempFolder = "temp"
$userArgument = $null

# Function to check if a process is running
function Test-ProcessRunning {
    param (
        [string]$processName
    )

    Get-Process -Name $processName -ErrorAction SilentlyContinue
}

# Function to terminate a process
function Stop-ProcessByName {
    param (
        [string]$processName
    )

    $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "Terminating $processName process..."
        Stop-Process -Name $processName -Force
    }
}

# Function to get user input with a 5-second timeout
function Get-UserInputWithTimer {
    param (
        [string]$prompt,
        [int]$timeoutSeconds
    )

    $timeout = (Get-Date).AddSeconds($timeoutSeconds)
    $input = $null

    while ((Get-Date) -le $timeout) {
        $input = Read-Host $prompt
        if ($input -ne "") {
            break
        }
    }

    return $input
}

# Ask user for additional argument with a 5-second timeout
$userArgument = Get-UserInputWithTimer -prompt "Enter additional argument (or press Enter to continue):" -timeoutSeconds 3

# Default to "nl.rtcw.eu" if no input is provided
if (-not $userArgument) {
    $userArgument = "nl.rtcw.eu"
    Write-Host "No input provided within 5 seconds. Defaulting to $userArgument."
} else {
    Write-Host "User provided input: $userArgument."
}

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
        Start-Process "$localFolder\wolfMP_$assetVersion.exe" -ArgumentList "+set fs_game rtcwpro +exec autoexec.cfg +connect $userArgument" -NoNewWindow

        # Start OBS process
        Start-Process -FilePath "C:\Program Files\obs-studio\bin\64bit\obs64.exe" -WorkingDirectory "C:\Program Files\obs-studio\bin\64bit\" -ArgumentList '--profile "shadowplay" --minimize-to-tray --startreplaybuffer --disable-shutdown-check'

        # Main loop
        while ($true) {
            # Check if wolfMP process is running
            $wolfMPProcess = Test-ProcessRunning -processName "wolfMP_$assetVersion"

            if ($wolfMPProcess) {
                Write-Host "wolfMP_$assetVersion.exe process is running."
            } else {
                Write-Host "wolfMP_$assetVersion.exe process not found. Terminating obs64.exe."

                # Terminate obs64.exe
                Stop-Process -Name "obs64"

                # Exit the loop if obs64.exe is not running
                if (-not (Test-ProcessRunning -processName "obs64.exe")) {
                    Write-Host "obs64.exe process not found. Exiting script."
                    break
                }
            }

            # Sleep for a short interval before checking again
            Start-Sleep -Seconds 10
        }

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
    Start-Process $launchedExecutablePath -ArgumentList "+set fs_game rtcwpro +exec autoexec.cfg +connect $userArgument" -NoNewWindow

    # Start OBS process
    Start-Process -FilePath "C:\Program Files\obs-studio\bin\64bit\obs64.exe" -WorkingDirectory "C:\Program Files\obs-studio\bin\64bit\" -ArgumentList '--profile "shadowplay" --minimize-to-tray --startreplaybuffer --disable-shutdown-check'

    # Main loop
    while ($true) {
        # Check if wolfMP process is running
        $wolfMPProcess = Test-ProcessRunning -processName "wolfMP_$assetVersion"

        if ($wolfMPProcess) {
            Write-Host "wolfMP_$assetVersion.exe process is running."
        } else {
            Write-Host "wolfMP_$assetVersion.exe process not found. Terminating obs64.exe."

            # Terminate obs64.exe
            Stop-Process -Name "obs64"

            # Exit the loop if obs64.exe is not running
            if (-not (Test-ProcessRunning -processName "obs64.exe")) {
                Write-Host "obs64.exe process not found. Exiting script."
                break
            }
        }

        # Sleep for a short interval before checking again
        Start-Sleep -Seconds 10
    }
} else {
    Write-Host "Error: No matching asset found."
}
