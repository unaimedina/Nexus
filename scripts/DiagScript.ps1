function DiagScript {
    $sb  = New-Object System.Text.StringBuilder
    $sep = "[*] ==============================================="

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    [void]$sb.AppendLine("[+] INITIATING DNS FLUSH SEQUENCE")
    [void]$sb.AppendLine($sep)
    [void]$sb.AppendLine((ipconfig /flushdns | Out-String).Trim())
    [void]$sb.AppendLine()

    [void]$sb.AppendLine("[+] REQUESTING NEW IP LEASE")
    [void]$sb.AppendLine($sep)
    [void]$sb.AppendLine((ipconfig /release | Out-String).Trim())
    [void]$sb.AppendLine((ipconfig /renew   | Out-String).Trim())
    [void]$sb.AppendLine()

    [void]$sb.AppendLine("[+] SPOOLER SERVICE RESTART")
    [void]$sb.AppendLine($sep)
    if ($isAdmin) {
        try {
            Restart-Service -Name Spooler -Force -ErrorAction Stop
            [void]$sb.AppendLine("    [OK] Spooler service successfully restarted.")
        } catch {
            [void]$sb.AppendLine("    [FAIL] Error restarting Spooler: $_")
        }
    } else {
        [void]$sb.AppendLine("    [WARN] ACCESS DENIED. Administrator privileges required.")
    }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine("[+] EXTERNAL CONNECTIVITY PING TEST")
    [void]$sb.AppendLine($sep)
    try {
        $ping  = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send("google.com", 4000)
        [void]$sb.AppendLine("    ComputerName   : google.com")
        [void]$sb.AppendLine("    RemoteAddress  : $($reply.Address)")
        [void]$sb.AppendLine("    PingSucceeded  : $($reply.Status -eq 'Success')")
        [void]$sb.AppendLine("    RoundtripTime  : $($reply.RoundtripTime) ms")
        if ($reply.Status -ne 'Success') {
            [void]$sb.AppendLine("    Status         : $($reply.Status)")
        }
    } catch {
        [void]$sb.AppendLine("    [WARN] No response. Network might still be resetting.")
        [void]$sb.AppendLine("    Detail         : $($_.Exception.InnerException.Message)")
    }
    [void]$sb.AppendLine()

    return $sb.ToString()
}