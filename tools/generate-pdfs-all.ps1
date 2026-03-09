param(
    [switch]$SkipPdf,
    [switch]$SkipBuild,
    [switch]$SkipInject
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptDir)) {
        return (Get-Location).Path
    }
    return $scriptDir
}

function ConvertTo-RelativePath {
    param([string]$Path)
    return ($Path -replace "\\", "/")
}

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
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()) -replace "/", "\"
}

function Get-RequiredCommand {
    param([string]$CommandName)
    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$CommandName' is not available in PATH."
    }
}

function Get-MarkdownFiles {
    param([string]$Root)

    return Get-ChildItem -Path $Root -Recurse -File -Filter "*.md" |
        Where-Object {
            $_.Name -ne "index.md" -and
            $_.FullName -notmatch "\\_site\\" -and
            $_.FullName -notmatch "\\obj\\" -and
            $_.FullName -notmatch "\\.git\\" -and
            $_.FullName -notmatch "\\pdf\\"
        }
}

function Get-AllSourceMarkdownFiles {
    param([string]$Root)

    return Get-ChildItem -Path $Root -Recurse -File -Filter "*.md" |
        Where-Object {
            $_.FullName -notmatch "\\_site\\" -and
            $_.FullName -notmatch "\\obj\\" -and
            $_.FullName -notmatch "\\.git\\" -and
            $_.FullName -notmatch "\\pdf\\"
        } |
        Sort-Object FullName
}

function Get-MarkdownContentHash {
    param([string]$Root)

    $mdFiles = Get-AllSourceMarkdownFiles -Root $Root
    $hashInput = New-Object System.Text.StringBuilder
    foreach ($file in $mdFiles) {
        $relativePath = Get-RelativePath -BasePath $Root -TargetPath $file.FullName
        $fileHash = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash
        [void]$hashInput.AppendLine("$relativePath|$fileHash")
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($hashInput.ToString())
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $result = $sha.ComputeHash($bytes)
    }
    finally {
        $sha.Dispose()
    }

    return ([System.BitConverter]::ToString($result)).Replace("-", "").ToLowerInvariant()
}

function Get-ReleaseInfo {
    param([string]$Root)

    $statePath = Join-Path $Root "tools\pdf-version-state.json"
    $currentHash = Get-MarkdownContentHash -Root $Root
    $baseVersion = "2.6.1"
    $versionToUse = $baseVersion
    $state = $null

    if (Test-Path $statePath) {
        $raw = Get-Content -Path $statePath -Raw -Encoding UTF8
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $state = $raw | ConvertFrom-Json
        }
    }

    if ($state -and $state.Version) {
        $versionToUse = [string]$state.Version
        if ($state.ContentHash -ne $currentHash) {
            $parts = $versionToUse.Split(".")
            if ($parts.Length -eq 3) {
                $major = [int]$parts[0]
                $minor = [int]$parts[1]
                $patch = [int]$parts[2] + 1
                $versionToUse = "$major.$minor.$patch"
            }
            else {
                $versionToUse = $baseVersion
            }
        }
    }

    $newState = [PSCustomObject]@{
        Version = $versionToUse
        ContentHash = $currentHash
        UpdatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    }
    $newState | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8

    return [PSCustomObject]@{
        Version = $versionToUse
        ReleaseDate = "March 2026"
    }
}

function Invoke-DocFxBuild {
    param([string]$Root)

    Get-RequiredCommand -CommandName "docfx"
    Write-Host "Building site with DocFX..."
    Push-Location $Root
    try {
        & docfx build
    }
    finally {
        Pop-Location
    }
}

function Get-BrowserExecutable {
    $candidates = @(
        $env:BROWSER_PDF_EXE,
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "No Chromium-based browser found. Set BROWSER_PDF_EXE to msedge.exe or chrome.exe."
}

function Start-StaticServer {
    param(
        [string]$SiteRoot,
        [int]$Port = 8765
    )

    Get-RequiredCommand -CommandName "python"

    $pythonArgs = @("-m", "http.server", $Port, "--bind", "127.0.0.1", "--directory", $SiteRoot)
    $startProcessParams = @{
        FilePath = "python"
        ArgumentList = $pythonArgs
        PassThru = $true
    }

    $isWindowsHost = ($PSVersionTable.PSEdition -eq "Desktop") -or ($env:OS -eq "Windows_NT")
    if ($isWindowsHost) {
        $startProcessParams.WindowStyle = "Hidden"
    }

    $process = Start-Process @startProcessParams

    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 250
        try {
            $response = Invoke-WebRequest -Uri ("http://127.0.0.1:{0}/index.html" -f $Port) -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                return @{ Process = $process; Port = $Port }
            }
        }
        catch {
        }
    }

    try {
        Stop-Process -Id $process.Id -Force
    }
    catch {
    }

    throw "Failed to start local static server for PDF rendering."
}

function Set-PdfOpenWithOutlinePane {
    param([string]$PdfPath)

    if (-not (Test-Path $PdfPath)) {
        return
    }

    $latin1 = [System.Text.Encoding]::GetEncoding(28591)
    $bytes = [System.IO.File]::ReadAllBytes($PdfPath)
    $text = $latin1.GetString($bytes)

    if ($text -match '/PageMode\s*/UseOutlines') {
        return
    }

    $updated = $text -replace '(/Type\s*/Catalog\b)', '$1 /PageMode /UseOutlines'
    if ($updated -ne $text) {
        [System.IO.File]::WriteAllBytes($PdfPath, $latin1.GetBytes($updated))
    }
}

function Install-PythonModuleIfMissing {
    param([string]$ModuleName)

    $check = "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('$ModuleName') else 1)"
    & python -c $check
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing python module: $ModuleName"
        & python -m pip install --quiet $ModuleName
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install required python module: $ModuleName"
        }
    }
}

function Add-PdfPageNumbers {
    param([string]$PdfPath)

    if (-not (Test-Path $PdfPath)) {
        return
    }

    $script = @'
import io
import sys
from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas

pdf_path = sys.argv[1]
reader = PdfReader(pdf_path)
writer = PdfWriter()
writer.clone_document_from_reader(reader)

for idx, page in enumerate(writer.pages):
    if idx > 0:
        width = float(page.mediabox.width)
        height = float(page.mediabox.height)
        packet = io.BytesIO()
        c = canvas.Canvas(packet, pagesize=(width, height))
        c.setFont("Helvetica", 10)
        c.drawCentredString(width / 2.0, 18, str(idx))
        c.save()
        packet.seek(0)
        overlay = PdfReader(packet).pages[0]
        page.merge_page(overlay)

with open(pdf_path, "wb") as f:
    writer.write(f)
'@

    $script | python - $PdfPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add page numbers to: $PdfPath"
    }
}

function Convert-HtmlToPdf {
    param(
        [string]$Root,
        [string]$SiteRoot,
        [System.IO.FileInfo[]]$MarkdownFiles,
        [pscustomobject]$ReleaseInfo
    )

    $browserExe = Get-BrowserExecutable
    Install-PythonModuleIfMissing -ModuleName "pypdf"
    Install-PythonModuleIfMissing -ModuleName "reportlab"

    $pdfRoot = Join-Path $SiteRoot "pdf"
    if (-not (Test-Path $pdfRoot)) {
        New-Item -ItemType Directory -Path $pdfRoot -Force | Out-Null
    }

    $server = Start-StaticServer -SiteRoot $SiteRoot
    try {
        foreach ($md in $MarkdownFiles) {
            $relativeMd = Get-RelativePath -BasePath $Root -TargetPath $md.FullName
            $relativeHtml = [System.IO.Path]::ChangeExtension($relativeMd, ".html")
            $relativePdf = [System.IO.Path]::ChangeExtension($relativeMd, ".pdf")
            $htmlPath = Join-Path $SiteRoot $relativeHtml

            if (-not (Test-Path $htmlPath)) {
                continue
            }

            $pdfOutputPath = Join-Path $pdfRoot $relativePdf
            $pdfOutputDir = Split-Path -Parent $pdfOutputPath
            if (-not (Test-Path $pdfOutputDir)) {
                New-Item -ItemType Directory -Path $pdfOutputDir -Force | Out-Null
            }

            $originalHtml = Get-Content -Path $htmlPath -Raw -Encoding UTF8
            $forcedLightScript = @"
<script>
  try { localStorage.setItem('theme', 'light'); } catch (e) {}
  document.documentElement.setAttribute('data-bs-theme', 'light');
</script>
"@
            $printStyle = @"
<style>
  @media print {
    @page { size: A4; margin: 16mm 12mm 18mm 12mm; }

    header,
    footer,
    .actionbar,
    #breadcrumb,
    .toc-offcanvas,
    .offcanvas-md,
    .offcanvas,
    .pdf-download {
      display: none !important;
      visibility: hidden !important;
    }

    main.container-xxl,
    .content,
    article {
      margin: 0 !important;
      padding: 0 !important;
      max-width: none !important;
      width: 100% !important;
    }

    .pdf-cover {
      height: 245mm;
      position: relative;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      text-align: center;
      page-break-after: always;
      break-after: page;
    }

    .pdf-cover-logo { width: 140px; height: auto; margin-bottom: 10px; }
    .pdf-cover h1 { margin: 0 0 12px; font-size: 30px; }
    .pdf-cover h2 { margin: 0 0 24px; font-size: 22px; font-weight: 600; }
    .pdf-cover .pdf-cover-meta { font-size: 13px; line-height: 1.8; }

    .pdf-cover-page-number-mask {
      position: absolute;
      left: 0;
      right: 0;
      bottom: -2mm;
      height: 18mm;
      background: #ffffff;
      z-index: 10;
    }

  }
</style>
"@
            $coverHtml = @"
<div class="pdf-cover">
  <img class="pdf-cover-logo" src="/images/logo.svg" alt="ICT logo" />
  <h1>ICT International</h1>
  <h2>Product Support Documentation</h2>
  <div class="pdf-cover-meta">
    <div><strong>Version:</strong> $($ReleaseInfo.Version)</div>
    <div><strong>Release Date:</strong> $($ReleaseInfo.ReleaseDate)</div>
  </div>
</div>
"@
            $tempHtml = $originalHtml -replace "(?i)<head>", ("<head>" + [Environment]::NewLine + $forcedLightScript + [Environment]::NewLine + $printStyle)
            $tempHtml = [System.Text.RegularExpressions.Regex]::Replace(
                $tempHtml,
                "(?is)(<article\b[^>]*>)",
                '$1' + [Environment]::NewLine + $coverHtml + [Environment]::NewLine + '<div class="pdf-content-start">',
                1
            )
            $tempHtml = $tempHtml -replace "(?i)</article>", ("</div>" + [Environment]::NewLine + "</article>")
            Set-Content -Path $htmlPath -Value $tempHtml -Encoding UTF8

            $urlPath = ConvertTo-RelativePath $relativeHtml
            $url = "http://127.0.0.1:$($server.Port)/$urlPath"
            Write-Host "Rendering browser PDF: $(ConvertTo-RelativePath $relativeHtml)"
            $chromeArgs = @(
                "--headless=new",
                "--disable-gpu",
                "--disable-dev-shm-usage",
                "--no-sandbox",
                "--no-first-run",
                "--no-default-browser-check",
                "--disable-background-networking",
                "--disable-component-update",
                "--disable-sync",
                "--run-all-compositor-stages-before-draw",
                "--virtual-time-budget=10000",
                "--print-to-pdf=$pdfOutputPath",
                "--print-to-pdf-no-header",
                "--no-pdf-header-footer",
                "--export-tagged-pdf",
                "--generate-pdf-document-outline",
                $url
            )

            try {
                & $browserExe @chromeArgs 2>$null | Out-Null
                $browserExitCode = $LASTEXITCODE
                if ($browserExitCode -ne 0 -or -not (Test-Path $pdfOutputPath)) {
                    # Retry with legacy headless flag for older/variant Chromium builds.
                    $fallbackArgs = @($chromeArgs)
                    $fallbackArgs[0] = "--headless"
                    & $browserExe @fallbackArgs 2>$null | Out-Null
                    $browserExitCode = $LASTEXITCODE
                }
                if ($browserExitCode -ne 0 -or -not (Test-Path $pdfOutputPath)) {
                    throw "PDF rendering failed for $relativeHtml"
                }
                Add-PdfPageNumbers -PdfPath $pdfOutputPath
                Set-PdfOpenWithOutlinePane -PdfPath $pdfOutputPath
            }
            finally {
                Set-Content -Path $htmlPath -Value $originalHtml -Encoding UTF8
            }
        }
    }
    finally {
        if ($server -and $server.Process) {
            try {
                Stop-Process -Id $server.Process.Id -Force
            }
            catch {
            }
        }
    }
}

function Add-PdfLinkToHtml {
    param(
        [string]$HtmlPath,
        [string]$RelativePdfPath
    )

    if (-not (Test-Path $HtmlPath)) {
        return
    }

    $htmlText = Get-Content -Path $HtmlPath -Raw -Encoding UTF8

    $iconSvg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' aria-hidden='true'><path fill='#fff' d='M6 2h9l5 5v13a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z'/><path fill='#d32f2f' d='M15 2v5h5zM4 14h16v6H4z'/><path fill='#fff' d='M6.4 18.5h.9c.7 0 1.1-.3 1.1-.9 0-.6-.4-.9-1.1-.9h-.9v1.8zm0 .8V21H5.3v-5h2.1c1.3 0 2.1.6 2.1 1.7S8.7 19.4 7.4 19.4h-1zm4.7.8h-1.8v-5h1.8c1.5 0 2.5.9 2.5 2.5s-1 2.5-2.5 2.5zm-.7-.9h.6c.8 0 1.4-.5 1.4-1.6s-.6-1.6-1.4-1.6h-.6zm4 .9h-1.1v-5h3.1v.9h-2v1.2h1.8v.9h-1.8z'/></svg>"
    $iconData = "data:image/svg+xml,{0}" -f [System.Uri]::EscapeDataString($iconSvg)
    $linkHtml = [Environment]::NewLine +
        "<p class=""pdf-download"" style=""margin:12px 0 20px;"">" +
        "<a class=""pdf-download-btn"" href=""$RelativePdfPath"" download style=""display:inline-flex;align-items:center;gap:10px;padding:8px 14px;border:1px solid #355c86;border-radius:6px;background:#4f79a8;color:#ffffff;text-decoration:none;font-weight:700;transition:background-color .2s ease,border-color .2s ease,color .2s ease;"" onmouseover=""this.style.background='#2f5e91';this.style.borderColor='#244d78';this.style.color='#ffffff';"" onmouseout=""this.style.background='#4f79a8';this.style.borderColor='#355c86';this.style.color='#ffffff';"">" +
        "<img src=""$iconData"" alt="""" width=""24"" height=""24"" style=""display:block;"" />" +
        "<span>Download PDF</span>" +
        "</a></p>" +
        [Environment]::NewLine

    $downloadBlockPattern = "(?is)<p\s+class=""pdf-download""[^>]*>.*?</p>"
    if ($htmlText -match $downloadBlockPattern) {
        $newHtml = [System.Text.RegularExpressions.Regex]::Replace($htmlText, $downloadBlockPattern, $linkHtml, 1)
        Set-Content -Path $HtmlPath -Value $newHtml -Encoding UTF8
        return
    }

    $h1Pattern = "(?is)(<h1\b[^>]*>.*?</h1>)"
    $h1Regex = New-Object System.Text.RegularExpressions.Regex($h1Pattern)
    if ($h1Regex.IsMatch($htmlText)) {
        $newHtml = $h1Regex.Replace($htmlText, '$1' + $linkHtml, 1)
        Set-Content -Path $HtmlPath -Value $newHtml -Encoding UTF8
        return
    }

    if ($htmlText -match "(?i)</body>") {
        $newHtml = [System.Text.RegularExpressions.Regex]::Replace(
            $htmlText,
            "(?i)</body>",
            [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $linkHtml + $m.Value },
            1
        )
        Set-Content -Path $HtmlPath -Value $newHtml -Encoding UTF8
    }
}

function Add-PdfLinksToHtml {
    param(
        [string]$Root,
        [string]$SiteRoot,
        [System.IO.FileInfo[]]$MarkdownFiles
    )

    foreach ($md in $MarkdownFiles) {
        $relativeMd = Get-RelativePath -BasePath $Root -TargetPath $md.FullName
        $relativeHtml = [System.IO.Path]::ChangeExtension($relativeMd, ".html")
        $relativePdf = [System.IO.Path]::ChangeExtension($relativeMd, ".pdf")

        $htmlPath = Join-Path $SiteRoot $relativeHtml
        $sitePdfPath = Join-Path (Join-Path $SiteRoot "pdf") $relativePdf

        if (-not (Test-Path $htmlPath)) {
            continue
        }

        $htmlDir = Split-Path -Parent $htmlPath
        $relativePdfForLink = (Get-RelativePath -BasePath $htmlDir -TargetPath $sitePdfPath) -replace "\\", "/"
        Add-PdfLinkToHtml -HtmlPath $htmlPath -RelativePdfPath $relativePdfForLink
        Write-Host "Inserted link in: $(ConvertTo-RelativePath $relativeHtml)"
    }
}

function Get-CombinedPdfFileName {
    param([string]$Root)

    $defaultName = "ICT Product Support Handbook.pdf"
    $docfxPath = Join-Path $Root "docfx.json"
    if (-not (Test-Path $docfxPath)) {
        return $defaultName
    }

    try {
        $docfx = Get-Content -Path $docfxPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $name = $docfx.build.globalMetadata.pdfFileName
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            return [string]$name
        }
    }
    catch {
    }

    return $defaultName
}

function New-CombinedPdf {
    param(
        [string]$Root,
        [string]$SiteRoot,
        [System.IO.FileInfo[]]$MarkdownFiles
    )

    Install-PythonModuleIfMissing -ModuleName "pypdf"

    $pdfRoot = Join-Path $SiteRoot "pdf"
    if (-not (Test-Path $pdfRoot)) {
        return
    }

    $combinedName = Get-CombinedPdfFileName -Root $Root
    $combinedPath = Join-Path $pdfRoot $combinedName

    $inputPdfs = New-Object System.Collections.Generic.List[string]
    foreach ($md in $MarkdownFiles) {
        $relativeMd = Get-RelativePath -BasePath $Root -TargetPath $md.FullName
        $relativePdf = [System.IO.Path]::ChangeExtension($relativeMd, ".pdf")
        $pdfPath = Join-Path $pdfRoot $relativePdf
        if (Test-Path $pdfPath) {
            [void]$inputPdfs.Add($pdfPath)
        }
    }

    if ($inputPdfs.Count -eq 0) {
        return
    }

    $listPath = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -Path $listPath -Value $inputPdfs -Encoding UTF8

        $script = @"
import os
import sys
from pypdf import PdfWriter

list_path = sys.argv[1]
out_path = sys.argv[2]

writer = PdfWriter()
with open(list_path, "r", encoding="utf-8") as f:
    for line in f:
        p = line.strip()
        if p and os.path.exists(p):
            try:
                writer.append(p, import_outline=True)
            except TypeError:
                writer.append(p)

with open(out_path, "wb") as out:
    writer.write(out)
"@
        $script | python - $listPath $combinedPath
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $combinedPath)) {
            throw "Failed to create combined PDF: $combinedPath"
        }

        Set-PdfOpenWithOutlinePane -PdfPath $combinedPath

        $targets = @(
            (Join-Path $SiteRoot $combinedName),
            (Join-Path (Join-Path $SiteRoot "Products") $combinedName)
        )

        foreach ($target in $targets) {
            Copy-Item -Path $combinedPath -Destination $target -Force
            Set-PdfOpenWithOutlinePane -PdfPath $target
        }

        Write-Host "Created combined PDF: $(ConvertTo-RelativePath (Get-RelativePath -BasePath $SiteRoot -TargetPath $combinedPath))"
    }
    finally {
        if (Test-Path $listPath) {
            Remove-Item -Path $listPath -Force
        }
    }
}
$repoRoot = Get-RepoRoot
$siteRoot = Join-Path $repoRoot "_site"
$markdownFiles = Get-MarkdownFiles -Root $repoRoot
$releaseInfo = Get-ReleaseInfo -Root $repoRoot

if (-not $SkipBuild) {
    Invoke-DocFxBuild -Root $repoRoot
}

if (-not $SkipPdf) {
    Convert-HtmlToPdf -Root $repoRoot -SiteRoot $siteRoot -MarkdownFiles $markdownFiles -ReleaseInfo $releaseInfo
    New-CombinedPdf -Root $repoRoot -SiteRoot $siteRoot -MarkdownFiles $markdownFiles
}

if (-not $SkipInject) {
    Add-PdfLinksToHtml -Root $repoRoot -SiteRoot $siteRoot -MarkdownFiles $markdownFiles
}

Write-Host "Done."














