function WindowsUpdateScript {
    $sb  = New-Object System.Text.StringBuilder
    $sep = "[*] ==============================================="

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    [void]$sb.AppendLine("[+] WINDOWS UPDATE TROUBLESHOOTING")
    [void]$sb.AppendLine($sep)
    if (-not $isAdmin) {
        [void]$sb.AppendLine("    [WARN] Standard user. Some service details may be inaccessible.")
        [void]$sb.AppendLine()
    }

    # Services Windows Update depends on. Most are trigger/Manual start, so Stopped is
    # normal; the real faults are Disabled, or an Auto service that isn't running.
    [void]$sb.AppendLine("[+] Update services")
    $services = [ordered]@{
        wuauserv         = "Windows Update"
        bits             = "Background Intelligent Transfer"
        cryptsvc         = "Cryptographic Services"
        msiserver        = "Windows Installer"
        TrustedInstaller = "Windows Modules Installer"
    }
    foreach ($name in $services.Keys) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $svc) {
            [void]$sb.AppendLine("    [FAIL] $($services[$name]) ($name): not found")
            continue
        }
        $startMode = (Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue).StartMode
        $marker = if ($startMode -eq 'Disabled') { "[FAIL]" }
                  elseif ($startMode -eq 'Auto' -and $svc.Status -ne 'Running') { "[WARN]" }
                  else { "[OK]" }
        [void]$sb.AppendLine("    $marker $($services[$name]) ($name): $($svc.Status) / $startMode")
    }
    [void]$sb.AppendLine()

    # Recently installed updates
    [void]$sb.AppendLine("[+] Recently installed updates")
    $hotfixes = @(Get-HotFix -ErrorAction SilentlyContinue | Where-Object InstalledOn |
                  Sort-Object InstalledOn -Descending | Select-Object -First 5)
    if ($hotfixes.Count -eq 0) {
        [void]$sb.AppendLine("    [WARN] No dated update history available.")
    }
    else {
        foreach ($h in $hotfixes) {
            $when = $h.InstalledOn.ToString("yyyy-MM-dd")
            [void]$sb.AppendLine("    $($h.HotFixID.PadRight(12)) $when  $($h.Description)")
        }
        if ($hotfixes[0].InstalledOn -lt (Get-Date).AddDays(-60)) {
            [void]$sb.AppendLine("    [WARN] Last update was over 60 days ago.")
        }
    }
    [void]$sb.AppendLine()

    # Pending reboot
    [void]$sb.AppendLine("[+] Pending reboot")
    $pendingKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    if ($pendingKeys | Where-Object { Test-Path $_ }) {
        [void]$sb.AppendLine("    [WARN] A reboot is pending to finish updates.")
    }
    else {
        [void]$sb.AppendLine("    [OK] No pending reboot detected.")
    }
    [void]$sb.AppendLine()

    # Download cache
    [void]$sb.AppendLine("[+] Update cache")
    $sd = Join-Path $env:WINDIR "SoftwareDistribution\Download"
    if (Test-Path $sd) {
        $bytes = (Get-ChildItem $sd -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        $size  = [math]::Round(([double]$bytes) / 1MB, 1)
        [void]$sb.AppendLine("    SoftwareDistribution\Download: $size MB")
        if ($size -gt 1024) {
            [void]$sb.AppendLine("    [WARN] Large cache. Resetting it may help if updates are stuck.")
        }
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("    Tip: if updates fail, stop wuauserv & bits, rename SoftwareDistribution, then restart them.")

    return $sb.ToString()
}
