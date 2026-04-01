$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $root "info.txt"
$jsonOut = Join-Path $root "info.json"
$zipOut = Join-Path $root "info_upload.zip"
$done = Join-Path $root "done.txt"
$webhookFile = Join-Path $root "discord_webhook.txt"

if (Test-Path $out) { Remove-Item $out -Force }
if (Test-Path $jsonOut) { Remove-Item $jsonOut -Force }
if (Test-Path $zipOut) { Remove-Item $zipOut -Force }
if (Test-Path $done) { Remove-Item $done -Force }

$jsonData = [ordered]@{}

function Add-Section {
    param([string]$Title)
    Add-Content -Path $out -Value ""
    Add-Content -Path $out -Value ("=" * 90)
    Add-Content -Path $out -Value $Title
    Add-Content -Path $out -Value ("=" * 90)
}

function Add-Line {
    param([string]$Name, [object]$Value)
    if ($null -eq $Value) { return }
    $text = $Value.ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    $safe = $text -replace "\r|\n", " "
    Add-Content -Path $out -Value ("{0}: {1}" -f $Name, $safe)
}

function Add-Table {
    param([string]$Title, [object]$Data)
    Add-Content -Path $out -Value ""
    Add-Content -Path $out -Value ("-- " + $Title + " --")
    if ($null -eq $Data) {
        Add-Content -Path $out -Value "(no data)"
        return
    }
    $lines = $Data | Out-String -Width 260
    Add-Content -Path $out -Value $lines.TrimEnd()
}

function Set-JsonSection {
    param([string]$Name, [object]$Value)
    $jsonData[$Name] = $Value
}

function Try-Command {
    param([scriptblock]$Script)
    try {
        & $Script
    } catch {
        Add-Content -Path $out -Value ("Error: " + $_.Exception.Message)
    }
}

function Resolve-DiscordWebhook {
    $fromEnv = $env:DISCORD_WEBHOOK_URL
    if (-not [string]::IsNullOrWhiteSpace($fromEnv)) {
        return $fromEnv.Trim()
    }

    if (Test-Path $webhookFile) {
        $line = (Get-Content -Path $webhookFile -ErrorAction SilentlyContinue | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            return $line.Trim()
        }
    }

    return $null
}

function Send-DiscordWebhookFiles {
    param(
        [string]$WebhookUrl,
        [string]$Message,
        [string[]]$FilePaths
    )

    Add-Type -AssemblyName System.Net.Http

    $client = New-Object System.Net.Http.HttpClient
    $multipart = New-Object System.Net.Http.MultipartFormDataContent

    try {
        $payloadJson = @{ content = $Message } | ConvertTo-Json -Compress
        $payloadContent = New-Object System.Net.Http.StringContent($payloadJson, [System.Text.Encoding]::UTF8, "application/json")
        $multipart.Add($payloadContent, "payload_json")

        $index = 0
        foreach ($file in $FilePaths) {
            if (-not (Test-Path $file)) { continue }
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $fileContent = New-Object System.Net.Http.ByteArrayContent(, $bytes)
            $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")
            $multipart.Add($fileContent, ("files[{0}]" -f $index), [System.IO.Path]::GetFileName($file))
            $index++
        }

        $response = $client.PostAsync($WebhookUrl, $multipart).Result
        if (-not $response.IsSuccessStatusCode) {
            $body = $response.Content.ReadAsStringAsync().Result
            throw "Discord upload failed: $($response.StatusCode) $body"
        }
    } finally {
        if ($multipart) { $multipart.Dispose() }
        if ($client) { $client.Dispose() }
    }
}

Add-Section "BASIC"
$basic = [ordered]@{
    Timestamp = (Get-Date -Format o)
    CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Machine = $env:COMPUTERNAME
    Domain = $env:USERDOMAIN
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
}
foreach ($k in $basic.Keys) { Add-Line $k $basic[$k] }
Set-JsonSection "Basic" $basic

Try-Command {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $board = Get-CimInstance Win32_BaseBoard

    Add-Section "OS AND DEVICE"
    Add-Line "OS" $os.Caption
    Add-Line "Version" $os.Version
    Add-Line "Build" $os.BuildNumber
    Add-Line "Architecture" $os.OSArchitecture
    Add-Line "InstallDate" $os.InstallDate
    Add-Line "LastBoot" $os.LastBootUpTime
    Add-Line "Manufacturer" $cs.Manufacturer
    Add-Line "Model" $cs.Model
    Add-Line "SystemType" $cs.SystemType
    Add-Line "TotalPhysicalMemoryBytes" $cs.TotalPhysicalMemory
    Add-Line "BIOSVersion" (($bios.SMBIOSBIOSVersion -join ", "))
    Add-Line "BIOSSerial" $bios.SerialNumber
    Add-Line "BaseBoard" (("{0} {1}" -f $board.Manufacturer, $board.Product).Trim())

    $secureBoot = "Unknown"
    try { $secureBoot = (Confirm-SecureBootUEFI) } catch {}

    $osDevice = [ordered]@{
        OS = $os.Caption
        Version = $os.Version
        Build = $os.BuildNumber
        Architecture = $os.OSArchitecture
        InstallDate = $os.InstallDate
        LastBoot = $os.LastBootUpTime
        Manufacturer = $cs.Manufacturer
        Model = $cs.Model
        SystemType = $cs.SystemType
        TotalPhysicalMemoryBytes = $cs.TotalPhysicalMemory
        BIOSVersion = ($bios.SMBIOSBIOSVersion -join ", ")
        BIOSSerial = $bios.SerialNumber
        BaseBoardManufacturer = $board.Manufacturer
        BaseBoardProduct = $board.Product
        TimeZone = (Get-TimeZone).Id
        SecureBoot = $secureBoot
    }
    Set-JsonSection "OSAndDevice" $osDevice
}

Try-Command {
    Add-Section "CPU"
    $cpu = Get-CimInstance Win32_Processor |
        Select-Object Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, CurrentClockSpeed, ProcessorId
    Add-Table "CPU List" $cpu
    Set-JsonSection "CPU" $cpu
}

Try-Command {
    Add-Section "RAM"
    $mem = Get-CimInstance Win32_PhysicalMemory |
        Select-Object BankLabel, Manufacturer, PartNumber, Speed, ConfiguredClockSpeed, Capacity, SerialNumber
    Add-Table "Memory Modules" $mem
    Set-JsonSection "RAM" $mem
}

Try-Command {
    Add-Section "GPU"
    $gpu = Get-CimInstance Win32_VideoController |
        Select-Object Name, AdapterRAM, DriverVersion, VideoProcessor, CurrentHorizontalResolution, CurrentVerticalResolution
    Add-Table "Video Controllers" $gpu
    Set-JsonSection "GPU" $gpu
}

Try-Command {
    Add-Section "STORAGE"
    $physical = Get-CimInstance Win32_DiskDrive | Select-Object Model, InterfaceType, MediaType, Size, SerialNumber
    $logical = Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID, DriveType, FileSystem, Size, FreeSpace, VolumeName
    $parts = Get-CimInstance Win32_DiskPartition | Select-Object Name, Type, Size, Bootable, BootPartition
    Add-Table "Physical Disks" $physical
    Add-Table "Logical Disks" $logical
    Add-Table "Disk Partitions" $parts
    Set-JsonSection "Storage" ([ordered]@{ PhysicalDisks = $physical; LogicalDisks = $logical; Partitions = $parts })
}

Try-Command {
    Add-Section "NETWORK"
    $adapters = Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress
    $ip4 = Get-NetIPAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, IPAddress, PrefixLength, AddressState
    $ip6 = Get-NetIPAddress -AddressFamily IPv6 | Select-Object InterfaceAlias, IPAddress, PrefixLength, AddressState
    $dns = Get-DnsClientServerAddress | Select-Object InterfaceAlias, AddressFamily, ServerAddresses
    $routes = Get-NetRoute | Select-Object -First 100 DestinationPrefix, NextHop, RouteMetric, InterfaceAlias
    Add-Table "Adapters" $adapters
    Add-Table "IPv4 Addresses" $ip4
    Add-Table "IPv6 Addresses" $ip6
    Add-Table "DNS Client" $dns
    Add-Table "Routes (Top 100)" $routes
    Set-JsonSection "Network" ([ordered]@{ Adapters = $adapters; IPv4 = $ip4; IPv6 = $ip6; DNS = $dns; Routes = $routes })
}

Try-Command {
    Add-Section "SECURITY"
    $def = Get-MpComputerStatus |
        Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, IsTamperProtected, NISEnabled, IoavProtectionEnabled
    $fw = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
    Add-Table "Windows Defender Computer Status" $def
    Add-Table "Firewall Profiles" $fw

    $bitlocker = $null
    try {
        $bitlocker = Get-BitLockerVolume -ErrorAction Stop | Select-Object MountPoint, VolumeType, VolumeStatus, ProtectionStatus, EncryptionMethod
        Add-Table "BitLocker Volumes" $bitlocker
    } catch {
        Add-Line "BitLocker" "Unavailable or requires admin"
    }

    $tpm = $null
    try {
        $tpm = Get-Tpm | Select-Object TpmPresent, TpmReady, ManufacturerIdTxt, ManagedAuthLevel
        Add-Table "TPM" $tpm
    } catch {
        Add-Line "TPM" "Unavailable"
    }

    Set-JsonSection "Security" ([ordered]@{ Defender = $def; FirewallProfiles = $fw; BitLocker = $bitlocker; TPM = $tpm })
}

Try-Command {
    $users = Get-LocalUser | Select-Object Name, Enabled, PasswordRequired, LastLogon
    $groups = Get-LocalGroup | Select-Object Name, Description
    Add-Table "Local Users" $users
    Add-Table "Local Groups" $groups
    Set-JsonSection "LocalAccounts" ([ordered]@{ Users = $users; Groups = $groups })
}

Try-Command {
    Add-Section "PROCESSES AND SERVICES"
    $procCpu = Get-Process | Sort-Object CPU -Descending | Select-Object -First 50 Name, Id, CPU, WorkingSet, StartTime
    $procMem = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 50 Name, Id, CPU, WorkingSet
    $services = Get-Service | Select-Object Name, DisplayName, StartType, Status
    Add-Table "Top Processes by CPU (50)" $procCpu
    Add-Table "Top Processes by RAM (50)" $procMem
    Add-Table "All Services" $services
    Set-JsonSection "ProcessesAndServices" ([ordered]@{ TopCPU = $procCpu; TopRAM = $procMem; Services = $services })
}

Try-Command {
    Add-Section "SOFTWARE"
    $appPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $apps = foreach ($path in $appPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation
    }

    $apps = $apps | Sort-Object DisplayName -Unique
    $hotfixes = Get-HotFix | Select-Object HotFixID, InstalledOn, Description
    Add-Line "InstalledAppCount" ($apps.Count)
    Add-Table "Installed Apps (Top 600)" ($apps | Select-Object -First 600)
    Add-Table "Installed HotFixes" $hotfixes
    Set-JsonSection "Software" ([ordered]@{ InstalledAppCount = $apps.Count; Apps = $apps; HotFixes = $hotfixes })
}

Try-Command {
    Add-Section "STARTUP AND SCHEDULED"
    $startup = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User
    $tasks = Get-ScheduledTask | Select-Object -First 500 TaskPath, TaskName, State, Author, Description
    Add-Table "Startup Commands" $startup
    Add-Table "Scheduled Tasks (Top 500)" $tasks
    Set-JsonSection "StartupAndScheduled" ([ordered]@{ Startup = $startup; ScheduledTasks = $tasks })
}

Try-Command {
    Add-Section "DRIVERS"
    $drivers = Get-CimInstance Win32_PnPSignedDriver |
        Select-Object -First 800 DeviceName, DriverProviderName, DriverVersion, DriverDate, InfName
    Add-Table "Signed Drivers (Top 800)" $drivers
    Set-JsonSection "Drivers" $drivers
}

Try-Command {
    Add-Section "HARDWARE EXTRAS"
    $usb = Get-PnpDevice -PresentOnly -Class USB -ErrorAction SilentlyContinue |
        Select-Object Status, Class, FriendlyName, InstanceId
    $monitors = Get-CimInstance Win32_DesktopMonitor | Select-Object Name, ScreenHeight, ScreenWidth, PNPDeviceID
    $printers = Get-Printer -ErrorAction SilentlyContinue | Select-Object Name, DriverName, PortName, Shared, Published
    $shares = Get-SmbShare -ErrorAction SilentlyContinue | Select-Object Name, Path, Description, CurrentUsers

    Add-Table "USB Devices" $usb
    Add-Table "Monitors" $monitors
    Add-Table "Printers" $printers
    Add-Table "SMB Shares" $shares
    Set-JsonSection "HardwareExtras" ([ordered]@{ USB = $usb; Monitors = $monitors; Printers = $printers; Shares = $shares })
}

Try-Command {
    Add-Section "ENVIRONMENT"
    $envVars = Get-ChildItem Env: | Sort-Object Name | Select-Object Name, Value
    Add-Table "Environment Variables" $envVars
    Set-JsonSection "Environment" $envVars
}

Try-Command {
    Add-Section "EVENT SUMMARY"
    $recentSystemErrors = Get-WinEvent -FilterHashtable @{ LogName = "System"; Level = 1, 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 120 |
        Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
    $recentAppErrors = Get-WinEvent -FilterHashtable @{ LogName = "Application"; Level = 1, 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 120 |
        Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
    Add-Table "System Errors/Critical (7 days)" $recentSystemErrors
    Add-Table "Application Errors/Critical (7 days)" $recentAppErrors
    Set-JsonSection "EventSummary" ([ordered]@{ System = $recentSystemErrors; Application = $recentAppErrors })
}

Try-Command {
    Add-Section "COMMAND SNAPSHOTS"
    $systeminfo = (cmd /c systeminfo) | Out-String
    $ipconfig = (cmd /c ipconfig /all) | Out-String
    $netstat = (cmd /c netstat -ano) | Out-String
    $driverquery = (cmd /c driverquery /fo table) | Out-String
    $tasklist = (cmd /c tasklist) | Out-String

    Add-Content -Path $out -Value ""
    Add-Content -Path $out -Value "-- systeminfo --"
    Add-Content -Path $out -Value $systeminfo

    Add-Content -Path $out -Value ""
    Add-Content -Path $out -Value "-- ipconfig /all --"
    Add-Content -Path $out -Value $ipconfig

    Add-Content -Path $out -Value ""
    Add-Content -Path $out -Value "-- netstat -ano --"
    Add-Content -Path $out -Value $netstat

    Add-Content -Path $out -Value ""
    Add-Content -Path $out -Value "-- driverquery --"
    Add-Content -Path $out -Value $driverquery

    Add-Content -Path $out -Value ""
    Add-Content -Path $out -Value "-- tasklist --"
    Add-Content -Path $out -Value $tasklist

    Set-JsonSection "CommandSnapshots" ([ordered]@{
        systeminfo = $systeminfo
        ipconfig_all = $ipconfig
        netstat_ano = $netstat
        driverquery = $driverquery
        tasklist = $tasklist
    })
}

Try-Command {
    Add-Section "OPTIONAL INTERNET"
    $publicIp = "Unavailable"
    try {
        $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org?format=text" -TimeoutSec 10)
    } catch {}
    Add-Line "PublicIP" $publicIp
    Set-JsonSection "Internet" ([ordered]@{ PublicIP = $publicIp })
}

$jsonData["OutputFiles"] = [ordered]@{
    TextReport = $out
    JsonReport = $jsonOut
    ZipReport = $zipOut
    DoneMarker = $done
}

Set-Content -Path $jsonOut -Value ($jsonData | ConvertTo-Json -Depth 8) -Encoding UTF8

Try-Command {
    Add-Section "DISCORD UPLOAD"
    $webhookUrl = Resolve-DiscordWebhook
    if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
        Add-Line "UploadStatus" "Skipped (no webhook set)"
        Add-Line "HowToEnable" "Set DISCORD_WEBHOOK_URL env var or create discord_webhook.txt next to this script"
        Set-JsonSection "DiscordUpload" ([ordered]@{ Enabled = $false; Status = "Skipped"; Reason = "No webhook" })
    } else {
        $maxBytes = 24MB
        $uploadTarget = $null

        Compress-Archive -Path $out, $jsonOut -DestinationPath $zipOut -Force

        if ((Get-Item $zipOut).Length -le $maxBytes) {
            $uploadTarget = $zipOut
            Add-Line "UploadTarget" "info_upload.zip"
        } elseif ((Get-Item $jsonOut).Length -le $maxBytes) {
            $uploadTarget = $jsonOut
            Add-Line "UploadTarget" "info.json"
            Add-Line "Note" "Zip was too large; uploaded JSON only"
        } else {
            throw "Reports are larger than Discord upload limits."
        }

        $msg = "System report from $env:COMPUTERNAME at $(Get-Date -Format o)"
        Send-DiscordWebhookFiles -WebhookUrl $webhookUrl -Message $msg -FilePaths @($uploadTarget)
        Add-Line "UploadStatus" "Success"
        Add-Line "UploadedFile" ([System.IO.Path]::GetFileName($uploadTarget))
        Set-JsonSection "DiscordUpload" ([ordered]@{ Enabled = $true; Status = "Success"; UploadedFile = [System.IO.Path]::GetFileName($uploadTarget) })
    }
}

# Refresh JSON so Discord upload status is included.
Set-Content -Path $jsonOut -Value ($jsonData | ConvertTo-Json -Depth 8) -Encoding UTF8
Set-Content -Path $done -Value "done=1" -Encoding ascii
