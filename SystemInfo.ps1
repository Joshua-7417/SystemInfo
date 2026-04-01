<#
.SYNOPSIS
    Displays detailed system information for the local machine.

.DESCRIPTION
    This PowerShell script collects and displays hardware and software information including
    OS, CPU, GPU, RAM, storage, network adapters, installed programs, Windows
    updates, and running services.

    Use -Export to save the output to a timestamped .log file on your Desktop.
    Use -Section to display only one specific category of information.

    The script requires administrator privileges and will automatically prompt for
    elevation if not already running as an administrator.

.PARAMETER Export
    Saves the console output to a timestamped .log file on the Desktop.
    The file is named:  SystemInfo_<YYYY-MM-DD_HH-mm-ss>.log

    If combined with -Section, the section name is included:
                    SystemInfo_GPU_<YYYY-MM-DD_HH-mm-ss>.log

.PARAMETER Section
    Runs and displays only the specified section. Accepted values:
    Uptime | OS | Users | CPU | RAM | Motherboard | GPU | Network | Storage | USB | Hotfixes | Programs | Services

.EXAMPLE
    PS> .\SystemInfo.ps1

    Runs all sections and prints the results to the console.

.EXAMPLE
    PS> .\SystemInfo.ps1 -Export

    Runs all sections, prints the results to the console, and exports a timestamped .log file to the Desktop.

.EXAMPLE
    PS> .\SystemInfo.ps1 -Section OS

    Displays OS section only.

.EXAMPLE
    PS> .\SystemInfo.ps1 -Section GPU -Export

    Displays GPU section and exports it to a timestamped .log file to the Desktop.

.LINK
	https://github.com/Joshua-7417/SystemInfo

.NOTES
    Author: Joshua
#>

param (
    [switch]$Export,

    [ValidateSet("Uptime","OS","Users","CPU","RAM","Motherboard","GPU","Network","Storage","USB","Hotfixes","Programs","Services","")]
    [string]$Section = ""
)

# If not running as administrator, relaunch elevated and exit current process
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

# ------------------------------------------------------------------
# Log buffer - plain-text lines collected when -Export is active
# ------------------------------------------------------------------
$script:LogLines = [System.Collections.Generic.List[string]]::new()

# ------------------------------------------------------------------
# Summary collectors - issues found during the run
# ------------------------------------------------------------------
$script:SummaryErrors   = [System.Collections.Generic.List[string]]::new()
$script:SummaryCautions = [System.Collections.Generic.List[string]]::new()

# ------------------------------------------------------------------
# Helper function to write to the console and to the logs.
# ------------------------------------------------------------------
function Write-Log {
    param (
        [string]$Message = "",
        [string]$ForegroundColor = ""
    )
    if ($ForegroundColor) {
        Write-Host $Message -ForegroundColor $ForegroundColor
    } else {
        Write-Host $Message
    }
    # Drop -ForegroundColor so the log file stays clean
    if ($Export) {
        $script:LogLines.Add($Message)
    }
}

# ------------------------------------------------------------------
# Helper function to write section headers
# ------------------------------------------------------------------
function Write-Header {
    param (
        [string]$Title
    )
    Write-Log ""
    Write-Log "$Title"
}

# ------------------------------------------------------------------
# Helper function to parse Extended Display Identification Data (EDID) and get "recommended" screen resolution
# ------------------------------------------------------------------
function Get-RecommendedResolution {
    param (
        [string]$HardwareID, # Hardware ID for the monitor in Windows Registry
        [string]$MonitorName # Display name for monitor (e.g. ROG XG27AQM)
    )

    # HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\DISPLAY\<HardwareID>\<InstanceID>
    # <InstanceID> - Unique ID for this physical connection (includes BusID, port, and UID).

    # Read EDID binary from registry, silently skip if key is protected or missing
    $edid = (Get-ItemProperty -Path $HardwareID -Name "EDID" -ErrorAction SilentlyContinue).EDID

    # We are interested in reading bytes 54-62, so if it's not that long, then we must return because its not proper format?!
    if (-not $edid -or $edid.Count -lt 62) {
        return
    }

    # EDID detailed timing descriptor starts at byte 54:
    # https://en.wikipedia.org/wiki/Extended_Display_Identification_Data

    # The monitor stores width and height in a 12-bit format across two bytes
    # nibble = 4 bits of a byte, "high nibble" means the leftmost 4 bits of a byte

    # Width  pixels: lower 8 bits = byte 56, upper 4 bits = high nibble of byte 58
    # Height pixels: lower 8 bits = byte 59, upper 4 bits = high nibble of byte 61

    # -band 0xF0 -> keeps only the high nibble
    # -shr 4 -> shifts it right 4 bits so the value becomes 0-15

    # Multiply by 256 (2^8) to move high nibble into bits 8-11, then add lower byte for full value

    $width  = $edid[56] + ((($edid[58] -band 0xF0) -shr 4) * 256)
    $height = $edid[59] + ((($edid[61] -band 0xF0) -shr 4) * 256)

    [PSCustomObject]@{
        MonitorName = $MonitorName
        Width       = $width
        Height      = $height
    }
}

# ------------------------------------------------------------------
# Up time
# ------------------------------------------------------------------
function Get-UptimeInfo {
    Write-Header "System Uptime"

    $uptime = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

    Write-Log "$($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes, $($uptime.Seconds) seconds"
}

# ------------------------------------------------------------------
# OS
# ------------------------------------------------------------------
function Get-OSInfo {
    Write-Header "Operating System"

    $os = Get-CimInstance -ClassName Win32_OperatingSystem

    Write-Log "Device Name    : $($os.CSName)"
    Write-Log "OS Name        : $($os.Caption)"

    # The DisplayVersion (e.g., 24H2) and Update Build Revision (UBR, .XXXX suffix in winver) are stored in the registry.
    # BuildNumber from WMI represents only the major build (e.g., 26100).
    $regVer  = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $release = $regVer.DisplayVersion
    $ubr     = $regVer.UBR
    Write-Log "Release        : $release"
    Write-Log "Build Number   : $($os.BuildNumber).$ubr"

    Write-Log "Architecture   : $($os.OSArchitecture)"
    Write-Log "Install Date   : $($os.InstallDate)"

    # Convert bytes -> GB
    $totalRamGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRamGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRamGB  = [math]::Round($totalRamGB - $freeRamGB, 2)

    Write-Log "Total RAM      : $totalRamGB GB"
    Write-Log "Used RAM       : $usedRamGB GB"
    Write-Log "Free RAM       : $freeRamGB GB"
    Write-Log "Last Boot      : $($os.LastBootUpTime)"
}

# ------------------------------------------------------------------
# Users
# ------------------------------------------------------------------
function Get-UserInfo {
    Write-Header "Users"

    # Get the list of user accounts
    $users = Get-CimInstance -ClassName Win32_UserAccount

    # Get the currently logged-in user
    $loggedInUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName

    Write-Log "Logged in as: $loggedInUser" -ForegroundColor Cyan
    Write-Log ""

    foreach ($user in $users)
    {
        if ($user.Disabled) {
            Write-Log "User          : $($user.Name) [DISABLED]" -ForegroundColor DarkRed
        } else {
            Write-Log "User          : $($user.Name)"
        }

        Write-Log "Local Account : $($user.LocalAccount)"
        Write-Log "SID           : $($user.SID)"
        Write-Log ""
    }
}

# ------------------------------------------------------------------
# CPU
# ------------------------------------------------------------------
function Get-CPUInfo {
    Write-Header "Processor (CPU)"

    # A machine can have multiple processors, so this returns an array
    $cpus = Get-CimInstance -ClassName Win32_Processor

    foreach ($cpu in $cpus) {
        Write-Log "Manufacturer   : $($cpu.Manufacturer)"
        Write-Log "Socket         : $($cpu.SocketDesignation)"
        Write-Log "Name           : $($cpu.Name)"
        Write-Log "Cores          : $($cpu.NumberOfCores)"
        Write-Log "Logical CPUs   : $($cpu.NumberOfLogicalProcessors)"
        Write-Log "Max Speed      : $($cpu.MaxClockSpeed) MHz"
        Write-Log "CPU Usage      : $($cpu.LoadPercentage)%"
    }
}

# ------------------------------------------------------------------
# Memory (RAM)
# ------------------------------------------------------------------
function Get-MemoryInfo {
    Write-Header "Memory (RAM)"

    $modules = Get-CimInstance -ClassName Win32_PhysicalMemory

    # Total capacity across all sticks
    $totalGB = [math]::Round(($modules | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
    Write-Log "Total Installed : $totalGB GB  ($(@($modules).Count) stick(s))"
    Write-Log ""

    # Detect CPU manufacturer once so we can label XMP (Intel) vs EXPO (AMD) correctly
    $cpuName = (Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1).Manufacturer
    $xcLabel = if ($cpuName -match "Intel") { "XMP" } elseif ($cpuName -match "AMD") { "EXPO" } else { "XMP/EXPO" }

    foreach ($stick in $modules) {
        $sizeGB = [math]::Round($stick.Capacity / 1GB, 2)

        # ConfiguredClockSpeed = what the BIOS is actually running the RAM at
        # Speed                = the rated/advertised speed on the stick
        $ratedMTs   = $stick.Speed
        $runningMTs = $stick.ConfiguredClockSpeed

        # Determine XMP/EXPO state by comparing running speed to rated speed
        if ($runningMTs -eq $ratedMTs) {
            # Running exactly at rated speed, XMP/EXPO is active (or kit is JEDEC native)
            $speedLabel = "$runningMTs MT/s ($xcLabel enabled, rated: $ratedMTs MT/s)"
            $speedColor = "Green"
        } elseif ($runningMTs -gt $ratedMTs) {
            # Running faster than rated, manually overclocked beyond XMP/EXPO profile
            $speedLabel = "$runningMTs MT/s (rated: $ratedMTs MT/s - Overclock)"
            $speedColor = "Yellow"
        } else {
            # Running slower than rated, XMP/EXPO is off, or manually underclocked
            $jedec = @(2133, 2400, 2666, 2933, 3200, 3600, 4000, 4400, 4800, 5200, 5600, 6000, 6400)
            $isJedec = $jedec -contains $runningMTs
            $speedLabel = if ($isJedec) {
                "$runningMTs MT/s (rated: $ratedMTs MT/s - $xcLabel OFF, JEDEC fallback)"
            } else {
                "$runningMTs MT/s (rated: $ratedMTs MT/s - Underclock)"
            }
            $speedColor = "DarkRed"
        }

        # Voltage - ConfiguredVoltage is in millivolts, divide by 1000 for volts
        $voltLabel = if ($stick.ConfiguredVoltage -gt 0) {
            "$([math]::Round($stick.ConfiguredVoltage / 1000, 3)) V"
        } else { "N/A" }

        # SMBIOSMemoryType
        $typeMap = @{ 20 = "DDR"; 21 = "DDR2"; 24 = "DDR3"; 26 = "DDR4"; 34 = "DDR5" }
        $memType = if ($typeMap.ContainsKey([int]$stick.SMBIOSMemoryType)) {
            $typeMap[[int]$stick.SMBIOSMemoryType]
        } else { "Unknown" }

        Write-Log "Slot           : $($stick.DeviceLocator) ($($stick.BankLabel))"
        Write-Log "Size           : $sizeGB GB"
        Write-Log "Type           : $memType"
        Write-Log "Speed          : $speedLabel" -ForegroundColor $speedColor
        Write-Log "Voltage        : $voltLabel"
        Write-Log "Manufacturer   : $($stick.Manufacturer)"
        Write-Log "Part Number    : $($stick.PartNumber.Trim())"
        Write-Log "Serial Number  : $($stick.SerialNumber.Trim())"
        Write-Log ""
    }
}

# ------------------------------------------------------------------
# Motherboard
# ------------------------------------------------------------------
function Get-MotherboardInfo {
    Write-Header "Motherboard"

    $bios  = Get-CimInstance -ClassName Win32_BIOS
    $board = Get-CimInstance -ClassName Win32_BaseBoard
    $secureBoot = Confirm-SecureBootUEFI

    Write-Log "BIOS Version / Date : $($bios.Manufacturer) $($bios.SMBIOSBIOSVersion) $($bios.ReleaseDate)"
    Write-Log "Board Manufacturer  : $($board.Manufacturer)"
    Write-Log "Board Model         : $($board.Product)"
    Write-Log "Serial Number       : $($board.SerialNumber)"

    if ($secureBoot) {
        Write-Log "Secure Boot State   : $secureBoot" -ForegroundColor Green
    } else {
        Write-Log "Secure Boot State   : $secureBoot" -ForegroundColor DarkRed
    }
}

# ------------------------------------------------------------------
# GPU
# ------------------------------------------------------------------
function Get-GPUInfo {
    Write-Header "Graphics Card (GPU)"

    $gpus       = Get-CimInstance -ClassName Win32_VideoController
    $monitorIDs = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID

    # Win32_VideoController.CurrentHorizontalResolution always returns the panel signal resolution,
    # not the desktop resolution. Screen.AllScreens is the correct source, but caches in the current
    # process. Spawning a fresh subprocess guarantees a live read every time.
    $desktopResolutions = @(powershell -NoProfile -Command {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
            "$($_.Bounds.Width) $($_.Bounds.Height)"
        }
    } | ForEach-Object {
        $parts = $_ -split ' '
        [PSCustomObject]@{ Width = [int]$parts[0]; Height = [int]$parts[1] }
    })

    # Win32_VideoController.AdapterRAM is a 32-bit field and caps at ~4GB regardless of real VRAM.
    # The real value is written by the driver to the registry under the adapter's key:
    # Display Adapters = 4d36e968-e325-11ce-bfc1-08002be10318
    $vramRegistry = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" `
                        -Name HardwareInformation.qwMemorySize -ErrorAction SilentlyContinue

    $recommendedResolutions = foreach ($id in $monitorIDs) {
        # Convert encoded monitor name to string (remove zero padding, cast to chars)
        $name = ($id.UserFriendlyName | Where-Object { $_ -ne 0 } |
                 ForEach-Object { [char]$_ }) -join ''

        # Build the registry path using id.InstanceName
        $regBase = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($id.InstanceName -replace '_\d+$','')\Device Parameters"
        $res = Get-RecommendedResolution -HardwareID $regBase -MonitorName $name

        if ($res) { $res }
    }

    foreach ($gpu in $gpus) {

        # Check if this is a known NVIDIA card by name — used to tailor failure messages,
        # but we still attempt nvidia-smi regardless in case of prototype/unlisted cards.
        $isNvidia = $gpu.Name -match "NVIDIA"
        $smi      = Get-Command "nvidia-smi.exe" -ErrorAction SilentlyContinue

        if ($smi) {
            try {
                $smiOutput   = nvidia-smi -q 2>&1
                $smiDriver   = ($smiOutput | Select-String "Driver Version" | Select-Object -First 1) -replace '.*:\s*', ''
                $linkSection = $smiOutput | Select-String "Link Width" -Context 0,2
                $linkMax     = ($linkSection.Context.PostContext | Select-String "Max")     -replace '[^\d]', ''
                $linkCurrent = ($linkSection.Context.PostContext | Select-String "Current") -replace '[^\d]', ''
                $bar1Section = $smiOutput | Select-String "BAR1 Memory Usage" -Context 0,2
                $bar1Total   = ($bar1Section.Context.PostContext | Select-String "Total")   -replace '[^\d]', ''
            } catch {
                # nvidia-smi exists but failed — hint at why if the card doesn't look like NVIDIA
                $failReason = if (-not $isNvidia) {
                    "nvidia-smi failed (card '$($gpu.Name)' does not appear to be NVIDIA)"
                } else {
                    "nvidia-smi failed for $($gpu.Name): $_"
                }
                Write-Log $failReason -ForegroundColor Yellow
                $script:SummaryCautions.Add($failReason)
                $smi = $null
            }
        }

        # GPU identity
        $driverLabel = if ($smi) { "$($gpu.DriverVersion)  ($($smiDriver.Trim()))" } else { $gpu.DriverVersion }
        Write-Log "Name           : $($gpu.Name)"
        Write-Log "Driver Version : $driverLabel"
        Write-Log "Driver Date    : $($gpu.DriverDate)"

        # VRAM - AdapterRAM is a 32-bit WMI field that caps at ~4GB, read real value from driver registry key
        $realVram = $vramRegistry | Where-Object { $_."HardwareInformation.qwMemorySize" -gt 0 } |
                    Select-Object -ExpandProperty "HardwareInformation.qwMemorySize" -First 1
        $vramGB = if ($realVram) {
            "$([math]::Round($realVram / 1GB, 2)) GB"
        } elseif ($gpu.AdapterRAM -gt 0) {
            "$([math]::Round($gpu.AdapterRAM / 1GB, 2)) GB (may be capped at 4GB by WMI)"
        } else {
            "Shared / Not reported"
        }
        Write-Log "VRAM           : $vramGB"

        if ($smi) {
            try {
                # PCIe link width (x16/x8) and generation from nvidia-smi -q "Link Width" section
                $pcieGenRaw = nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.gen.max --format=csv,noheader 2>&1
                $pcieGen    = $pcieGenRaw -split ',' | ForEach-Object { $_.Trim() }
                $pcieLabel  = "x$linkCurrent  (max x$linkMax)  |  Gen $($pcieGen[0])  (max Gen $($pcieGen[1]))"
                $pcieColor  = if ($linkCurrent -eq $linkMax -and $pcieGen[0] -eq $pcieGen[1]) { "Green" } else { "DarkRed" }
                Write-Log "PCIe Slot      : $pcieLabel" -ForegroundColor $pcieColor
                if ($linkCurrent -ne $linkMax -or $pcieGen[0] -ne $pcieGen[1]) {
                    $script:SummaryCautions.Add("GPU PCIe link running below maximum on $($gpu.Name): $pcieLabel")
                }

                # Detect ReBAR: BAR1 Total matches VRAM size when enabled or capped at 256 MiB when disabled
                $vramMiB    = if ($realVram) { [math]::Round($realVram / 1MB, 0) } else { 0 }
                $rebarOn    = [int]$bar1Total -gt 0 -and [int]$bar1Total -ge ($vramMiB * 0.95)
                $rebarLabel = if ($rebarOn) { "Enabled" } else { "Disabled" }
                $rebarColor = if ($rebarOn) { "Green" } else { "DarkRed" }
                Write-Log "Resizable BAR  : $rebarLabel" -ForegroundColor $rebarColor
                if (-not $rebarOn) {
                    $script:SummaryCautions.Add("Resizable BAR (ReBAR) is disabled on $($gpu.Name)")
                }
            } catch {
                $smi = $null
                Write-Log "nvidia-smi failed: $_" -ForegroundColor Yellow
            }
        } else {
            # nvidia-smi not found
            $noSmiMsg = if ($isNvidia) {
                "nvidia-smi not found, NVIDIA driver may not be installed"
            } else {
                "nvidia-smi not found, PCIe/ReBAR checks require an NVIDIA GPU and driver"
            }
            Write-Log "PCIe / ReBAR   : $noSmiMsg" -ForegroundColor DarkGray
        }
        Write-Log ""

        # @() forces an array so .Count is always a number, preventing 0..-1 generating two iterations
        foreach ($i in 0..(@($recommendedResolutions).Count - 1)) {
            $rec   = @($recommendedResolutions)[$i]
            $desk  = if ($i -lt $desktopResolutions.Count) { $desktopResolutions[$i] } else { $null }
            $deskW = if ($desk) { $desk.Width  } else { $gpu.CurrentHorizontalResolution }
            $deskH = if ($desk) { $desk.Height } else { $gpu.CurrentVerticalResolution }

            $resLabel = if (($deskW -eq $rec.Width) -and ($deskH -eq $rec.Height)) {
                "$deskW x $deskH (recommended)"
            } else {
                "$deskW x $deskH  [recommended: $($rec.Width) x $($rec.Height)]"
            }
            $resColor = if (($deskW -eq $rec.Width) -and ($deskH -eq $rec.Height)) { "Green" } else { "DarkRed" }
            if (($deskW -ne $rec.Width) -or ($deskH -ne $rec.Height)) {
                $script:SummaryCautions.Add("Monitor $($rec.MonitorName) not at recommended resolution ($($rec.Width) x $($rec.Height)), currently $deskW x $deskH")
            }

            $hzLabel = if ($gpu.CurrentRefreshRate -ge $gpu.MaxRefreshRate) {
                "$($gpu.CurrentRefreshRate) Hz (native)"
            } else {
                "$($gpu.CurrentRefreshRate) Hz  [native: $($gpu.MaxRefreshRate) Hz]"
            }
            $hzColor = if ($gpu.CurrentRefreshRate -ge $gpu.MaxRefreshRate) { "Green" } else { "DarkRed" }
            if ($gpu.CurrentRefreshRate -lt $gpu.MaxRefreshRate) {
                $script:SummaryCautions.Add("Monitor $($rec.MonitorName) refresh rate is $($gpu.CurrentRefreshRate) Hz, native is $($gpu.MaxRefreshRate) Hz")
            }

            Write-Log "Monitor        : $($rec.MonitorName)"
            Write-Log "Resolution     : $resLabel" -ForegroundColor $resColor
            Write-Log "Refresh Rate   : $hzLabel"  -ForegroundColor $hzColor
            Write-Log ""
        }
    }
}

# ------------------------------------------------------------------
# Network
# ------------------------------------------------------------------
function Get-NetworkInfo {
    Write-Header "Network Adapters"

    # IPEnabled = $true means the adapter has an IP address configured
    $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration |
                Where-Object { $_.IPEnabled -eq $true }

    foreach ($adapter in $adapters) {
        Write-Log "Adapter        : $($adapter.Description)"
        Write-Log "MAC Address    : $($adapter.MACAddress)"

        # IPAddress is an array (IPv4 + IPv6), grab just the first one
        Write-Log "IP Address      : $($adapter.IPAddress[0])"
        Write-Log "Subnet Mask     : $($adapter.IPSubnet[0])"
        Write-Log "Default Gateway : $($adapter.DefaultIPGateway)"
        Write-Log "DNS Servers     : $($adapter.DNSServerSearchOrder -join ', ')"
        Write-Log ""
    }
}

# ------------------------------------------------------------------
# Storage
# ------------------------------------------------------------------
function Get-StorageInfo {
    Write-Header "Storage"

    # Win32_DiskDrive = physical drives (e.g. Samsung 870 EVO)
    $physicalDisks = Get-CimInstance -ClassName Win32_DiskDrive | Sort-Object Index

    foreach ($disk in $physicalDisks) {

        # Partition style (MBR/GPT) is in Win32_DiskPartition via the disk index
        $partitionStyle = (Get-Disk -Number $disk.Index).PartitionStyle

        $totalGB = [math]::Round($disk.Size / 1GB, 2)

        Write-Log "Disk $($disk.Index)          : $($disk.Model)"
        Write-Log "Interface       : $($disk.InterfaceType)"
        Write-Log "Partition Style : $partitionStyle"
        Write-Log "Total Size      : $totalGB GB"
        Write-Log "Serial Number   : $($disk.SerialNumber.Trim())"
        Write-Log ""

        # Win32_DiskDriveToDiskPartition links physical disk -> partitions
        # Win32_LogicalDiskToPartition links partitions -> drive letters
        $partitions = Get-CimAssociatedInstance -InputObject $disk -ResultClassName Win32_DiskPartition

        foreach ($partition in $partitions) {
            $logicalDisks = Get-CimAssociatedInstance -InputObject $partition -ResultClassName Win32_LogicalDisk

            foreach ($logical in $logicalDisks) {
                $freeGB  = [math]::Round($logical.FreeSpace / 1GB, 2)
                $usedGB  = [math]::Round(($logical.Size - $logical.FreeSpace) / 1GB, 2)
                $sizeGB  = [math]::Round($logical.Size / 1GB, 2)
                $freePct = [math]::Round(($logical.FreeSpace / $logical.Size) * 100, 1)

                $volLabel = if ($logical.VolumeName) { " ($($logical.VolumeName))" } else { "" }

                Write-Log "  Drive        : $($logical.DeviceID)$volLabel"
                Write-Log "  Total        : $sizeGB GB"
                Write-Log "  Used         : $usedGB GB"

                # Warn when free space drops below 15% of total
                if ($freePct -lt 15) {
                    Write-Log "  Free         : $freeGB GB ($freePct%)  LOW DISK SPACE" -ForegroundColor DarkRed
                    $script:SummaryErrors.Add("Low disk space on $($logical.DeviceID)$volLabel - only $freeGB GB free ($freePct%)")
                } else {
                    Write-Log "  Free         : $freeGB GB ($freePct%)" -ForegroundColor Green
                }
                Write-Log ""
            }
        }
    }
}

# ------------------------------------------------------------------
# USB
# ------------------------------------------------------------------
function Get-USBInfo {
    Write-Header "USB"

    # Win32_PnPEntity gives all plug-and-play devices, filter to USB only
    $allUSB = Get-CimInstance -ClassName Win32_PnPEntity |
              Where-Object { $_.PNPDeviceID -like "USB\*" -and $_.Name -notmatch "Root Hub|Host Controller|Composite Device" } |
              Sort-Object Name

    # Split into named devices and generic "USB Input Device" entries
    $named   = $allUSB | Where-Object { $_.Name -notmatch "^USB (Input Device|Hub)$|Hub$" }
    $generic = $allUSB | Where-Object { $_.Name -match "^USB Input Device$" }
    $hubs    = $allUSB | Where-Object { $_.Name -match "Hub$" }

    Write-Log "Connected USB Devices : $($named.Count) named, $($generic.Count) generic input, $($hubs.Count) hub(s)"
    Write-Log ""

    Write-Log "-- Named Devices --" -ForegroundColor Cyan
    foreach ($device in $named) {
        $statusColor = if ($device.Status -eq "OK") { "Green" } else { "DarkRed" }
        Write-Log "Name           : $($device.Name)"
        Write-Log "Status         : $($device.Status)" -ForegroundColor $statusColor
        Write-Log "Device ID      : $($device.PNPDeviceID)"
        Write-Log ""
    }

    if ($generic.Count -gt 0) {
        Write-Log "-- Generic USB Input Devices --" -ForegroundColor DarkGray
        Write-Log "  $($generic.Count) device(s) reported as 'USB Input Device' (HID devices without a specific driver name)"
        Write-Log ""
        foreach ($device in $generic) {
            $statusColor = if ($device.Status -eq "OK") { "Green" } else { "DarkRed" }
            Write-Log "  Status         : $($device.Status)" -ForegroundColor $statusColor
            Write-Log "  Device ID      : $($device.PNPDeviceID)"
            Write-Log ""
        }
    }

    if ($hubs.Count -gt 0) {
        Write-Log "-- USB Hubs --" -ForegroundColor DarkGray
        Write-Log "  $($hubs.Count) hub(s) detected (internal USB components)"
        Write-Log ""
        foreach ($device in $hubs) {
            $statusColor = if ($device.Status -eq "OK") { "Green" } else { "DarkRed" }
            Write-Log "  Name           : $($device.Name)"
            Write-Log "  Status         : $($device.Status)" -ForegroundColor $statusColor
            Write-Log "  Device ID      : $($device.PNPDeviceID)"
            Write-Log ""
        }
    }
}

# ------------------------------------------------------------------
# Hotfixes (Windows Updates)
# ------------------------------------------------------------------
function Get-HotfixInfo {
    Write-Header "Installed Hotfixes"

    # Win32_QuickFixEngineering = installed Windows Updates
    $hotfixes = Get-CimInstance -ClassName Win32_QuickFixEngineering | Sort-Object InstalledOn -Descending

    Write-Log "Total Updates: $($hotfixes.Count)"
    Write-Log ""

    # Column widths
    $colID   = 12
    $colDate = 16
    $colDesc = 40

    # Header
    $header = "$("Hotfix ID".PadRight($colID))  $("Installed On".PadRight($colDate))  $("Description".PadRight($colDesc))"
    $divider = "$("-" * $colID)  $("-" * $colDate)  $("-" * $colDesc)"

    Write-Log $header  -ForegroundColor Cyan
    Write-Log $divider -ForegroundColor DarkGray

    foreach ($fix in $hotfixes) {
        $date = if ($fix.InstalledOn) { $fix.InstalledOn.ToString("yyyy-MM-dd") } else { "Unknown" }
        $desc = if ($fix.Description) { $fix.Description } else { "N/A" }

        # Truncate description if longer than column width
        if ($desc.Length -gt $colDesc) {
            $desc = $desc.Substring(0, $colDesc - 3) + "..."
        }

        Write-Log "$($fix.HotFixID.PadRight($colID))  $($date.PadRight($colDate))  $($desc.PadRight($colDesc))"
    }
}

# ------------------------------------------------------------------
# Installed Programs
# ------------------------------------------------------------------
function Get-InstalledPrograms {
    Write-Header "Installed Programs"

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", # 64-bit programs
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # 32-bit programs installed on 64-bit Windows
    )

    $programs = foreach ($path in $regPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
        Where-Object {
            # Filter out empty entries, Windows system components, and update packages
            $_.DisplayName -and
            $_.DisplayName -notmatch "^(KB\d+|Security Update|Update for)" -and
            $_.SystemComponent -ne 1
        } |
        Select-Object DisplayName, Publisher, DisplayVersion,
            @{ Name = "InstallDate"; Expression = {
                # InstallDate is stored as YYYYMMDD, reformat to YYYY-MM-DD
                if ($_.InstallDate -match '^\d{8}$') {
                    "$($_.InstallDate.Substring(0,4))-$($_.InstallDate.Substring(4,2))-$($_.InstallDate.Substring(6,2))"
                } else { "Unknown" }
            }}
    }

    # Remove potential duplicates, sort alphabetically
    $programs = $programs | Sort-Object DisplayName -Unique

    Write-Log "Total Programs: $($programs.Count)"
    Write-Log ""

    foreach ($prog in $programs) {
        Write-Log "  Name         : $($prog.DisplayName)"
        if ($prog.Publisher)      { Write-Log "  Publisher    : $($prog.Publisher)" }
        if ($prog.DisplayVersion) { Write-Log "  Version      : $($prog.DisplayVersion)" }
        Write-Log "  Install Date : $($prog.InstallDate)"
        Write-Log ""
    }
}

# ------------------------------------------------------------------
# Services
# ------------------------------------------------------------------
function Get-RunningServices {
    Write-Header "Services"

    $allServices = Get-CimInstance -ClassName Win32_Service | Sort-Object DisplayName

    $running  = $allServices | Where-Object { $_.State -eq "Running" }
    $stopped  = $allServices | Where-Object { $_.State -eq "Stopped" -and $_.StartMode -eq "Auto" }

    # Services set to Automatic but not running may have crashed
    $stoppedColor   = if ($stopped.Count -gt 0) { "Yellow" } else { "Green" }

    Write-Log "Running             : $($running.Count)"
    Write-Log "Stopped (Automatic) : $($stopped.Count)" -ForegroundColor $stoppedColor
    if ($stopped.Count -gt 0) {
        Write-Log "Warning: Some automatic services have stopped and may have crashed." -ForegroundColor Yellow
        $script:SummaryCautions.Add("$($stopped.Count) automatic service(s) are stopped and may have crashed")
    }
    Write-Log ""

    Write-Log "-- Running Services --" -ForegroundColor Cyan
    foreach ($svc in $running) {
        Write-Log "  $($svc.DisplayName.PadRight(45)) [$($svc.StartMode)]"
    }

    if ($stopped.Count -gt 0) {
        Write-Log ""
        Write-Log "-- Stopped (Automatic) Services --" -ForegroundColor DarkRed
        foreach ($svc in $stopped) {
            Write-Log "  $($svc.DisplayName.PadRight(45)) [Automatic - STOPPED]" -ForegroundColor Yellow
        }
    }
}

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
function Write-Summary {
    Write-Log ""
    Write-Log "=================================" -ForegroundColor Cyan
    Write-Log "============ SUMMARY ============" -ForegroundColor Cyan
    Write-Log "=================================" -ForegroundColor Cyan

    if ($script:SummaryErrors.Count -eq 0 -and $script:SummaryCautions.Count -eq 0) {
        Write-Log ""
        Write-Log "  No issues detected." -ForegroundColor Green
        Write-Log ""
        return
    }

    if ($script:SummaryErrors.Count -gt 0) {
        Write-Log ""
        Write-Log "  Errors" -ForegroundColor Red
        Write-Log "  ------" -ForegroundColor DarkGray
        foreach ($msg in $script:SummaryErrors) {
            Write-Log "  [!] $msg" -ForegroundColor Red
        }
    }

    if ($script:SummaryCautions.Count -gt 0) {
        Write-Log ""
        Write-Log "  Cautions" -ForegroundColor Yellow
        Write-Log "  --------" -ForegroundColor DarkGray
        foreach ($msg in $script:SummaryCautions) {
            Write-Log "  [?] $msg" -ForegroundColor Yellow
        }
    }

    Write-Log ""
}

# ------------------------------------------------------------------
# Map section names to each function
# ------------------------------------------------------------------
$allSections = [ordered]@{
    Uptime      = { Get-UptimeInfo      }
    OS          = { Get-OSInfo          }
    Users       = { Get-UserInfo        }
    CPU         = { Get-CPUInfo         }
    RAM         = { Get-MemoryInfo      }
    Motherboard = { Get-MotherboardInfo }
    Storage     = { Get-StorageInfo     }
    Network     = { Get-NetworkInfo     }
    GPU         = { Get-GPUInfo         }
    USB         = { Get-USBInfo         }
    Services    = { Get-RunningServices }
    Hotfixes    = { Get-HotfixInfo      }
    Programs    = { Get-InstalledPrograms }
}

# ------------------------------------------------------------------
# Header (always shown)
# ------------------------------------------------------------------
$now        = Get-Date
$bannerLine = "================================="
$bannerTitle = "========== SYSTEM INFO =========="
$timestamp  = "Generated: $($now.ToString('yyyy-MM-dd  HH:mm:ss'))"

Write-Log $bannerLine  -ForegroundColor Red
Write-Log $bannerTitle -ForegroundColor Red
Write-Log $bannerLine  -ForegroundColor Red
Write-Log $timestamp

# ------------------------------------------------------------------
# Run sections
# ------------------------------------------------------------------
if ($Section -ne "") {
    # Run sections specified in launch argument
    $key = $allSections.Keys | Where-Object { $_ -eq $Section }
    if ($key) {
        & $allSections[$key]
        Write-Summary
    } else {
        Write-Host "Unknown section '$Section'. Valid values: $($allSections.Keys -join ', ')" -ForegroundColor DarkRed
        exit 1
    }
} else {
    # Run all sections
    foreach ($key in $allSections.Keys) {
        & $allSections[$key]
    }
    Write-Summary
}

# ------------------------------------------------------------------
# Export to log file
# ------------------------------------------------------------------
if ($Export) {
    $desktopPath = [System.Environment]::GetFolderPath("Desktop")
    $sectionTag  = if ($Section -ne "") { "_$Section" } else { "" }
    $fileName    = "SystemInfo$sectionTag`_$($now.ToString('yyyy-MM-dd_HH-mm-ss')).log"
    $logPath     = Join-Path $desktopPath $fileName

    $script:LogLines | Set-Content -Path $logPath -Encoding UTF8

    Write-Host ""
    Write-Host "Log saved to: $logPath" -ForegroundColor Cyan
}

# ------------------------------------------------------------------
# Wait for user input, automatically close if -Export is used
# ------------------------------------------------------------------
if (-not $Export) {
    Write-Host ""
    Read-Host "Press Enter to exit"
}
