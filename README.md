# RtCWPro Launcher 

Simple powershell script to update and launch our game client. 

Needs to be placed in the root directory of the game, ie: C:\Program Files\Return To Castle Wolfenstein\ 

For current gather and public use we compile [wolfMP_maps_backup.ps1](wolfMP_maps_backup.ps1) via [ps2exe](https://github.com/MScholtes/PS2EXE) using the arguments: 
```
ps2exe -iconFile 'wolfMP.ico' -description 'RtCWPro Launcher' -product 'RtCWPro' -copyright 'WolfMP.com' -version '1.3' -noOutput -noConsole -requireAdmin -title 'RtCWPro Launcher' -company 'WolfMP.com' -trademark 'WolfMP.com' .\wolfMP_maps_backup.ps1 .\wolfMP.exe
```

## [wolfMP.ps1](wolfMP.ps1)

It'll extract the version from the filename and compare it against the latest version of the filename provided in the github release api for [RtCWPro](https://github.com/rtcwmp-com/rtcwPro/releases). 

A succesful match launches the game and exits. 

Otherwise download rtcwpro_<version>_client.zip, extract it to a temp folder and name the .exe appropriately to reflect the version tag in the filename.

We further clean-up the client from old rtcwpro_*.pk3 assets to force a fresh download from the server as old/mismatching assets can frequently cause issues. 


## [wolfMP_maps_backup.ps1](wolfMP_maps_backup.ps1)

Additionally try to create a backup of our wolfconfig_mp.cfg files in their respective folders as some users complain about config issues after an update. This should hopefully help them preserve settings. 

We assume that most people using this are players that haven't played in a long time or are fresh installs, as updates to the client.exe are very very infrequent, therefor it's worth checking if they're missing any of the actively played maps and download them if necessary. 

We're doing so by comparing the filenames of the *.pk3 files in their Main/ directory against this [list of actively played custom maps](https://github.com/Oksii/autoexec_timer#supported-custom-maps).

If necessary download any missing files from the community repository at: http://rtcw.life/files/mapdb/


## [wolfMP_OBS_config.ps1](wolfMP_OBS_config.ps1) 

Additionally to all of the above we'll also be launching OBS with a set of arguments alongside our client.exe, this version is designed for personal use and really only aimed at the specific usecase, but could be adopted easily by changing default variables that we declare and export to [wolfMP.config](wolfMP.config.example)

Any configuration provided will overwrite default values set in the script. 

The script will monitor the activity of wolfMP_*.exe, if the game stops running, we'll silently kill the OBS process as well. 

As OBS is running with elevated privileges to capture hotkeys, the script is required to be ran as admin as well.
