function EventViewerScript {
    $sb  = New-Object System.Text.StringBuilder
    $sep = "[*] ==============================================="

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    $hoursBack = 24
    $maxPerLog = 10
    $since     = (Get-Date).AddHours(-$hoursBack)

    [void]$sb.AppendLine("[+] EVENT VIEWER ANALYSIS (last $hoursBack h)")
    [void]$sb.AppendLine($sep)
    if (-not $isAdmin) {
        [void]$sb.AppendLine("    [WARN] Standard user. The Security log and some entries may be inaccessible.")
        [void]$sb.AppendLine()
    }

    # Level: 1 = Critical, 2 = Error
    $logs = @("System", "Application")
    foreach ($log in $logs) {
        [void]$sb.AppendLine("[+] $log log")

        $events = $null
        try {
            $events = @(Get-WinEvent -FilterHashtable @{
                LogName   = $log
                Level     = 1, 2
                StartTime = $since
            } -ErrorAction Stop)
        } catch {
            if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound') {
                $events = @()
            } else {
                [void]$sb.AppendLine("    [FAIL] Unable to read log: $($_.Exception.Message)")
                [void]$sb.AppendLine()
                continue
            }
        }

        $crit = @($events | Where-Object { $_.Level -eq 1 }).Count
        $err  = @($events | Where-Object { $_.Level -eq 2 }).Count
        [void]$sb.AppendLine("    Critical : $crit    Error : $err    Total : $($events.Count)")

        if ($events.Count -eq 0) {
            [void]$sb.AppendLine("    [OK] No critical or error events in this window.")
            [void]$sb.AppendLine()
            continue
        }

        $grouped = $events |
            Group-Object -Property ProviderName, Id |
            Sort-Object Count -Descending |
            Select-Object -First $maxPerLog

        [void]$sb.AppendLine("    Top sources by occurrence:")
        foreach ($g in $grouped) {
            $first   = $g.Group[0]
            $provider = $first.ProviderName
            $id       = $first.Id
            $lvl      = if ($first.Level -eq 1) { "CRIT" } else { "ERR " }
            $last     = $first.TimeCreated.ToString("MM-dd HH:mm")
            $msg      = ($first.Message -split "[\r\n]")[0]
            if ($msg.Length -gt 90) { $msg = $msg.Substring(0, 90) + "..." }
            [void]$sb.AppendLine("      [$lvl] x$($g.Count.ToString().PadRight(3)) $provider (ID $id) last $last")
            [void]$sb.AppendLine("            $msg")
        }
        [void]$sb.AppendLine()
    }

    return $sb.ToString()
}
