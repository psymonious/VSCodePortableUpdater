# VSCodePortableUpdater

A PowerShell approach on an autoupdater for Visual Studio Code Portable

## Basic functionality
- parse the news feed and look for major updates
- test direct download uri for minor versions
- download and extract latest
- copy data folder of last version to new one
- cleanup old versions

## PowerShell versions
- Windows PowerShell 5.1
- PowerShell 6.0.2

## Notes / Recommendations
- If you change the 'versionBaseName' make sure you also rename your app and download directories to that name (i only sort and don't care about any datetime attribute)
- It works fine with PowerShell 5.1 but i does run faster in PowerShell 6.0.2