Function Start-Cleanup {

    ## Allows the use of -WhatIf
    [CmdletBinding(SupportsShouldProcess = $True)]

    param(
        ## Delete data older then $daystodelete
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 0)]
        $DaysToDelete = 7,

        ## LogFile path for the transcript to be written to
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 1)]
        $LogFile = ("$env:TEMP\" + (get-date -format "MM-d-yy-HH-mm") + '.log'),

        ## All verbose outputs will get logged in the transcript($logFile)
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 2)]
        $VerbosePreference = "Continue",

        ## All errors should be withheld from the console
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 3)]
        $ErrorActionPreference = "SilentlyContinue"
    )

    ## Begin the timer
    $Starters = (Get-Date)
    ## Check $VerbosePreference variable, and turns on
    Function global:Write-Verbose ( [string]$Message ) {
        if ( $VerbosePreference -ne 'SilentlyContinue' ) {
            Write-Host "$Message" -ForegroundColor 'Green'
        }
    }

    ## Tests if the log file already exists and renames the old file if it does exist
    <#if(Test-Path $LogFile){
        ## Renames the log to be .old
        Rename-Item $LogFile $LogFile.old -Force
    } else {
        ## Starts a transcript in C:\temp so you can see which files were deleted
        Write-Host (Start-Transcript -Path $LogFile) -ForegroundColor Green
    }#>

    ## Writes a verbose output to the screen for user information
    Write-Host "Retrieving Disk Space Statistics...              " -NoNewline -ForegroundColor Green

    ## Gathers the amount of disk space used before running the script
    $Before = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
    @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
    @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f ( $_.Size / 1gb)}},
    @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f ( $_.Freespace / 1gb ) } },
    @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f ( $_.FreeSpace / $_.Size ) } } |
        Format-Table -AutoSize |
        Out-String

    ## Stops the windows update service so that c:\windows\softwaredistribution can be cleaned up
    Get-Service -Name wuauserv | Stop-Service -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # Sets the SCCM cache size to 1 GB if it exists.
    if ((Get-WmiObject -namespace root\ccm\SoftMgmtAgent -class CacheConfig) -ne "$null") {
        # if data is returned and sccm cache is configured it will shrink the size to 1024MB.
        $cache = Get-WmiObject -namespace root\ccm\SoftMgmtAgent -class CacheConfig
        $Cache.size = 1024 | Out-Null
        $Cache.Put() | Out-Null
        Restart-Service ccmexec -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black

    ## Deletes the contents of windows software distribution.
    Write-Host "Cleaning SoftwareDistribution...                 " -NoNewline -ForegroundColor Green
    Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -recurse -ErrorAction SilentlyContinue
    Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black

    ## Deletes the contents of the Windows Temp folder.
    Write-host "Cleaning Windows Temp...                         " -NoNewline -ForegroundColor Green
    Get-ChildItem "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete)) } | Remove-Item -force -recurse -ErrorAction SilentlyContinue
    Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black

    ## Deletes all files and folders in user's Temp folder older then $DaysToDelete
    Write-Host "Cleaning `$env:TEMP...                            " -NoNewline -ForegroundColor Green
    Get-ChildItem "C:\users\*\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete))} |
        Remove-Item -force -recurse -ErrorAction SilentlyContinue
    Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black

    ## Removes all files and folders in user's Temporary Internet Files older then $DaysToDelete
    Write-Host "Cleaning Temporary Internet Files...             " -NoNewline -ForegroundColor Green
    Get-ChildItem "C:\users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" `
        -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete))} |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black

    ## Removes *.log from C:\windows\CBS
    Write-Host "Cleaning CBS Logs...                             " -NoNewline -ForegroundColor Green
    if (Test-Path C:\Windows\logs\CBS\) {
        Get-ChildItem "C:\Windows\logs\CBS\*.log" -Recurse -Force -ErrorAction SilentlyContinue |
            remove-item -force -recurse -ErrorAction SilentlyContinue
        Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black
    }
    else {
        #Write-Host "C:\inetpub\logs\LogFiles\ does not exist, there is nothing to cleanup.                           " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans IIS Logs older then $DaysToDelete
    if (Test-Path C:\inetpub\logs\LogFiles\) {
        Write-Host "Cleaning IIS Logs...                             " -NoNewline -ForegroundColor Green
        Get-ChildItem "C:\inetpub\logs\LogFiles\*" -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-60)) } | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black
    }
    else {
        #Write-Host "C:\Windows\logs\CBS\ does not exist, there is nothing to cleanup.                                   " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Removes C:\Config.Msi
    if (test-path C:\Config.Msi) {
        remove-item -Path C:\Config.Msi -force -recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Config.Msi does not exist, there is nothing to cleanup.                                          " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Removes c:\Intel
    if (test-path C:\Intel) {
        remove-item -Path c:\Intel -force -recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "c:\Intel does not exist, there is nothing to cleanup.                                               " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Removes c:\PerfLogs
    if (test-path C:\PerfLogs) {
        remove-item -Path c:\PerfLogs -force -recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "c:\PerfLogs does not exist, there is nothing to cleanup.                                            " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Removes $env:windir\memory.dmp
    if (test-path $env:windir\memory.dmp) {
        remove-item $env:windir\memory.dmp -force -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Windows\memory.dmp does not exist, there is nothing to cleanup.                                  " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Removes Windows Error Reporting files
    if (test-path C:\ProgramData\Microsoft\Windows\WER) {
        Write-host "Cleaning Windows Error Reporting files...        " -NoNewline -ForegroundColor Green
        Get-ChildItem -Path C:\ProgramData\Microsoft\Windows\WER -Recurse | Remove-Item -force -recurse -ErrorAction SilentlyContinue
        Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black
    }
    else {
        #Write-Host "C:\ProgramData\Microsoft\Windows\WER does not exist, there is nothing to cleanup.              " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Removes System and User Temp Files - lots of access denied will occur.
    ## Cleans up c:\windows\temp
    Write-host "Cleaning System and User Temp files...           " -NoNewline -ForegroundColor Green
    if (Test-Path $env:windir\Temp\) {
        Remove-Item -Path "$env:windir\Temp\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Windows\Temp does not exist, there is nothing to cleanup.                                   " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up minidump
    if (Test-Path $env:windir\minidump\) {
        Remove-Item -Path "$env:windir\minidump\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "$env:windir\minidump\ does not exist, there is nothing to cleanup.                                   " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up prefetch
    if (Test-Path $env:windir\Prefetch\) {
        Remove-Item -Path "$env:windir\Prefetch\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "$env:windir\Prefetch\ does not exist, there is nothing to cleanup.                             " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up each users temp folder
    if (Test-Path "C:\Users\*\AppData\Local\Temp\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Temp\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Users\*\AppData\Local\Temp\ does not exist, there is nothing to cleanup.                    " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up all users windows error reporting
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\WER\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\WER\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\ProgramData\Microsoft\Windows\WER does not exist, there is nothing to cleanup.              " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up users temporary internet files
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\ does not exist.                " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up Internet Explorer cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\ does not exist.                           " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up Internet Explorer cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\ does not exist.                         " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up Internet Explorer download history
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\ does not exist.                       " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up Internet Cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\ does not exist.                               " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up Internet Cookies
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\ does not exist.                             " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Cleans up terminal server cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\*" -Force -Recurse -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\ does not exist.                    " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black

    ## Turns errors back on
    $ErrorActionPreference = "Continue"

    Write-Host "Cleaning Recycle Bin...                          " -NoNewline -ForegroundColor Green
    ## Removes the hidden recycling bin.
    if (Test-path 'C:\$Recycle.Bin') {
        Remove-Item 'C:\$Recycle.Bin' -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        #Write-Host "C:\`$Recycle.Bin does not exist, there is nothing to cleanup.                                        " -NoNewline -ForegroundColor DarkGray
        #Write-Host "[WARNING]" -ForegroundColor DarkYellow -BackgroundColor Black
    }

    ## Checks the version of PowerShell
    ## If PowerShell version 4 or below is installed the following will process
    if ($PSVersionTable.PSVersion.Major -le 4) {

        ## Empties the recycling bin, the desktop recyling bin
        $Recycler = (New-Object -ComObject Shell.Application).NameSpace(0xa)
        $Recycler.items() | ForEach-Object { 
            ## If PowerShell version 4 or bewlow is installed the following will process
            Remove-Item -Include $_.path -Force -Recurse
        }
    }
    elseif ($PSVersionTable.PSVersion.Major -ge 5) {
        ## If PowerShell version 5 is running on the machine the following will process
        Clear-RecycleBin -DriveLetter C:\ -Force
    }
    
    Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black

    ## Starts cleanmgr.exe
    Function Start-CleanMGR {
        Try {
            Write-Host "Running Windows Disk Cleanup...                  " -NoNewline -ForegroundColor Green
            Start-Process -FilePath Cleanmgr -ArgumentList '/sagerun:1' -Wait
            Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black
        }
        Catch [System.Exception] {
            Write-Host "Running Windows Disk Cleanup...                  " -NoNewline -ForegroundColor Green
            Write-Host "[ERROR]" -ForegroundColor Red -BackgroundColor Black
        }
    } 
    Start-CleanMGR

    Write-Host "Retrieving Disk Space Statistics...              " -NoNewline -ForegroundColor Green

    ## gathers disk usage after running the cleanup cmdlets.
    $After = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
    @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
    @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f ( $_.Size / 1gb)}},
    @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f ( $_.Freespace / 1gb ) } },
    @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f ( $_.FreeSpace / $_.Size ) } } |
        Format-Table -AutoSize | Out-String

    ## Restarts wuauserv
    Get-Service -Name wuauserv | Start-Service -ErrorAction SilentlyContinue

    ## Stop timer
    $Enders = (Get-Date)

    Write-Host "[COMPLETE]" -ForegroundColor Green -BackgroundColor Black

    ## Sends the disk usage before running the cleanup script to the console for ticketing purposes.
    Write-Verbose "`r`nBefore: $Before"

    ## Sends the disk usage after running the cleanup script to the console for ticketing purposes.
    Write-Verbose "After: $After"

    Write-Host "Operations completed in $(($Enders - $Starters).totalseconds) seconds.`r`n" -NoNewline -ForegroundColor Green
}
Start-Cleanup

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');