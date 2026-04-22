# Path to your URL list
$UrlFile = "URLs.txt"

# Path to your exported cookies.txt file
$CookieFile = "cookies.txt"

# Output folder
$OutputFolder = ""

# Create folder if needed
if (!(Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

# Load cookies
$Cookies = Import-Csv $CookieFile -Delimiter "`t" -Header domain,flag,path,secure,expiration,name,value |
    Where-Object { $_.domain -like "*airdata.com" }

# Create a WebRequest session
$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

foreach ($c in $Cookies) {
    $cookie = New-Object System.Net.Cookie
    $cookie.Name  = $c.name
    $cookie.Value = $c.value
    $cookie.Domain = $c.domain.TrimStart(".")
    $cookie.Path = $c.path
    $Session.Cookies.Add($cookie)
}

# Read URLs
$Urls = Get-Content $UrlFile

foreach ($Url in $Urls) {
    $Url = $Url.Trim()
    if ($Url -eq "") { continue }

    Write-Host "Downloading: $Url"

    try {
        $Response = Invoke-WebRequest -Uri $Url -WebSession $Session -ErrorAction Stop

        # Use server-provided filename
        $FileName = $Response.Headers["Content-Disposition"] -replace '.*filename="?([^"]+)"?','$1'
        if (-not $FileName) { $FileName = "unknown_$(Get-Random).txt" }

        $OutFile = Join-Path $OutputFolder $FileName
        [IO.File]::WriteAllBytes($OutFile, $Response.Content)

        Write-Host "Saved: $FileName"
    }
    catch {
        Write-Warning "Failed: $Url"
    }

    Start-Sleep -Milliseconds 500
}

Write-Host "All downloads completed."
