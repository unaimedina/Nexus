Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptsDir = Join-Path $scriptDir "scripts"
$UiDir = Join-Path $scriptDir "ui"

foreach ($module in "Test-IsAdmin", "DiagScript", "DiskScript", "ImageScript", "CleanTempScript", "EventViewerScript", "OfficeScript") {
    $path = Join-Path $ScriptsDir "$module.ps1"
    if (Test-Path $path) { . $path }
}

if (-not (Get-Command Test-IsAdmin -ErrorAction SilentlyContinue)) {
    function global:Test-IsAdmin {
        return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    }
}

function Import-XamlWindow {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "XAML file not found: $Path" }
    [xml]$doc = Get-Content -Path $Path -Raw
    $reader = New-Object System.Xml.XmlNodeReader $doc
    return [System.Windows.Markup.XamlReader]::Load($reader)
}

$Form = Import-XamlWindow (Join-Path $UiDir "MainWindow.xaml")

$btnNetworkDiag = $Form.FindName("btnNetworkDiag")
$btnDiskCheck = $Form.FindName("btnDiskCheck")
$btnImageVerify = $Form.FindName("btnImageVerify")
$btnCleanTemp = $Form.FindName("btnCleanTemp")
$btnEventViewer = $Form.FindName("btnEventViewer")
$btnAppSolutions = $Form.FindName("btnAppSolutions")
$btnClear = $Form.FindName("btnClear")
$txtOutput = $Form.FindName("txtOutput")
$scrollViewer = $Form.FindName("scrollViewer")
$txtAdminStatus = $Form.FindName("txtAdminStatus")
$panelOffice = $Form.FindName("panelOffice")
$btnOfficeInfo = $Form.FindName("btnOfficeInfo")
$btnOfficeQuick = $Form.FindName("btnOfficeQuick")
$btnOfficeOnline = $Form.FindName("btnOfficeOnline")

$logoPath = Join-Path $scriptDir "assets\logo.png"
if (Test-Path $logoPath) {
    $logoBmp = New-Object System.Windows.Media.Imaging.BitmapImage
    $logoBmp.BeginInit()
    $logoBmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $logoBmp.UriSource = New-Object System.Uri($logoPath)
    $logoBmp.EndInit()
    $logoBmp.Freeze()
    $imgLogo = $Form.FindName("imgLogo")
    if ($imgLogo) { $imgLogo.Source = $logoBmp }
}

$iconPath = Join-Path $scriptDir "assets\logo.ico"
if (Test-Path $iconPath) {
    $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
        (New-Object System.Uri($iconPath)),
        [System.Windows.Media.Imaging.BitmapCreateOptions]::None,
        [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    $Form.Icon = ($dec.Frames | Sort-Object { [math]::Abs($_.PixelWidth - 32) } | Select-Object -First 1)
}
elseif ($logoBmp) {
    $Form.Icon = $logoBmp
}

function Write-Console {
    param([string]$Text, [string]$Color = "#e5e5e5")
    $run = New-Object System.Windows.Documents.Run
    $run.Text = "$Text`n"
    $run.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Color)
    $txtOutput.Inlines.Add($run)
    $scrollViewer.ScrollToBottom()

    [System.Windows.Forms.Application]::DoEvents()
}

function Get-DiagnosisFindings {
    param([string]$Text)
    $findings = New-Object System.Collections.Generic.List[object]
    $add = { param($m, $c) $findings.Add([pscustomobject]@{ Msg = $m; Color = $c }) }

    if ($Text -match 'No se puede iniciar el servicio|Error al reiniciar Spooler|Error restarting Spooler|\[FAIL\][^\r\n]*Spooler|Cannot start service[^\r\n]*Spooler|Spooler[^\r\n]*(could not be started|cannot be started)') {
        & $add "Print Spooler service failed to start." "#ef4444"
    }
    if ($Text -match 'PingSucceeded\s*:\s*False' -or $Text -match 'No response\. Network might still be resetting' -or
        $Text -match 'Request timed out|Ping request could not find host|Destination host unreachable') {
        & $add "No external connectivity: ping to google.com failed." "#ef4444"
    }
    if ($Text -match 'ACCESS DENIED|Acceso denegado|Administrator privileges required|privilegios de administrador') {
        & $add "Administrator privileges required for one or more actions." "#fbbf24"
    }
    if ($Text -match 'ScanResult\s*:\s*(\w+)' -and $Matches[1] -ne 'NoErrorsFound') {
        & $add "File system scan reported: $($Matches[1])." "#fbbf24"
    }
    if ($Text -match '\[FAIL\][^\r\n]*(scanning volume|chkdsk|escanear el volumen)') {
        & $add "Error scanning the system volume." "#ef4444"
    }
    if (($Text -match 'almac.n de componentes' -and $Text -notmatch 'No se detectaron da.os') -or
        ($Text -match 'component store' -and $Text -match 'repairable|corruption' -and $Text -notmatch 'No component store corruption')) {
        & $add "DISM detected component store corruption." "#ef4444"
    }
    if ($Text -match 'encontr. archivos da.ados|found corrupt files|no pudo reparar|was unable to fix|did find corrupt files') {
        & $add "SFC found corrupted system files." "#ef4444"
    }

    return $findings
}

function Write-DiagnosisSummary {
    param([string]$Text)
    $findings = Get-DiagnosisFindings $Text
    Write-Console "" "#525252"
    Write-Console "[!] DIAGNOSIS SUMMARY" "#e4ff3a"
    if ($findings.Count -eq 0) {
        Write-Console "    [OK] No issues detected." "#22c55e"
    }
    else {
        foreach ($f in $findings) { Write-Console "    - $($f.Msg)" $f.Color }
    }
}

if (Test-IsAdmin) {
    $txtAdminStatus.Text = "Auth: root privileges"
    $txtAdminStatus.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#22c55e")
}
else {
    $txtAdminStatus.Text = "Auth: standard user"
    $txtAdminStatus.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#ef4444")
}

Write-Console "Nexus diagnostic initialized." "#e4ff3a"
Write-Console "Awaiting operator input.`n" "#525252"

$script:diagBusy = $false

function Start-DiagTask {
    param([string]$ScriptFile, [string]$FunctionName, [string]$Label)

    if ($script:diagBusy) {
        Write-Console "Busy: a task is already running." "#fbbf24"
        return
    }
    if (-not (Test-Path $ScriptFile)) {
        Write-Console "ERROR: $FunctionName module not found." "#ef4444"
        return
    }

    $script:diagBusy = $true
    Write-Console "> Executing $Label..." "#e4ff3a"

    $btnNetworkDiag.IsEnabled = $false
    $btnDiskCheck.IsEnabled = $false
    $btnImageVerify.IsEnabled = $false
    $btnCleanTemp.IsEnabled = $false
    $btnEventViewer.IsEnabled = $false

    $script:diagRs = [runspacefactory]::CreateRunspace()
    $script:diagRs.ApartmentState = "STA"
    $script:diagRs.ThreadOptions = "ReuseThread"
    $script:diagRs.Open()
    $script:diagPs = [powershell]::Create()
    $script:diagPs.Runspace = $script:diagRs
    [void]$script:diagPs.AddScript(". `"$ScriptFile`"; & `"$FunctionName`"")
    $script:diagHandle = $script:diagPs.BeginInvoke()

    $script:diagTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:diagTimer.Interval = [TimeSpan]::FromMilliseconds(150)
    $script:diagTimer.Add_Tick({
            if (-not $script:diagHandle.IsCompleted) { return }
            $script:diagTimer.Stop()
            try {
                $out = $script:diagPs.EndInvoke($script:diagHandle)
                $text = ($out | Out-String).Trim()
                if ([string]::IsNullOrWhiteSpace($text)) { $text = "(no output)" }
                Write-Console $text "#e5e5e5"
                Write-DiagnosisSummary $text
            }
            catch {
                Write-Console "ERROR: $($_.Exception.Message)" "#ef4444"
            }
            finally {
                $script:diagPs.Dispose(); $script:diagRs.Close(); $script:diagRs.Dispose()
                $btnNetworkDiag.IsEnabled = $true
                $btnDiskCheck.IsEnabled = $true
                $btnImageVerify.IsEnabled = $true
                $btnCleanTemp.IsEnabled = $true
                $btnEventViewer.IsEnabled = $true
                $script:diagBusy = $false
                Write-Console "Task completed.`n" "#22c55e"
            }
        })
    $script:diagTimer.Start()
}

function Update-ImageLine {
    param([string]$Text, [bool]$IsProgress)
    if ($IsProgress) {
        if (-not $script:imgProgRun) {
            $script:imgProgRun = New-Object System.Windows.Documents.Run
            $script:imgProgRun.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#e4ff3a")
            $txtOutput.Inlines.Add($script:imgProgRun)
        }
        $script:imgProgRun.Text = "    $Text`n"
    }
    else {
        $script:imgProgRun = $null
        $script:imgLog += "$Text`n"
        if ($Text -match '^\[\+\]') { Write-Console $Text "#e4ff3a" }
        else { Write-Console "    $Text" "#e5e5e5" }
    }
    $scrollViewer.ScrollToBottom()
}

function Read-ImageOutput {
    $len = $script:imgFs.Length
    if ($len -gt $script:imgFs.Position) {
        $count = [int]($len - $script:imgFs.Position)
        $buf = New-Object byte[] $count
        $read = $script:imgFs.Read($buf, 0, $count)
        $chunk = New-Object System.Text.StringBuilder
        for ($i = 0; $i -lt $read; $i++) { if ($buf[$i] -ne 0) { [void]$chunk.Append([char]$buf[$i]) } }
        $script:imgBuffer += $chunk.ToString()
    }

    $parts = [regex]::Split($script:imgBuffer, "[\r\n]")
    $script:imgBuffer = $parts[-1]
    if ($parts.Count -gt 1) {
        foreach ($p in $parts[0..($parts.Count - 2)]) {
            $t = $p.Trim()
            if ($t) { Update-ImageLine $t ($t -match '%') }
        }
    }
    $tail = $script:imgBuffer.Trim()
    if ($tail -and $tail -match '%') { Update-ImageLine $tail $true }
}

function Start-ImageVerify {
    if ($script:diagBusy) { Write-Console "Busy: a task is already running." "#fbbf24"; return }

    Write-Console "> Executing System Image Verification..." "#e4ff3a"
    if (-not (Test-IsAdmin)) {
        Write-Console "    [WARN] ACCESS DENIED. Administrator privileges required to run DISM / SFC." "#fbbf24"
        Write-Console "Task completed.`n" "#22c55e"
        return
    }

    $script:diagBusy = $true
    $btnNetworkDiag.IsEnabled = $false
    $btnDiskCheck.IsEnabled = $false
    $btnImageVerify.IsEnabled = $false
    $btnCleanTemp.IsEnabled = $false
    $btnEventViewer.IsEnabled = $false

    $script:imgProgRun = $null
    $script:imgBuffer = ""
    $script:imgLog = ""
    $script:imgOut = [System.IO.Path]::GetTempFileName()

    $cmd = '/c echo [+] DISM /Online /Cleanup-Image /ScanHealth' +
    ' & DISM /Online /Cleanup-Image /ScanHealth' +
    ' & echo. & echo [+] SFC /scannow' +
    ' & sfc /scannow'
    $script:imgProc = Start-Process -FilePath "cmd.exe" -ArgumentList $cmd `
        -WindowStyle Hidden -RedirectStandardOutput $script:imgOut -PassThru

    $script:imgFs = [System.IO.File]::Open($script:imgOut, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)

    $script:imgTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:imgTimer.Interval = [TimeSpan]::FromMilliseconds(250)
    $script:imgTimer.Add_Tick({
            Read-ImageOutput
            if ($script:imgProc.HasExited) {
                Read-ImageOutput
                $tail = $script:imgBuffer.Trim()
                if ($tail) { Update-ImageLine $tail ($tail -match '%') }
                $script:imgTimer.Stop()
                $script:imgFs.Close()
                Remove-Item $script:imgOut -Force -ErrorAction SilentlyContinue
                Write-DiagnosisSummary $script:imgLog
                $btnNetworkDiag.IsEnabled = $true
                $btnDiskCheck.IsEnabled = $true
                $btnImageVerify.IsEnabled = $true
                $btnCleanTemp.IsEnabled = $true
                $btnEventViewer.IsEnabled = $true
                $script:diagBusy = $false
                Write-Console "Task completed.`n" "#22c55e"
            }
        })
    $script:imgTimer.Start()
}

$btnNetworkDiag.Add_Click({ Start-DiagTask (Join-Path $ScriptsDir "DiagScript.ps1") "DiagScript" "Network Diagnostics" })
$btnDiskCheck.Add_Click({ Start-DiagTask (Join-Path $ScriptsDir "DiskScript.ps1") "DiskScript" "Disk Usage Analysis" })
$btnImageVerify.Add_Click({ Start-ImageVerify })
$btnCleanTemp.Add_Click({ Start-DiagTask (Join-Path $ScriptsDir "CleanTempScript.ps1") "CleanTempScript" "Temporary Files Cleanup" })
$btnEventViewer.Add_Click({ Start-DiagTask (Join-Path $ScriptsDir "EventViewerScript.ps1") "EventViewerScript" "Event Viewer Analysis" })

$btnAppSolutions.Add_Click({
        if ($panelOffice.Visibility -eq [System.Windows.Visibility]::Visible) {
            $panelOffice.Visibility = [System.Windows.Visibility]::Collapsed
        }
        else {
            $panelOffice.Visibility = [System.Windows.Visibility]::Visible
            Write-Console "> Application solutions ready. Select an action." "#e4ff3a"
        }
    })

$btnOfficeInfo.Add_Click({ Write-Console (Get-OfficeInfo) "#e5e5e5" })
$btnOfficeQuick.Add_Click({
        Write-Console "> Launching Office Quick Repair..." "#e4ff3a"
        Write-Console (Repair-OfficeApps -RepairType QuickRepair) "#e5e5e5"
    })
$btnOfficeOnline.Add_Click({
        Write-Console "> Launching Office Online Repair..." "#e4ff3a"
        Write-Console (Repair-OfficeApps -RepairType FullRepair) "#e5e5e5"
    })

$btnClear.Add_Click({
        $txtOutput.Inlines.Clear()
        Write-Console "Console purged.`n" "#525252"
    })

if (-not ([System.Management.Automation.PSTypeName]'NexusFocus').Type) {
    Add-Type -Namespace '' -Name 'NexusFocus' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetForegroundWindow(System.IntPtr hWnd);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@
}

$Form.Add_Loaded({
        $Form.WindowState = [System.Windows.WindowState]::Maximized
        $Form.Activate()
        $Form.Topmost = $true
        $Form.Topmost = $false
        $helper = New-Object System.Windows.Interop.WindowInteropHelper $Form
        [void][NexusFocus]::ShowWindow($helper.Handle, 9)   # SW_RESTORE
        [void][NexusFocus]::SetForegroundWindow($helper.Handle)
        $Form.Focus()
    })

$Form.ShowDialog() | Out-Null
