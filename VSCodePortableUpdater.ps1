#--------------------
# INITIALIZE
#--------------------

$feedURI = "https://code.visualstudio.com/feed.xml"

$directDownloadURI = "https://vscode-update.azurewebsites.net/xVERSIONx/win32-x64-archive/stable/"
# https://vscode-update.azurewebsites.net/latest/win32-x64-archive/stable
# https://vscode-update.azurewebsites.net/1.32.3/win32-x64-archive/stable

$dirLocalRoot = Get-Item -Path "D:\VSCodePortable"
$dirDownload = New-item -Path "$dirLocalRoot\Downloads" -ItemType Directory -ErrorAction SilentlyContinue -Force

$DownloadVersions = Get-ChildItem -Path $dirDownload -Filter "*.zip"
$AppVersions = Get-ChildItem -Path $dirLocalRoot -Directory | Where-Object {$_.Name -match "[0-9]{1}\.[0-9]{2}"}

$versionBaseName = "VSCode-"

$keepDownloadVersions = 3
$keepAppVersions = 2


#--------------------
# MAIN
#--------------------

# get news from feed
$feedPosts = Invoke-RestMethod -Uri $feedURI

# search for new versions in feed
$feedVersions = @()
$feedPosts | Select-Object -First 5 | ForEach-Object {
    if ($_.Id -match "updates/v[0-9]{1}_[0-9]{2}") {

        # extract version from regex match
        $feedVersion = ($Matches[0] -split "updates/v")[1] -replace "_","."

        # expand version to full release number
        if ($feedVersion.split(".").count -eq 2) {
            $feedVersion = $feedVersion + ".0"
        }

        # object to store version
        $tempVersion = [PSCustomObject]@{
            Full = [string]$feedVersion
            Major = [decimal](($feedVersion.Split('.',3) | Select-Object -Index 0,1) -join ".")
            Minor = [decimal](($feedVersion.Split('.',3) | Select-Object -Index 1,2) -join ".")
        }

        # update collection array
        $feedVersions += $tempVersion
    }
}
$feedLatestVersion = $feedVersions | Sort-Object Full -Descending | Select-Object -First 1

# search for local version
$AppVersionsDetail = @()
$AppVersions | Foreach-Object {
    
    $localVersion = ($_.Name -split "$versionBaseName")[1]

    # object to store version
    $tempVersion = [PSCustomObject]@{
        Full = [string]$localVersion
        Major = [decimal](($localVersion.Split('.',3) | Select-Object -Index 0,1) -join ".")
        Minor = [decimal](($localVersion.Split('.',3) | Select-Object -Index 1,2) -join ".")
        Directory = $_
    }

    $AppVersionsDetail += $tempVersion
}
$AppVersionLatest = $AppVersionsDetail | Sort-Object Full -Descending | Select-Object -First 1

# check for newer major version
if ($feedLatestVersion.Major -gt $AppVersionLatest.Major) {
    $selectedMajor = $feedLatestVersion.Major
    $selectedMinor = $feedLatestVersion.Minor
}
else {
    $selectedMajor = $AppVersionLatest.Major
    $selectedMinor = $AppVersionLatest.Minor
}

# search for minor version of selected major
[decimal]$maxIncrease = [math]::Floor($selectedMinor + 1) - 0.1
do {
    # tackle the full versions
    if ($selectedMinor%1 -eq 0) {
        $selectedMinorString = ".0"
    }
    else {
        $selectedMinorString = ".$(($selectedMinor.ToString().Split('.'))[1])"
    }

    # perpare current URI
    $tempDownloadUri = $directDownloadURI -replace "xVERSIONx","$($selectedMajor)$($selectedMinorString)"

    # Test generated URIs
    try {
        Invoke-WebRequest -Uri $tempDownloadUri -Method Head | Out-Null
        $downloadVersion = "$($selectedMajor)$($selectedMinorString)"
        $downloadVersionUri = $tempDownloadUri        
    }
    catch {
        Write-Verbose "$($Error[0].Exception.Message)"
    }

    $selectedMinor += 0.1
}
until ($selectedMinor -gt $maxIncrease)

# check if version already downloaded
if ($downloadVersion -eq $AppVersionLatest.Full) {
    Write-Verbose "Latest version already downloaded and installed!"
    exit
}

# download file
$downloadFilePath = "$($dirDownload)\$($versionBaseName)$($downloadVersion).zip"
$downloadRequest = Invoke-WebRequest -Uri $downloadVersionUri -OutFile $downloadFilePath -PassThru

# check HTTP StatusCode
if ($downloadRequest.StatusCode -ne 200) {
    Write-Verbose "Download failed with error '$($downloadRequest.StatusCode) - $($downloadRequest.StatusDescription)'" -Verbose
    Remove-Item -Path $downloadFilePath -Force -Verbose -ErrorAction SilentlyContinue
    exit
}

# create new folder and extract zip file
$dirNewVersion = New-Item -Path "$($dirLocalRoot)\$($versionBaseName)$($downloadVersion)" -ItemType Directory -Force
Expand-Archive -Path $downloadFilePath -DestinationPath $dirNewVersion -Force | Out-Null

# copy data from current version
Copy-Item -Path "$($AppVersionLatest.Directory.FullName)\data" -Destination "$dirNewVersion\data" -Recurse -Force

# apply retention settings
$DownloadVersions = Get-ChildItem -Path $dirDownload -Filter "*.zip"
$DownloadVersions | Sort-Object | Select-Object -SkipLast $keepDownloadVersions | Remove-Item -Force -Confirm:$false

$AppVersions = Get-ChildItem -Path $dirLocalRoot -Directory | Where-Object {$_.Name -match "[0-9]{1}\.[0-9]{2}"}
$AppVersions | Sort-Object | Select-Object -SkipLast $keepAppVersions | Remove-Item -Recurse -Force -Confirm:$false