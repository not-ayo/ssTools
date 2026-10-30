
# Export-StartupInfo.ps1
# Extract process information from Windows WDI StartupInfo XML logs.
# Output: C:\ss1\startupexe.csv

$Source = Join-Path $env:windir 'System32\WDI\LogFiles\StartupInfo'
$OutputDirectory = 'C:\ss1'
$OutputFile = Join-Path $OutputDirectory 'startupexe.csv'
$ErrorFile = Join-Path $OutputDirectory 'startupexe-errors.csv'

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "StartupInfo directory not found: $Source"
}

New-Item -Path $OutputDirectory -ItemType Directory -Force |
    Out-Null

$Results = [System.Collections.Generic.List[object]]::new()
$Errors = [System.Collections.Generic.List[object]]::new()

function Get-XmlValue {
    param(
        [System.Xml.XmlNode]$Node,
        [string[]]$Names
    )

    foreach ($Name in $Names) {
        # Search descendant elements, ignoring XML element-name casing.
        $LowerName = $Name.ToLowerInvariant()
        $XPath = ".//*[translate(local-name(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')='$LowerName']"
        $Match = $Node.SelectSingleNode($XPath)

        if ($Match -and
            -not [string]::IsNullOrWhiteSpace($Match.InnerText)) {
            return $Match.InnerText.Trim()
        }

        # Also check attributes on the current node.
        if ($Node.Attributes) {
            foreach ($Attribute in $Node.Attributes) {
                if ($Attribute.LocalName -ieq $Name -and
                    -not [string]::IsNullOrWhiteSpace($Attribute.Value)) {
                    return $Attribute.Value.Trim()
                }
            }
        }
    }

    return $null
}

$Files = Get-ChildItem -LiteralPath $Source -Filter '*.xml' -File -Recurse

foreach ($File in $Files) {
    try {
        [xml]$Xml = Get-Content -LiteralPath $File.FullName -Raw

        $ProcessNodes = $Xml.SelectNodes(
            "//*[translate(local-name(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')='process']"
        )

        if ($ProcessNodes.Count -eq 0) {
            $ProcessNodes = $Xml.SelectNodes(
                "//*[translate(local-name(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')='processinfo']"
            )
        }

        if ($ProcessNodes.Count -eq 0) {
            $ProcessNodes = $Xml.SelectNodes(
                "//*[translate(local-name(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')='processname']/.."
            )
        }

        foreach ($Node in $ProcessNodes) {
            $Name = Get-XmlValue $Node @(
                'ProcessName', 'ImageName', 'ExecutableName', 'Name'
            )

            $ExecutablePath = Get-XmlValue $Node @(
                'ExecutablePath', 'ImagePath', 'ProcessPath'
            )

            if (-not $ExecutablePath) {
                $ExecutablePath = $Name
            }

            $CommandLine = Get-XmlValue $Node @('CommandLine')
            $PidValue = Get-XmlValue $Node @('ProcessId', 'PID')
            $ParentPid = Get-XmlValue $Node @(
                'ParentProcessId', 'ParentPID', 'ParentPid'
            )
            $ParentName = Get-XmlValue $Node @(
                'ParentProcessName', 'ParentName'
            )
            $StartTime = Get-XmlValue $Node @(
                'StartTime', 'ProcessStartTime', 'StartTimestamp'
            )
            $ParentStartTime = Get-XmlValue $Node @(
                'ParentStartTime', 'ParentProcessStartTime'
            )

            $Results.Add([PSCustomObject]@{
                ExecutedTime      = $StartTime
                ExecutablePath    = $ExecutablePath
                ProcessName       = $Name
                ProcessId         = $PidValue
                CommandLine       = $CommandLine
                ParentProcessName = $ParentName
                ParentProcessId   = $ParentPid
                ParentStartTime   = $ParentStartTime
                SourceLog         = $File.FullName
                LogLastWriteTime  = $File.LastWriteTime
            })
        }
    }
    catch {
        $Errors.Add([PSCustomObject]@{
            SourceLog = $File.FullName
            Error     = $_.Exception.Message
        })

        Write-Warning "Could not parse $($File.FullName): $($_.Exception.Message)"
    }
}

if ($Results.Count -gt 0) {
    $Results |
        Sort-Object ExecutedTime, SourceLog, ProcessId |
        Export-Csv -LiteralPath $OutputFile `
            -NoTypeInformation -Encoding UTF8

    Write-Host "Export complete: $OutputFile" -ForegroundColor Green
    Write-Host "Records exported: $($Results.Count)"
}
else {
    Write-Warning 'No process records extracted. Check the XML structure and permissions.'
}

if ($Errors.Count -gt 0) {
    $Errors |
        Export-Csv -LiteralPath $ErrorFile `
            -NoTypeInformation -Encoding UTF8

    Write-Warning "Some files could not be parsed. Details: $ErrorFile"
}
