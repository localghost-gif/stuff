<#
  Windows System Information Gathering (PowerShell port)

  Gathers system, hardware, network, user, process, software, environment and log info to text files
  under a timestamped folder in the machine TEMP directory.


  Run as Administrator for the most complete results. Some commands (Event logs, services, scheduled tasks, etc.)
  may return limited info when run as standard user.
#>

$ErrorActionPreference = 'Stop'

function New-OutputDir {
    $t = Get-Date -Format "yyyyMMdd_HHmmss"
    $r = Get-Random -Maximum 100000
    $baseTemp = if ($env:TEMP) { $env:TEMP } else { "C:\Windows\Temp" }
    $dir = Join-Path -Path $baseTemp -ChildPath ("sysinfo_{0}_{1}" -f $t, $r)
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
    return (Resolve-Path $dir).Path
}

function Write-HeaderAndRun {
    param(
        [string]$CommandDescription,
        [scriptblock]$ScriptBlock,
        [string]$OutFile
    )

    $header = @()
    $header += "Gathering: $CommandDescription"
    $header += "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $header += ("=" * 60)
    $headerText = $header -join [Environment]::NewLine

    "$headerText" | Out-File -FilePath $OutFile -Encoding UTF8
    try {
        & $ScriptBlock 2>&1 | Out-File -Append -FilePath $OutFile -Encoding UTF8
    } catch {
        "ERROR: $_" | Out-File -Append -FilePath $OutFile -Encoding UTF8
    }
    "" | Out-File -Append -FilePath $OutFile -Encoding UTF8
}

function Format-Bytes {
    param([int64]$Bytes)
    if ($Bytes -ge 1GB) { "{0:N2} GB" -f ($Bytes/1GB) }
    elseif ($Bytes -ge 1MB) { "{0:N2} MB" -f ($Bytes/1MB) }
    elseif ($Bytes -ge 1KB) { "{0:N2} KB" -f ($Bytes/1KB) }
    else { "$Bytes bytes" }
}

# Create output dir
if (-not (Test-Path -Path $env:TEMP)) {
    Write-Host "Error: TEMP directory not found. Exiting." -ForegroundColor Red
    exit 1
}

$OUTPUT_DIR = New-OutputDir
Write-Host "=== Windows System Information Gathering ===" -ForegroundColor Yellow
Write-Host "Output directory: $OUTPUT_DIR"
Write-Host "Started: $(Get-Date)"
Write-Host ""

# 01_system_info.txt
$sysFile = Join-Path $OUTPUT_DIR "01_system_info.txt"

Write-HeaderAndRun -CommandDescription "Computer and OS information" -OutFile $sysFile -ScriptBlock {
    "Hostname: $(hostname)"
    "User: $(whoami 2>$null)"
    ""
    "Get-ComputerInfo (partial):"
    try { Get-ComputerInfo | Select-Object CsName,WindowsProductName,WindowsVersion,WindowsBuildLabEx,OsHardwareAbstractionLayer,OsName,OsDisplayVersion } catch {}
    ""
    "Win32_OperatingSystem (WMI):"
    try { Get-CimInstance -ClassName Win32_OperatingSystem } catch {}
    ""
    "Uptime (since last boot):"
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $boot = $os.LastBootUpTime
        $uptime = (Get-Date) - ([Management.ManagementDateTimeConverter]::ToDateTime($boot))
        "LastBootUpTime: $boot"
        "Uptime: $($uptime.ToString())"
    } catch {}
    ""
    "System architecture:"
    try { Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object Manufacturer,Model,SystemType } catch {}
}

# 02_hardware.txt
$hwFile = Join-Path $OUTPUT_DIR "02_hardware.txt"
Write-HeaderAndRun -CommandDescription "Hardware information (CPU, Memory, Disks, GPU, PnP devices)" -OutFile $hwFile -ScriptBlock {
    "CPU:"
    try { Get-CimInstance -ClassName Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed } catch {}

    ""
    "Memory (physical modules):"
    try { Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object Manufacturer,Capacity,Speed,DeviceLocator,PartNumber } catch {}

    ""
    "Memory summary:"
    try {
        $mem = Get-CimInstance -ClassName Win32_ComputerSystem
        $total = [int64]$mem.TotalPhysicalMemory
        "TotalPhysicalMemory: $(Format-Bytes $total)"
    } catch {}

    ""
    "Disks & Volumes:"
    try {
        Get-Disk | Select-Object Number,Model,SerialNumber,Size,PartitionStyle,OperationalStatus
        Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,SizeRemaining,Size
    } catch {}

    ""
    "PnP / Device list (best-effort):"
    try {
        Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PnPEntity | Select-Object Name,Manufacturer,DeviceID | Out-String -Width 200
    } catch {}
}

# 03_network.txt
$netFile = Join-Path $OUTPUT_DIR "03_network.txt"
Write-HeaderAndRun -CommandDescription "Network interfaces, routes, listening ports, ARP table" -OutFile $netFile -ScriptBlock {
    "IP Addresses:"
    try { Get-NetIPAddress -AddressState Preferred -ErrorAction SilentlyContinue | Select-Object InterfaceAlias,IPAddress,AddressFamily } catch {}

    ""
    "Network adapters:"
    try { Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name,Status,LinkSpeed,MacAddress } catch {}

    ""
    "Routing table:"
    try { Get-NetRoute -ErrorAction SilentlyContinue | Select-Object ifIndex,DestinationPrefix,NextHop,RouteMetric } catch {}

    ""
    "Listening TCP/UDP endpoints (Get-Net* or netstat fallback):"
    try {
        Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,State,OwningProcess | Out-String -Width 200
        Get-NetUDPEndpoint -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort | Out-String -Width 200
    } catch {
        "Get-NetTCPConnection error: $_"
        "Trying netstat..."
        netstat -ano
    }

    ""
    "ARP / neighbor table:"
    try { Get-NetNeighbor -ErrorAction SilentlyContinue | Select-Object ifIndex,IPAddress,LinkLayerAddress,State } catch {}
}

# 04_users.txt
$userFile = Join-Path $OUTPUT_DIR "04_users.txt"
Write-HeaderAndRun -CommandDescription "Local users, groups, logged in users, recent logons" -OutFile $userFile -ScriptBlock {
    "Local Users:"
    try { Get-LocalUser | Select-Object Name,Enabled,LastLogon } catch { "Get-LocalUser not available: $_" }

    ""
    "Local Groups:"
    try { Get-LocalGroup | Select-Object Name,Description } catch { "Get-LocalGroup not available: $_" }

    ""
    "Members of Administrators group:"
    try { Get-LocalGroupMember -Group 'Administrators' | Select-Object Name,PrincipalSource } catch { "Cannot enumerate Administrators group: $_" }

    ""
    "Currently logged on users (quser/who):"
    try { whoami } catch {}
    try { quser 2>$null } catch {}
    try { Get-CimInstance -ClassName Win32_LogonSession | Select-Object LogonId,StartTime,LogonType } catch {}
}

# 05_processes.txt
$procFile = Join-Path $OUTPUT_DIR "05_processes.txt"
Write-HeaderAndRun -CommandDescription "Running processes, services, scheduled tasks, autoruns-like checks" -OutFile $procFile -ScriptBlock {
    "Processes:"
    try { Get-Process | Sort-Object -Property WS -Descending | Select-Object -First 200 -Property Id,ProcessName,CPU,WS } catch {}

    ""
    "Running services:"
    try { Get-Service | Where-Object {$_.Status -eq 'Running'} | Select-Object Name,DisplayName,Status } catch {}

    ""
    "Enabled services (StartType Automatic):"
    try { Get-Service | Where-Object {$_.StartType -eq 'Automatic'} | Select-Object Name,DisplayName,StartType } catch {}

    ""
    "Scheduled Tasks (Task Scheduler):"
    try { Get-ScheduledTask | Select-Object TaskName,TaskPath,State } catch { "Get-ScheduledTask not available or insufficient privileges: $_" }

    ""
    "Startup items (registry & startup folders - best effort):"
    try {
        Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
        Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
    } catch {}
}

# 06_security.txt
$secFile = Join-Path $OUTPUT_DIR "06_security.txt"
Write-HeaderAndRun -CommandDescription "Security-related info: local admins, firewall, user rights" -OutFile $secFile -ScriptBlock {
    "Administrators group members:"
    try { Get-LocalGroupMember -Group 'Administrators' | Select-Object Name,PrincipalSource } catch {}

    ""
    "Local firewall status and profiles:"
    try { Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction } catch {}

    ""
    "User rights assignments (secpol) - best-effort via secedit export (requires admin):"
    try {
        $tmp = Join-Path $env:TEMP "secpol_$((Get-Random)).inf"
        secedit /export /cfg $tmp 2>$null
        if (Test-Path $tmp) { Get-Content $tmp | Select-Object -First 200; Remove-Item $tmp -ErrorAction SilentlyContinue }
    } catch { "secedit export failed or requires admin: $_" }

    ""
    "Windows Defender / AV product:"
    try { Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct | Select-Object displayName,productState,instanceGuid } catch {}
}

# 07_software.txt
$softFile = Join-Path $OUTPUT_DIR "07_software.txt"
Write-HeaderAndRun -CommandDescription "Installed software / packages / dev tools" -OutFile $softFile -ScriptBlock {
    "Installed packages (Get-Package):"
    try { Get-Package -ErrorAction SilentlyContinue | Select-Object Name,ProviderName,Version } catch {}

    ""
    "Programs from registry (Uninstall keys) - best-effort:"
    try {
        $paths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        foreach ($p in $paths) {
            Get-ItemProperty -Path $p -ErrorAction SilentlyContinue | Select-Object DisplayName,DisplayVersion,Publisher,InstallDate
        }
    } catch {}

# Developer tool binaries (search common names in PATH):
try {
    $devTools = @('gcc','g++','python','python3','perl','ruby','php','java','javac','msbuild')
    foreach ($exe in $devTools) {
        try {
            $cmd = Get-Command $exe -ErrorAction SilentlyContinue
            if ($null -ne $cmd) {
                "{0} => {1}" -f $exe,($cmd.Source) | Out-File -Append -FilePath $softFile -Encoding UTF8
            } else {
                "{0} => <not found>" -f $exe | Out-File -Append -FilePath $softFile -Encoding UTF8
            }
        } catch {
            "{0} => <error: $($_.Exception.Message)>" -f $exe | Out-File -Append -FilePath $softFile -Encoding UTF8
        }
    }
} catch {
    "Error while checking dev tools: $_" | Out-File -Append -FilePath $softFile -Encoding UTF8
}
}

# 08_environment.txt
$envFile = Join-Path $OUTPUT_DIR "08_environment.txt"
Write-HeaderAndRun -CommandDescription "Environment variables, hosts, DNS, mounted drives" -OutFile $envFile -ScriptBlock {
    "Environment variables:"
    try { Get-ChildItem Env: | Sort-Object Name } catch {}

    ""
    "Hosts file:"
    try { Get-Content -Path "$env:WinDir\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue } catch {}

    ""
    "DNS servers (per adapter):"
    try { Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Select-Object InterfaceAlias,ServerAddresses } catch {}

    ""
    "PS drives / mounted filesystems:"
    try { Get-PSDrive | Select-Object Name,Provider,Used,Free } catch {}
}

# 09_logs.txt
$logFile = Join-Path $OUTPUT_DIR "09_logs.txt"
Write-HeaderAndRun -CommandDescription "Recent Event Logs (Application, System, Security) - last 50 each" -OutFile $logFile -ScriptBlock {
    "Application (last 50):"
    try { Get-WinEvent -LogName Application -MaxEvents 50 | Format-List -Property TimeCreated,Id,LevelDisplayName,Message } catch {}

    ""
    "System (last 50):"
    try { Get-WinEvent -LogName System -MaxEvents 50 | Format-List -Property TimeCreated,Id,LevelDisplayName,Message } catch {}

    ""
    "Security (last 50) - may require admin:"
    try { Get-WinEvent -LogName Security -MaxEvents 50 | Format-List -Property TimeCreated,Id,LevelDisplayName,Message } catch { "Security log read failed (requires admin or audit policy): $_" }
}

# 10_interesting.txt
$intFile = Join-Path $OUTPUT_DIR "10_interesting.txt"
Write-HeaderAndRun -CommandDescription "Interesting files: hidden files in user profiles, temp files, program files" -OutFile $intFile -ScriptBlock {
    "Hidden files in user profiles (first 100):"
    try {
        Get-ChildItem -Path C:\Users -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Attributes -band [IO.FileAttributes]::Hidden -and -not $_.PSIsContainer } |
            Select-Object -First 100 FullName,Length,LastWriteTime
    } catch {}

    ""
    "Files in Temp directories (user temp and Windows temp) - first 100:"
    try {
        Get-ChildItem -Path "$env:TEMP" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 100 FullName,Length,LastWriteTime
        Get-ChildItem -Path "C:\Windows\Temp" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 100 FullName,Length,LastWriteTime
    } catch {}

    ""
    "Files under Program Files recently modified (first 100):"
    try { Get-ChildItem -Path 'C:\Program Files','C:\Program Files (x86)' -Recurse -ErrorAction SilentlyContinue | Where-Object {-not $_.PSIsContainer} | Sort-Object LastWriteTime -Descending | Select-Object -First 100 FullName,LastWriteTime } catch {}
}

# 11_history.txt
$histFile = Join-Path $OUTPUT_DIR "11_history.txt"
Write-HeaderAndRun -CommandDescription "Shell history & saved history files" -OutFile $histFile -ScriptBlock {
    "Current PowerShell session history (Get-History):"
    try { Get-History } catch {}

    ""
    "PSReadLine history file (if exists):"
    try {
        $psrl = Join-Path $env:APPDATA "Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
        if (Test-Path $psrl) { Get-Content $psrl -ErrorAction SilentlyContinue | Select-Object -Last 200 } else { "PSReadLine history not found at $psrl" }
    } catch {}

    ""
    "Other *history files under C:\Users (first 200 lines each):"
    try {
        Get-ChildItem -Path C:\Users -Recurse -Include *.history,*.bash_history,*.ps1_history -ErrorAction SilentlyContinue |
            ForEach-Object {
                "---- $_.FullName ----"
                Get-Content -Path $_.FullName -ErrorAction SilentlyContinue | Select-Object -Last 200
            }
    } catch {}
}

# 00_SUMMARY.txt
$sumFile = Join-Path $OUTPUT_DIR "00_SUMMARY.txt"
$summary = @()
$summary += "=== SYSTEM INFORMATION SUMMARY ==="
$summary += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$summary += "Hostname: $(hostname)"
try { $summary += "OS: " + ((Get-CimInstance -ClassName Win32_OperatingSystem).Caption) } catch {}
try { $summary += "OS Version: " + ((Get-CimInstance -ClassName Win32_OperatingSystem).Version) } catch {}
try { $summary += "Kernel (Build): " + ((Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber) } catch {}
try { $summary += "Architecture: " + (Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture } catch {}
$summary += "Current User: $(whoami 2>$null)"
try { $summary += "Total Physical Memory: " + (Format-Bytes ([int64](Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory)) } catch {}
$summary += ""
$summary += "=== FILES GENERATED ==="
Get-ChildItem -Path $OUTPUT_DIR -Force | ForEach-Object {
    $size = Format-Bytes $_.Length
    $summary += ("{0} - {1}" -f $_.Name, $size)
}
$summary | Out-File -FilePath $sumFile -Encoding UTF8

# Final message
Write-Host ""
Write-Host "=== Information Gathering Complete ===" -ForegroundColor Green
Write-Host "Results saved to: $OUTPUT_DIR" -ForegroundColor Yellow
Write-Host "Summary available in: $sumFile"
Write-Host ""
Write-Host "Note: Some commands may fail due to permissions or missing modules." -ForegroundColor Yellow
Write-Host "Run as Administrator for more complete results." -ForegroundColor Yellow
