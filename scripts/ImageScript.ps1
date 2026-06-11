function ImageScript {
    $sb  = New-Object System.Text.StringBuilder
    $sep = "[*] ==============================================="

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        [void]$sb.AppendLine("[+] SYSTEM IMAGE VERIFICATION")
        [void]$sb.AppendLine($sep)
        [void]$sb.AppendLine("    [WARN] ACCESS DENIED. Administrator privileges required to run DISM / SFC.")
        [void]$sb.AppendLine()
        return $sb.ToString()
    }

    [void]$sb.AppendLine("[+] DEPLOYMENT IMAGE SERVICING AND MANAGEMENT (DISM) SCAN")
    [void]$sb.AppendLine($sep)
    try {
        [void]$sb.AppendLine((DISM /Online /Cleanup-Image /ScanHealth | Out-String).Trim())
    } catch {
        [void]$sb.AppendLine("    [FAIL] Error running DISM: $_")
    }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine("[+] SYSTEM FILE CHECKER (SFC) VERIFICATION")
    [void]$sb.AppendLine($sep)
    try {
        [void]$sb.AppendLine((sfc /scannow | Out-String).Trim())
    } catch {
        [void]$sb.AppendLine("    [FAIL] Error running SFC: $_")
    }
    [void]$sb.AppendLine()

    return $sb.ToString()
}