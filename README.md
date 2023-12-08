# RTCWPro Launcher 
Simple powershell script to update and launch our game client. 

Needs to be placed in the root directory of the game, ie: C:\Program Files\Return To Castle Wolfenstein\ 

### Useful Links
  - [RtCWpro](https://github.com/rtcwmp-com/rtcwPro) - RTCWPro Github
  - [RTCW Match Server](https://github.com/msh100/rtcw) - RTCWPro Docker Server

### Compile Method
For current gather and public use we compile [wolfMP.ps1](main/wolfMP.ps1) via [ps2exe](https://github.com/MScholtes/PS2EXE) using the arguments: 
```
ps2exe -iconFile 'wolfMP.ico' -description 'RtCWPro Launcher' -product 'RtCWPro' -copyright 'WolfMP.com' -version '1.3' -noOutput -noConsole -requireAdmin -title 'RtCWPro Launcher' -company 'WolfMP.com' -trademark 'WolfMP.com' .\wolfMP.ps1 .\wolfMP.exe
```

## [wolfMP.ps1](main/wolfMP.ps1)

- Extract the version from filename and compare it against the latest version of the filename provided in the github release api for RtCWPro.
- A successful match launches the game and exits.


### Otherwise:
- Download rtcwpro_"version"_client.zip, extract it to a temp folder and name the .exe appropriately to reflect the version tag in the filename.
- Clean-up the client from old rtcwpro_*.pk3 assets to force a fresh download from the server as old/mismatching assets can frequently cause issues.
- Create a backup of our wolfconfig_mp.cfg files in their respective folders. This should help preserve settings for users with config issues. 
- Compare list of *.pk3's in Main/ against [list of actively played custom maps](https://github.com/Oksii/autoexec_timer#supported-custom-maps).
- Download any missing maps from the community repository at: http://rtcw.life/files/mapdb/ 

## Additional Configuration: 
You can declare additional settings or deviate from the default variables by providing a [wolfMP.config](main/wolfMP.config.example) file. 
Available parameters: 
| Parameter | Default | Function | 
| :----: | --- | --- |
| $RepoOwner | rtcwmp-com | $RepoOwner used in github string
| $RepoName | rtcwPro | $RepoName used in github string
| $ReleaseApiUrl | https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest | Default release API 
| $GitHubPk3Url | https://raw.githubusercontent.com/Oksii/autoexec_timer/main/README.md | List of Costum Maps to download
| $Pk3DownloadUrlBase | http://rtcw.life/files/mapdb/ | Map repository 
| $RtcwArgs | +set fs_game rtcwpro | Append launch arguments to wolfMP.exe, ie: +exec autoexec.cfg +connect serverIP:password
| $BackupDateFormat | yyyy-MM-dd | Date Format used in backup.cfg files
| $RtcwproSubPath | rtcwpro | rtcwpro/ Folder Path 
| $MainSubPath | Main | Main/ Folder Path
| $AdditionalProcess | null | *Disabled by Default:* Can be used to start additional processes, ie RInput.exe, OBS.exe. See [wolfMP.config](main/wolfMP.config.example) for example usage. 
| $AdditionalProcessPath | null | *Disabled by Default:* Path used for the above, full folder Path needed 
| $AdditionalProcessArgs | null | *Disabled by Default:* Argument for the Process to use. Example RInput we need to tell it what wolfMP_"version".exe to attach to 
| $AdditionalProcessDelay | null | *Disabled by Default:* Delay in seconds before starting our additional Process


### Known Issues and workarounds
- Some AMD graphic cards may incorrectly draw textures on long distance, this seems to be caused by renaming the wolfMP.exe. Possibly related to code in ui_main in the game. Setting "r_depthbits 32" fixes this issue. 
- OBS Game Capture specifically set to woflMP.exe and "Window title must match" or "Match title, otherwise find window of same executable"  may fail to capture the window. Set Window Match Priority to: "Match title, otherwise find window **of same type**". Or Update Window to "wolfMP_130.exe" though the latter will require updating whenever a new wolfMP.exe is released. 
