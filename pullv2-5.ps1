<#
  Pull v2.5 by l0calgh0st - Pulling useful wordlists in one go (PowerShell port)
#>

$ErrorActionPreference = "Stop"

function Write-Color {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

Write-Color "Security Wordlists Downloader (Git Raw URLs)" "Yellow"
Write-Host "============================================="

$WORDLIST_DIR = "wordlists"
if (-not (Test-Path -Path $WORDLIST_DIR -PathType Container)) {
    Write-Color "Creating $WORDLIST_DIR directory..." "Yellow"
    New-Item -ItemType Directory -Path $WORDLIST_DIR | Out-Null
}

Set-Location -Path $WORDLIST_DIR

function Download-From-GitHub {
    param(
        [Parameter(Mandatory=$true)][string]$Repo,        
        [Parameter(Mandatory=$true)][string]$FilePath,    
        [Parameter(Mandatory=$true)][string]$OutName,     
        [string]$Description = $FilePath
    )

    $branches = @("main","master")
    $success = $false

    foreach ($branch in $branches) {
        $rawUrl = "https://raw.githubusercontent.com/$Repo/$branch/$FilePath"
        Write-Host ""
        Write-Color "Downloading $Description..." "Yellow"
        Write-Host "URL: $rawUrl"

        try {
            Invoke-WebRequest -Uri $rawUrl -OutFile $OutName -UseBasicParsing -ErrorAction Stop
            Write-Color "✓ Successfully downloaded $OutName" "Green"
            $success = $true
            break
        }
        catch {
            Write-Color "✗ Failed to download from branch '$branch'." "Red"

        }
    }

    if (-not $success) {
        Write-Color "✗ Failed to download $OutName from both main and master." "Red"
        return $false
    }

    try {
        $size = (Get-Item $OutName).Length
        # Pretty print size (KB/MB)
        if ($size -ge 1MB) {
            $sizeStr = "{0:N2} MB" -f ($size / 1MB)
        } elseif ($size -ge 1KB) {
            $sizeStr = "{0:N2} KB" -f ($size / 1KB)
        } else {
            $sizeStr = "$size bytes"
        }
        Write-Host "  File size: $sizeStr"
    } catch {
        # ignore size errors
    }

    return $true
}

# Check for network tools (Invoke-WebRequest exists by default). We'll detect if we can reach github.
try {
    $null = Invoke-WebRequest -Uri "https://raw.githubusercontent.com" -Method Head -TimeoutSec 10 -ErrorAction Stop
} catch {
    Write-Color "Error: Cannot reach raw.githubusercontent.com. Check your network or proxy settings." "Red"
    exit 1
}

Download-From-GitHub -Repo "n0kovo/n0kovo_subdomains" `
                     -FilePath "n0kovo_subdomains_huge.txt" `
                     -OutName "n0kovo_subdomains_huge.txt" `
                     -Description "n0kovo's huge subdomain list" | Out-Null

Download-From-GitHub -Repo "danielmiessler/SecLists" `
                     -FilePath "Discovery/Web-Content/combined_directories.txt" `
                     -OutName "combined_directories.txt" `
                     -Description "Combined Directories list" | Out-Null

Write-Host ""
Write-Color "Downloading RockYou password list..." "Yellow"
$rockyou_downloaded = $false

$rockyou_sources = @(
    @{ repo = "brannondorsey/naive-hashcat"; branch = "master"; path = "wordlists/rockyou.txt" },
    @{ repo = "danielmiessler/SecLists"; branch = "master"; path = "Passwords/Leaked-Databases/rockyou.txt" },
    @{ repo = "danielmiessler/SecLists"; branch = "master"; path = "Passwords/Leaked-Databases/rockyou-75.txt" }
)

foreach ($src in $rockyou_sources) {
    $rawUrl = "https://raw.githubusercontent.com/$($src.repo)/$($src.branch)/$($src.path)"
    Write-Host "Trying: $rawUrl"

    try {
        Invoke-WebRequest -Uri $rawUrl -OutFile "rockyou.txt" -UseBasicParsing -ErrorAction Stop
        Write-Color "✓ Successfully downloaded rockyou.txt" "Green"
        $size = (Get-Item "rockyou.txt").Length
        if ($size -ge 1MB) { $sizeStr = "{0:N2} MB" -f ($size / 1MB) }
        elseif ($size -ge 1KB) { $sizeStr = "{0:N2} KB" -f ($size / 1KB) }
        else { $sizeStr = "$size bytes" }
        Write-Host "  File size: $sizeStr"
        $rockyou_downloaded = $true
        break
    }
    catch {
        Write-Color "✗ Failed from this source" "Red"
    }
}

if (-not $rockyou_downloaded) {
    Write-Color "✗ Could not download rockyou.txt from any source" "Red"
}

Write-Host ""
Write-Color "Download process completed!" "Green"
Write-Color "Files saved in: $(Get-Location)" "Yellow"
Write-Host ""
Write-Host "Downloaded files:"
# List only .txt files, similar to ls -lah *.txt
Get-ChildItem -Path . -Filter *.txt -File -ErrorAction SilentlyContinue | 
    Select-Object Name, @{Name="Size";Expression={
        $s = $_.Length
        if ($s -ge 1MB) { "{0:N2} MB" -f ($s/1MB) }
        elseif ($s -ge 1KB) { "{0:N2} KB" -f ($s/1KB) }
        else { "$s bytes" }
    }} |
    Format-Table -AutoSize

if (-not (Get-ChildItem -Path . -Filter *.txt -File -ErrorAction SilentlyContinue)) {
    Write-Host "No .txt files found"
}

Write-Host ""
Write-Color "Note: These wordlists are for legitimate security testing purposes only." "Yellow"
Write-Color "Always ensure you have proper authorization before using them." "Yellow"