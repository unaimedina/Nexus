function Get-OfficeC2RConfig {
    $cfg = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
    if (Test-Path $cfg) { return (Get-ItemProperty $cfg) }
    return $null
}

function Get-OfficeClickToRunExe {
    $exe = Join-Path $env:CommonProgramFiles "Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    if (Test-Path $exe) { return $exe }
    return $null
}

function Get-OfficeInfo {
    $sb  = New-Object System.Text.StringBuilder
    $sep = "[*] ==============================================="
    [void]$sb.AppendLine("[+] OFFICE INSTALLATION INFO")
    [void]$sb.AppendLine($sep)

    $c = Get-OfficeC2RConfig
    if ($c) {
        [void]$sb.AppendLine("    Edition     : Click-to-Run")
        [void]$sb.AppendLine("    Products    : $($c.ProductReleaseIds)")
        [void]$sb.AppendLine("    Platform    : $($c.Platform)")
        [void]$sb.AppendLine("    Version     : $($c.VersionToReport)")
        [void]$sb.AppendLine("    Culture     : $($c.ClientCulture)")
        [void]$sb.AppendLine("    InstallPath : $($c.InstallationPath)")
    } else {
        [void]$sb.AppendLine("    No Click-to-Run Office detected.")
        [void]$sb.AppendLine("    (May be an MSI/legacy install or Office is not present.)")
    }
    return $sb.ToString()
}

function Repair-OfficeApps {
    param([ValidateSet('QuickRepair', 'FullRepair')][string]$RepairType = 'QuickRepair')

    $sb  = New-Object System.Text.StringBuilder
    $sep = "[*] ==============================================="
    [void]$sb.AppendLine("[+] OFFICE $RepairType".ToUpper())
    [void]$sb.AppendLine($sep)

    $exe = Get-OfficeClickToRunExe
    if (-not $exe) {
        [void]$sb.AppendLine("    [FAIL] OfficeClickToRun.exe not found.")
        [void]$sb.AppendLine("    Office may be MSI-based or not installed; repair from")
        [void]$sb.AppendLine("    'Apps & features' -> Microsoft Office -> Modify.")
        return $sb.ToString()
    }

    $c        = Get-OfficeC2RConfig
    $platform = if ($c -and $c.Platform) { $c.Platform } else { "x64" }
    $culture  = if ($c -and $c.ClientCulture) { $c.ClientCulture } else { "en-us" }

    try {
        Start-Process -FilePath $exe -ArgumentList @(
            "scenario=Repair",
            "platform=$platform",
            "culture=$culture",
            "RepairType=$RepairType",
            "DisplayLevel=True"
        ) -ErrorAction Stop
        [void]$sb.AppendLine("    [OK] Office $RepairType launched ($platform / $culture).")
        if ($RepairType -eq 'FullRepair') {
            [void]$sb.AppendLine("    Online repair requires an internet connection and may take a while.")
        }
        [void]$sb.AppendLine("    Follow the Office repair window to complete the process.")
    } catch {
        [void]$sb.AppendLine("    [FAIL] Could not launch repair: $($_.Exception.Message)")
    }
    return $sb.ToString()
}
