#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads all tools in parallel, organized into group folders. ZIPs are extracted and then deleted.
    Optionally adds C:\ss1 to Windows Defender exclusions (requires admin).
.NOTES
    Tune $MaxThreads to match your connection. 16 is default for speed.
#>

$ProgressPreference = 'SilentlyContinue'

# ── recorder killer ─────────────────────────────

$forbiddenProcesses = @(

    "obs","obs32","obs64","streamlabs","camtasia","bandicam","xsplit",
    "fraps","action","dxtory","sharex","screenrec","flashback","bdcam",
    "gamebar","xboxgamebar","gamebarpresencewriter","broadcastdvr",
    "steam","steamwebhelper","overwolf","teams","riotclientservices","epicgameslauncher",
    "nvcontainer","nvdisplay.container","nvidiashare","nvbackend",
    "nvsphelper64","nvstreamer","nvtray","nvtelemetry","nvfbc","nvifrex",
    "amdsoftware","radeonsoftware","amdxcapture","amdenc","amddvr"
)

$detected = @{}
$allProcs = Get-Process -ErrorAction SilentlyContinue

foreach ($proc in $allProcs) {
    try {
        $name = $proc.Name.ToLower()
        $isForbidden = $forbiddenProcesses -contains $name
        $isCapture = $false

        $modules = $proc.Modules.ModuleName
        if (
            $modules -contains "Windows.Graphics.Capture.dll" -or
            $modules -match "graphicscapture" -or
            $modules -match "nvencodeapi" -or
            $modules -match "amdenc|amf"
        ) {
            $isCapture = $true
        }

        if (($isForbidden -or $isCapture) -and -not $detected.ContainsKey($name)) {
            $detected[$name] = $proc.Name
        }
    } catch {}
}

foreach ($procName in $detected.Values) {
    Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

# ── Defender Exclusion Prompt (with admin check & auto-elevation) ────────────

$ExclusionPath = 'C:\ss1'

function Test-Admin {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-DefenderExclusion {
    param([string]$Path)
    try {
        Add-MpPreference -ExclusionPath $Path -ErrorAction Stop
        Write-Host "  [+] Added Defender exclusion for $Path" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  [x] Failed to add exclusion: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Check if exclusion already exists
$existingExclusions = (Get-MpPreference -ErrorAction SilentlyContinue).ExclusionPath
if ($existingExclusions -contains $ExclusionPath) {
    Write-Host "  [~] Defender exclusion for $ExclusionPath already exists." -ForegroundColor DarkGray
} else {
    Write-Host ""
    Write-Host "Do you want to add '$ExclusionPath' to Windows Defender exclusion list?" -ForegroundColor Cyan
    Write-Host "This helps prevent false positives and improves performance. (Y/N)" -ForegroundColor Cyan
    $choice = Read-Host
    if ($choice -eq 'Y' -or $choice -eq 'y') {
        if (-not (Test-Admin)) {
            Write-Host "  [!] Administrator rights required to modify Defender settings." -ForegroundColor Yellow
            Write-Host "  [*] Attempting to relaunch script as administrator..." -ForegroundColor Yellow
            $scriptPath = $MyInvocation.MyCommand.Path
            if (-not $scriptPath) {
                Write-Host "  [x] Cannot determine script path. Please run PowerShell as Administrator manually." -ForegroundColor Red
            } else {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "powershell.exe"
                $psi.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
                $psi.Verb = "runas"
                try {
                    [System.Diagnostics.Process]::Start($psi)
                    exit
                } catch {
                    Write-Host "  [x] Elevation failed: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "  [x] Please run the script as Administrator manually to add the exclusion." -ForegroundColor Red
                }
            }
        } else {
            Add-DefenderExclusion -Path $ExclusionPath
        }
    } else {
        Write-Host "  [-] Skipped Defender exclusion." -ForegroundColor DarkGray
    }
}

Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────

$BaseDir    = 'C:\ss1'
$MaxThreads = 16

$Groups = [ordered]@{
    'Spokwn' = @(
        'https://github.com/spokwn/JournalTrace/releases/latest/download/JournalTrace.exe'
        'https://github.com/spokwn/PathsParser/releases/latest/download/PathsParser.exe'
        'https://github.com/spokwn/BAM-parser/releases/latest/download/BAMParser.exe'
        'https://github.com/spokwn/prefetch-parser/releases/latest/download/PrefetchParser.exe'
        'https://github.com/spokwn/pcasvc-executed/releases/download/v0.8.7/PcaSvcExecuted.exe'
        'https://github.com/spokwn/ActivitiesCache-execution/releases/download/v0.6.5/ActivitiesCacheParser.exe'
        'https://github.com/spokwn/Replaceparser/releases/latest/download/Replaceparser.exe'
        'https://github.com/spokwn/BamDeletedKeys/releases/latest/download/BamDeletedKeys.exe'
        'https://github.com/spokwn/Tool/releases/latest/download/espouken.exe'
        'https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe'
    )
    'Nirsoft' = @(
        'https://www.nirsoft.net/utils/winprefetchview-x64.zip'
        'https://www.nirsoft.net/utils/lastactivityview.zip'
        'https://www.nirsoft.net/utils/executedprogramslist.zip'
        'https://www.nirsoft.net/utils/userassistview.zip'
        'https://www.nirsoft.net/utils/alternatestreamview-x64.zip'
        'https://www.nirsoft.net/utils/hashmyfiles-x64.zip'
        'https://www.nirsoft.net/utils/jumplistsview.zip'
        'https://www.nirsoft.net/utils/opensavefilesview-x64.zip'
        'https://www.nirsoft.net/utils/usbdeview-x64.zip'
        'https://www.nirsoft.net/utils/turnedontimesview.zip'
        'https://www.nirsoft.net/utils/regscanner-x64.zip'
        'https://www.nirsoft.net/utils/browserdownloadsview-x64.zip'
        'https://www.nirsoft.net/utils/driverview-x64.zip'
        'https://www.nirsoft.net/utils/fileaccesserrorview-x64.zip'
        'https://www.nirsoft.net/utils/previousfilesrecovery-x64.zip'
        'https://www.nirsoft.net/utils/recentfilesview.zip'
        'https://www.nirsoft.net/utils/shellbagsview.zip'
        'https://www.nirsoft.net/utils/taskschedulerview-x64.zip'
        'https://www.nirsoft.net/utils/uninstallview-x64.zip'
        'https://www.nirsoft.net/utils/usbdrivelog.zip'
    )
    'Eric Zimmerman' = @(
        'https://download.ericzimmermanstools.com/net/PECmd.zip'
        'https://download.ericzimmermanstools.com/net/MFTExplorer.zip'
        'https://download.ericzimmermanstools.com/net/JLECmd.zip'
        'https://download.ericzimmermanstools.com/net/SrumECmd.zip'
        'https://download.ericzimmermanstools.com/net/bstrings.zip'
        'https://download.ericzimmermanstools.com/net/RecentFileCacheParser.zip'
        'https://download.ericzimmermanstools.com/net/RegistryExplorer.zip'
        'https://download.ericzimmermanstools.com/net/JumpListExplorer.zip'
        'https://download.ericzimmermanstools.com/net/ShellBagsExplorer.zip'
        'https://download.ericzimmermanstools.com/net/TimelineExplorer.zip'
        'https://builds.dotnet.microsoft.com/dotnet/Sdk/9.0.308/dotnet-sdk-9.0.308-win-x64.exe'
    )
    'Generic Tools' = @(
        'https://github.com/winsiderss/si-builds/releases/download/3.2.25275.112/systeminformer-build-canary-setup.exe'
        'https://www.voidtools.com/Everything-1.4.1.1029.x64-Setup.exe'
        'https://www.dropbox.com/scl/fi/q428cz9l0uq50bg3azh57/AccessData_FTK_Imager_4.7.1.exe?rlkey=o6w5ot98zb3wpo12n4rlwowhb&st=230sgk3i&dl=1'
        'https://download.ccleaner.com/rcsetup154.exe'
        'https://github.com/horsicq/DIE-engine/releases/download/3.10/die_win64_portable_3.10_x64.zip'
        'https://mh-nexus.de/downloads/HxDPortableSetup.zip'
        'https://github.com/deathmarine/Luyten/releases/download/v0.5.4_Rebuilt_with_Latest_depenencies/luyten-0.5.4.exe'
        'https://github.com/Col-E/Recaf/releases/download/2.21.14/recaf-2.21.14-J8-jar-with-dependencies.jar'
        'https://download.sysinternals.com/files/Autoruns.zip'
        'https://github.com/Yamato-Security/hayabusa/releases/download/v3.7.0/hayabusa-3.7.0-win-x64.zip'
        'https://storage.googleapis.com/mfi-files/free_tools/MagnetRAMCapture/MRCv120.exe'
        'https://github.com/sadreck/Spartacus/releases/download/v2.2.2/Spartacus-v2.2.2-x64.zip'
	'https://github.com/TheCruZ/BootViewer/releases/download/v1.1.1/BootViewer-amd64.exe'
	'https://github.com/MeowTonynoh/MeowClientFucker/releases/download/V1.1/MeowClientFucker.exe'

    )
    'Red Lotus' = @(
        'https://github.com/ItzIceHere/RedLotus-Task-Sentinel/releases/download/RL/RedLotusTaskSentinel.exe'
        'https://github.com/ItzIceHere/RedLotus-Mod-Analyzer/releases/download/RL/RedLotusModAnalyzer.exe'
        'https://github.com/ItzIceHere/RedLotusAltChecker/releases/download/RL/RedLotusAltChecker.exe'
    )
    'detect.ac tools' = @(
        'https://detect.ac/tool/Autoruns++'
        'https://detect.ac/tool/StringExplorer++'
        'https://detect.ac/tool/WinPrefetchView++'
        'https://detect.ac/tool/SRUMExplorer++'
        'https://detect.ac/tool/PowerShellParser++'
        'https://detect.ac/tool/MFTExplorer++'
        'https://detect.ac/tool/JournalTrace++'
        'https://detect.ac/tool/CrashedFileViewer++'
        'https://detect.ac/tool/BamParser++'
        'https://detect.ac/tool/AmcacheParser++'
        'https://detect.ac/tool/BrowserDownloadsView++'
	'https://detect.ac/tool/Collector++'
    )
    'orbdiff+' = @(
        'https://github.com/Orbdiff/USNJournal_CLI/releases/download/v1.0/Journal_CLI.exe'
        'https://github.com/Orbdiff/Fileless/releases/download/v1.3/fileless.exe'
        'https://github.com/Orbdiff/StringsParser/releases/download/v1.2.1b/stringsparser.1.2.1b.exe'
    )
}

# ── Build flat task list; force .exe extension for detect.ac tools ───────────

$Tasks = [System.Collections.Generic.List[hashtable]]::new()

foreach ($Group in $Groups.GetEnumerator()) {
    $GroupDir = Join-Path $BaseDir $Group.Key
    [void](New-Item -ItemType Directory -Force -Path $GroupDir)

    foreach ($Url in $Group.Value) {
        $uri = [System.Uri]$Url
        $uriExt = [IO.Path]::GetExtension($uri.LocalPath)
        
        # For detect.ac tools, explicitly force .exe extension
        if ($Group.Key -eq 'detect.ac tools') {
            $toolName = $uri.Segments[-1].TrimEnd('/')
            $fileName = "$toolName.exe"
        } else {
            $fileName = if ($uriExt) { [IO.Path]::GetFileName($uri.LocalPath) } else { '' }
        }

        $Tasks.Add(@{
            Url      = $Url
            GroupDir = $GroupDir
            Group    = $Group.Key
            FileName = $fileName
        })
    }
}

# ── Worker scriptblock – now deletes ZIP after extraction ────────────────────

$Worker = {
    param(
        [string]$Url,
        [string]$GroupDir,
        [string]$Group,
        [string]$FileName
    )

    $ProgressPreference = 'SilentlyContinue'

    # If no filename was provided (only happens for non-detect.ac tools without extension),
    # try to get it via HEAD request.
    if (-not $FileName) {
        try {
            $head = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop
            $cd   = $head.Headers['Content-Disposition']
            if ($cd -match 'filename\*?=(?:UTF-8'''')?(?:"([^"]+)"|([^;\s\r\n]+))') {
                $FileName = ($matches[1], $matches[2] | Where-Object { $_ })[0].Trim('"').Trim()
            }
        } catch { }

        if (-not $FileName) {
            $FileName = ([System.Uri]$Url).Segments[-1].TrimEnd('/') -replace '[^\w\.\-\+]', '_'
        }
    }

    $FilePath = Join-Path $GroupDir $FileName
    $IsZip    = $FileName -like '*.zip'
    $Status   = 'OK'
    $Err      = ''

    try {
        if (Test-Path $FilePath) {
            $Status = 'EXIST'
            if ($IsZip) {
                $xDir = Join-Path $GroupDir ([IO.Path]::GetFileNameWithoutExtension($FilePath))
                if (-not (Test-Path $xDir)) {
                    Expand-Archive -Path $FilePath -DestinationPath $xDir -Force
                    $Status = 'EXIST_EXTRACTED'
                    Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
                } else {
                    # ZIP already extracted – delete the stale ZIP
                    Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Invoke-WebRequest -Uri $Url -OutFile $FilePath -UseBasicParsing -ErrorAction Stop

            if ($IsZip) {
                $xDir = Join-Path $GroupDir ([IO.Path]::GetFileNameWithoutExtension($FilePath))
                Expand-Archive -Path $FilePath -DestinationPath $xDir -Force
                $Status = 'OK_EXTRACTED'
                Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        $Status = 'FAIL'
        $Err    = $_.Exception.Message
        if (Test-Path $FilePath) { Remove-Item $FilePath -Force -ErrorAction SilentlyContinue }
    }

    [PSCustomObject]@{
        Group    = $Group
        FileName = $FileName
        Status   = $Status
        Error    = $Err
    }
}

# ── Create RunspacePool and submit all jobs ──────────────────────────────────

$Pool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
$Pool.ApartmentState = 'STA'
$Pool.Open()

$Jobs = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($Task in $Tasks) {
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $Pool
    [void]$ps.AddScript($Worker)
    [void]$ps.AddParameter('Url',      $Task.Url)
    [void]$ps.AddParameter('GroupDir', $Task.GroupDir)
    [void]$ps.AddParameter('Group',    $Task.Group)
    [void]$ps.AddParameter('FileName', $Task.FileName)

    $Jobs.Add([PSCustomObject]@{
        PS     = $ps
        Handle = $ps.BeginInvoke()
    })
}

# ── Poll for completed jobs and print each result as it finishes ──────────────

$Total   = $Jobs.Count
$Done    = 0
$Pad     = $Total.ToString().Length
$Results = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-Host ''
Write-Host 'Parallel Tool Downloader' -ForegroundColor Cyan
Write-Host '========================' -ForegroundColor Cyan
Write-Host "  Files : $Total   Threads : $MaxThreads   Output : $BaseDir" -ForegroundColor DarkGray
Write-Host ''

while ($Jobs.Count -gt 0) {
    $completed = @($Jobs | Where-Object { $_.Handle.IsCompleted })

    foreach ($Job in $completed) {
        $r = $Job.PS.EndInvoke($Job.Handle)[0]
        [void]$Job.PS.Dispose()
        $Results.Add($r)
        [void]$Jobs.Remove($Job)
        $Done++

        $counter = '  [{0}{1}/{2}]' -f (' ' * ($Pad - $Done.ToString().Length)), $Done, $Total

        switch ($r.Status) {
            'OK'              { Write-Host "$counter  [+]  [$($r.Group)]  $($r.FileName)"               -ForegroundColor Green    }
            'OK_EXTRACTED'    { Write-Host "$counter  [+]  [$($r.Group)]  $($r.FileName)  -> extracted + zip removed" -ForegroundColor Green }
            'EXIST'           { Write-Host "$counter  [~]  [$($r.Group)]  $($r.FileName)"               -ForegroundColor DarkGray }
            'EXIST_EXTRACTED' { Write-Host "$counter  [~]  [$($r.Group)]  $($r.FileName)  -> re‑extracted + zip removed" -ForegroundColor DarkGray }
            'FAIL'            {
                                Write-Host "$counter  [x]  [$($r.Group)]  $($r.FileName)"               -ForegroundColor Red
                                Write-Host (' ' * ($Pad + 16)) + $r.Error                               -ForegroundColor DarkRed
                              }
        }
    }

    if ($Jobs.Count -gt 0) { Start-Sleep -Milliseconds 150 }
}

$Pool.Close()
$Pool.Dispose()

# ── Summary ───────────────────────────────────────────────────────────────────

$cOk   = @($Results | Where-Object { $_.Status -like 'OK*'    }).Count
$cSkip = @($Results | Where-Object { $_.Status -like 'EXIST*' }).Count
$cFail = @($Results | Where-Object { $_.Status -eq   'FAIL'   }).Count

Write-Host ''
Write-Host '─────────────────────────────────────────' -ForegroundColor DarkGray
Write-Host "  Downloaded : $cOk"   -ForegroundColor Green
Write-Host "  Skipped    : $cSkip" -ForegroundColor DarkGray

if ($cFail -gt 0) {
    Write-Host "  Failed     : $cFail" -ForegroundColor Red
    Write-Host ''
    Write-Host '  Failed files:' -ForegroundColor Red
    $Results | Where-Object Status -eq 'FAIL' | ForEach-Object {
        Write-Host "    [$($_.Group)]  $($_.FileName)" -ForegroundColor Red
        Write-Host "    $($_.Error)"                   -ForegroundColor DarkRed
    }
}

Write-Host "  Output     : $BaseDir" -ForegroundColor Cyan
Write-Host ''

# ── Additional items: C:\data and Sysinternals ───────────────────────────────

Write-Host ''
Write-Host 'Processing additional items...' -ForegroundColor Cyan

$DataFolder = 'C:\data'
if (-not (Test-Path $DataFolder)) {
    New-Item -ItemType Directory -Path $DataFolder -Force | Out-Null
    Write-Host '  [+] Created folder: C:\data' -ForegroundColor Green
} else {
    Write-Host '  [~] Folder already exists: C:\data' -ForegroundColor DarkGray
}

$SysZipPath = 'C:\sysinternals.zip'
$SysDest    = 'C:\sysinternals'

if (Test-Path $SysDest) {
    Write-Host '  [~] Sysinternals already exists at C:\sysinternals' -ForegroundColor DarkGray
} else {
    Write-Host '  [*] Downloading SysinternalsSuite.zip...' -ForegroundColor DarkGray
    try {
        Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/SysinternalsSuite.zip' -OutFile $SysZipPath -UseBasicParsing -ErrorAction Stop
        Write-Host '  [*] Extracting to C:\sysinternals...' -ForegroundColor DarkGray
        Expand-Archive -Path $SysZipPath -DestinationPath $SysDest -Force
        Remove-Item $SysZipPath -Force
        Write-Host '  [+] Sysinternals Suite installed at C:\sysinternals (ZIP deleted)' -ForegroundColor Green
    } catch {
        Write-Host "  [x] Failed to download/extract Sysinternals: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $SysZipPath) { Remove-Item $SysZipPath -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
Write-Host 'All tasks completed.' -ForegroundColor Cyan
