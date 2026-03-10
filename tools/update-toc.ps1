param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$DocsRoot = "Products",
    [string]$TocPath = $null,
    [string]$SectionName = "Product Support Documentation",
    [string]$SectionHref = "Products/Nodes/ADNode.md",
    [switch]$Flat
)

$ErrorActionPreference = "Stop"

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath)
    $target = [System.IO.Path]::GetFullPath($TargetPath)

    if (-not $base.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
        $base += [System.IO.Path]::DirectorySeparatorChar
    }

    $baseUri = New-Object System.Uri($base)
    $targetUri = New-Object System.Uri($target)
    $relativeUri = $baseUri.MakeRelativeUri($targetUri)
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()) -replace "/", "\\"
}

function ConvertTo-RelativePath {
    param([string]$Path)
    return ($Path -replace "\\\\", "/")
}

if (-not $TocPath) {
    $TocPath = Join-Path $Root "toc.yml"
}

if (-not $Flat) {
    $lines = @(
        "- name: $SectionName",
        "  href: $SectionHref"
    )
    $content = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
    Set-Content -Path $TocPath -Value $content -Encoding UTF8
    Write-Host "toc.yml updated with a single link."
    return
}

$docsPath = Join-Path $Root $DocsRoot
if (-not (Test-Path $docsPath)) {
    throw "Docs root not found: $docsPath"
}

$mdFiles = Get-ChildItem -Path $docsPath -Recurse -File -Filter "*.md" |
    Where-Object { $_.Name -ne "index.md" } |
    Sort-Object { (Get-RelativePath -BasePath $Root -TargetPath $_.FullName).ToLowerInvariant() }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("- name: $SectionName")
$lines.Add("  items:")

foreach ($file in $mdFiles) {
    $relative = ConvertTo-RelativePath (Get-RelativePath -BasePath $Root -TargetPath $file.FullName)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $title = ($base -replace "[-_]+", " ").Trim()
    if ([string]::IsNullOrWhiteSpace($title)) {
        continue
    }
    $lines.Add("    - name: $title Documentation")
    $lines.Add("      href: $relative")
}

$content = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
Set-Content -Path $TocPath -Value $content -Encoding UTF8

Write-Host "toc.yml updated with $($mdFiles.Count) markdown files."
