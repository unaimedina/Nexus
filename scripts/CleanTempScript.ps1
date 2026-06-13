function CleanTempScript {
    $sb  = New-Object System.Text.StringBuilder
    $sep = "[*] ==============================================="

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    $targets = @(
        [pscustomobject]@{ Name = "User temp (%TEMP%)";   Path = $env:TEMP;                                 NeedsAdmin = $false }
        [pscustomobject]@{ Name = "Windows temp";         Path = (Join-Path $env:SystemRoot "Temp");        NeedsAdmin = $true  }
        [pscustomobject]@{ Name = "Prefetch";             Path = (Join-Path $env:SystemRoot "Prefetch");    NeedsAdmin = $true  }
    )

    [void]$sb.AppendLine("[+] TEMPORARY FILES CLEANUP")
    [void]$sb.AppendLine($sep)
    if (-not $isAdmin) {
        [void]$sb.AppendLine("    [WARN] Standard user. Windows temp and Prefetch require administrator privileges.")
        [void]$sb.AppendLine()
    }

    $totalFreed = 0
    foreach ($t in $targets) {
        [void]$sb.AppendLine("[+] $($t.Name)")
        [void]$sb.AppendLine("    Path : $($t.Path)")

        if (-not $t.Path -or -not (Test-Path -LiteralPath $t.Path)) {
            [void]$sb.AppendLine("    [WARN] Path not found, skipped.")
            [void]$sb.AppendLine()
            continue
        }
        if ($t.NeedsAdmin -and -not $isAdmin) {
            [void]$sb.AppendLine("    [WARN] ACCESS DENIED. Administrator privileges required, skipped.")
            [void]$sb.AppendLine()
            continue
        }

        $items = @(Get-ChildItem -LiteralPath $t.Path -Force -ErrorAction SilentlyContinue)
        $before = ($items | Measure-Object -Property Length -Sum).Sum
        if (-not $before) { $before = 0 }

        $removed = 0
        $failed  = 0
        foreach ($item in $items) {
            try {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                $removed++
            } catch {
                $failed++
            }
        }

        $remaining = @(Get-ChildItem -LiteralPath $t.Path -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        if (-not $remaining) { $remaining = 0 }
        $freed = $before - $remaining
        if ($freed -lt 0) { $freed = 0 }
        $totalFreed += $freed

        [void]$sb.AppendLine("    Freed   : $([math]::Round($freed / 1MB, 1)) MB")
        [void]$sb.AppendLine("    Removed : $removed item(s)")
        if ($failed -gt 0) {
            [void]$sb.AppendLine("    [WARN] $failed item(s) in use or locked, left in place.")
        } else {
            [void]$sb.AppendLine("    [OK] Cleaned.")
        }
        [void]$sb.AppendLine()
    }

    [void]$sb.AppendLine($sep)
    [void]$sb.AppendLine("[+] TOTAL SPACE FREED: $([math]::Round($totalFreed / 1MB, 1)) MB")
    [void]$sb.AppendLine()

    return $sb.ToString()
}
