function DiskScript {
    $sb  = New-Object System.Text.StringBuilder
    $sep = "[*] ==============================================="

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    [void]$sb.AppendLine("[+] STORAGE VOLUMES ANALYSIS")
    [void]$sb.AppendLine($sep)
    try {
        $vols = Get-Volume | Where-Object { $_.DriveLetter } |
            Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus,
                @{ N = "Size(GB)"; E = { [math]::Round($_.Size / 1GB, 1) } },
                @{ N = "Free(GB)"; E = { [math]::Round($_.SizeRemaining / 1GB, 1) } }
        [void]$sb.AppendLine(($vols | Format-Table -AutoSize | Out-String).Trim())
    } catch {
        [void]$sb.AppendLine("    [FAIL] Unable to retrieve volume stats: $_")
    }
    [void]$sb.AppendLine()

    $sys       = $env:SystemDrive
    $sysLetter = $sys.TrimEnd(':')
    [void]$sb.AppendLine("[+] FILE SYSTEM INTEGRITY SCAN (READ-ONLY) ON $sys")
    [void]$sb.AppendLine($sep)
    if ($isAdmin) {
        try {
            $scan = Repair-Volume -DriveLetter $sysLetter -Scan -ErrorAction Stop
            [void]$sb.AppendLine("    DriveLetter : $sysLetter")
            [void]$sb.AppendLine("    ScanResult  : $scan")
            if ($scan -eq 'NoErrorsFound') {
                [void]$sb.AppendLine("    [OK] No file system errors detected.")
            } else {
                [void]$sb.AppendLine("    [WARN] Issues reported. A full repair (chkdsk /F) may be required at next reboot.")
            }
        } catch {
            [void]$sb.AppendLine("    [FAIL] Error scanning volume: $($_.Exception.Message)")
        }
    } else {
        [void]$sb.AppendLine("    [WARN] ACCESS DENIED. Administrator privileges required for deep scan.")
    }
    [void]$sb.AppendLine()

    return $sb.ToString()
}