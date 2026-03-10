param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

function Get-PdfVersionStatePath {
    param([string]$RootPath)
    return (Join-Path $RootPath "tools\pdf-version-state.json")
}

function Get-SnapshotDir {
    param([string]$RootPath)
    return (Join-Path $RootPath "tools\pdf-version-snapshots")
}

function Read-PdfVersionState {
    param([string]$StatePath)

    if (-not (Test-Path $StatePath)) {
        throw "Missing pdf version state file: $StatePath"
    }

    $raw = Get-Content -Path $StatePath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Empty pdf version state file: $StatePath"
    }

    return ($raw | ConvertFrom-Json)
}

function Get-LatestSnapshotPath {
    param([string]$SnapshotDir)

    if (-not (Test-Path $SnapshotDir)) {
        return $null
    }

    return Get-ChildItem -Path $SnapshotDir -Filter "*.json" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function Compare-PdfVersionStates {
    param(
        [pscustomobject]$Current,
        [pscustomobject]$Previous
    )

    $changes = New-Object System.Collections.Generic.List[object]
    $currentFiles = $Current.Files.PSObject.Properties | ForEach-Object { $_.Name }
    $previousFiles = if ($Previous) { $Previous.Files.PSObject.Properties | ForEach-Object { $_.Name } } else { @() }

    foreach ($path in $currentFiles) {
        $currentEntry = $Current.Files.$path
        $previousEntry = if ($Previous) { $Previous.Files.$path } else { $null }

        if (-not $previousEntry) {
            [void]$changes.Add([PSCustomObject]@{
                Path = $path
                Status = "new"
                OldVersion = $null
                NewVersion = $currentEntry.Version
            })
            continue
        }

        if ($currentEntry.ContentHash -ne $previousEntry.ContentHash) {
            [void]$changes.Add([PSCustomObject]@{
                Path = $path
                Status = "updated"
                OldVersion = $previousEntry.Version
                NewVersion = $currentEntry.Version
            })
        }
    }

    foreach ($path in $previousFiles) {
        if (-not $Current.Files.PSObject.Properties.Name.Contains($path)) {
            [void]$changes.Add([PSCustomObject]@{
                Path = $path
                Status = "removed"
                OldVersion = $Previous.Files.$path.Version
                NewVersion = $null
            })
        }
    }

    return $changes
}

function Save-Snapshot {
    param(
        [string]$SnapshotDir,
        [pscustomobject]$State
    )

    if (-not (Test-Path $SnapshotDir)) {
        New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $snapshotPath = Join-Path $SnapshotDir ("pdf-version-state-{0}.json" -f $timestamp)
    $State | ConvertTo-Json -Depth 6 | Set-Content -Path $snapshotPath -Encoding UTF8
    return $snapshotPath
}

$statePath = Get-PdfVersionStatePath -RootPath $Root
$snapshotDir = Get-SnapshotDir -RootPath $Root
$currentState = Read-PdfVersionState -StatePath $statePath

$latestSnapshot = Get-LatestSnapshotPath -SnapshotDir $snapshotDir
$previousState = $null
if ($latestSnapshot) {
    $previousState = Read-PdfVersionState -StatePath $latestSnapshot
}

$changes = Compare-PdfVersionStates -Current $currentState -Previous $previousState

Write-Host "PDF version changes since last snapshot:"
if ($changes.Count -eq 0) {
    Write-Host "  No changes detected."
}
else {
    foreach ($change in $changes) {
        $old = if ($change.OldVersion) { $change.OldVersion } else { "-" }
        $new = if ($change.NewVersion) { $change.NewVersion } else { "-" }
        Write-Host ("  {0} | {1} -> {2} | {3}" -f $change.Status, $old, $new, $change.Path)
    }
}

$snapshotPath = Save-Snapshot -SnapshotDir $snapshotDir -State $currentState
Write-Host "Snapshot saved to: $snapshotPath"

$changesReportPath = Join-Path $Root "tools\pdf-version-changes.json"
$changesReport = [PSCustomObject]@{
    RunAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    Changes = $changes
}
$changesReport | ConvertTo-Json -Depth 6 | Set-Content -Path $changesReportPath -Encoding UTF8
Write-Host "Changes JSON saved to: $changesReportPath"
