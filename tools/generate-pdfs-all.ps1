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

function Get-PdfVersionState {
    param([string]$Root)

    $statePath = Join-Path $Root "tools\pdf-version-state.json"
    $state = [PSCustomObject]@{
        Files = @{}
    }

    if (Test-Path $statePath) {
        try {
            $raw = Get-Content -Path $statePath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $parsed = $raw | ConvertFrom-Json
                if ($parsed -and $parsed.Files) {
                    $files = @{}
                    foreach ($prop in $parsed.Files.PSObject.Properties) {
                        $files[$prop.Name] = $prop.Value
                    }
                    $state.Files = $files
                }
            }
        }
        catch {
        }
    }

    return $state
}

function Get-NextPatchVersion {
    param(
        [string]$Version,
        [string]$FallbackVersion
    )

    $parts = $Version.Split(".")
    if ($parts.Length -eq 3 -and ($parts | Where-Object { $_ -match '^\d+$' }).Count -eq 3) {
        $major = [int]$parts[0]
        $minor = [int]$parts[1]
        $patch = [int]$parts[2] + 1
        return "$major.$minor.$patch"
    }

    return $FallbackVersion
}

function Update-PdfVersionStateForFile {
    param(
        [pscustomobject]$State,
        [string]$RelativePath,
        [string]$FileHash,
        [string]$BaseVersion,
        [string]$ReleaseDate
    )

    $files = $State.Files
    $entry = $null
    if ($files.ContainsKey($RelativePath)) {
        $entry = $files[$RelativePath]
    }

    $versionToUse = $BaseVersion
    if ($entry -and $entry.Version) {
        $versionToUse = [string]$entry.Version
    }

    if (-not $entry) {
        $versionToUse = $BaseVersion
    }
    elseif ($entry.ContentHash -ne $FileHash) {
        $versionToUse = Get-NextPatchVersion -Version $versionToUse -FallbackVersion $BaseVersion
    }

    $files[$RelativePath] = [PSCustomObject]@{
        Version = $versionToUse
        ContentHash = $FileHash
        UpdatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    }

    return [PSCustomObject]@{
        Version = $versionToUse
        ReleaseDate = $ReleaseDate
    }
}

function Save-PdfVersionState {
    param(
        [string]$Root,
        [pscustomobject]$State
    )

    $statePath = Join-Path $Root "tools\pdf-version-state.json"
    $stateOut = [PSCustomObject]@{
        Files = [PSCustomObject]$State.Files
        UpdatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    }
    $stateOut | ConvertTo-Json -Depth 6 | Set-Content -Path $statePath -Encoding UTF8
}
function Save-PdfVersionReport {
    param(
        [string]$Root,
        [string]$ReleaseDate,
        [System.Collections.IEnumerable]$Changes
    )

    $reportPath = Join-Path $Root "tools\pdf-version-report.json"
    $run = [PSCustomObject]@{
        RunAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        ReleaseDate = $ReleaseDate
        ChangedCount = @($Changes).Count
        Changes = @($Changes)
    }

    $report = [PSCustomObject]@{
        Runs = @($run)
    }

    if (Test-Path $reportPath) {
        try {
            $raw = Get-Content -Path $reportPath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $existing = $raw | ConvertFrom-Json
                if ($existing -and $existing.Runs) {
                    $runs = @()
                    foreach ($item in $existing.Runs) {
                        $runs += $item
                    }
                    $runs += $run
                    $report = [PSCustomObject]@{ Runs = $runs }
                }
            }
        }
        catch {
        }
    }

    $report | ConvertTo-Json -Depth 6 | Set-Content -Path $reportPath -Encoding UTF8
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

function Invoke-BrowserWithTimeout {
    param(
        [string]$BrowserExe,
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 120
    )

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()

    try {
        $proc = Start-Process -FilePath $BrowserExe -ArgumentList $Arguments -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $timedOut = $false

        try {
            Wait-Process -Id $proc.Id -Timeout $TimeoutSeconds -ErrorAction Stop
        }
        catch {
            $timedOut = $true
        }

        if ($timedOut) {
            try { Stop-Process -Id $proc.Id -Force } catch {}
            return [PSCustomObject]@{ ExitCode = -1; TimedOut = $true }
        }

        return [PSCustomObject]@{ ExitCode = $proc.ExitCode; TimedOut = $false }
    }
    finally {
        if (Test-Path $stdoutPath) { Remove-Item -Path $stdoutPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $stderrPath) { Remove-Item -Path $stderrPath -Force -ErrorAction SilentlyContinue }
    }
}
function Get-UsePlaywright {
    $value = $env:USE_PLAYWRIGHT
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $false
    }

    $value = $value.ToLowerInvariant()
    return ($value -eq "1" -or $value -eq "true" -or $value -eq "yes")
}

function Ensure-PlaywrightAvailable {
    $check = "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('playwright') else 1)"
    & python -c $check
    if ($LASTEXITCODE -ne 0) {
        throw "Playwright is not installed. Install with: python -m pip install playwright; python -m playwright install chromium"
    }
}

function Invoke-PlaywrightPdf {
    param(
        [string]$Url,
        [string]$PdfPath,
        [int]$TimeoutSeconds = 180
    )

    Ensure-PlaywrightAvailable

    $script = @"
import sys
from playwright.sync_api import sync_playwright
url = sys.argv[1]
out_path = sys.argv[2]
timeout_ms = int(sys.argv[3]) * 1000
with sync_playwright() as p:
    browser = p.chromium.launch(args=["--disable-dev-shm-usage"])
    page = browser.new_page()
    page.set_default_timeout(timeout_ms)
    page.goto(url, wait_until="load", timeout=timeout_ms)
    try:
        page.wait_for_load_state("networkidle", timeout=5000)
    except Exception:
        pass
    page.pdf(path=out_path, print_background=True, prefer_css_page_size=True)
    browser.close()
"@

    $output = $script | python - $Url $PdfPath $TimeoutSeconds 2>&1
    if ($LASTEXITCODE -ne 0) {
        $msg = ($output -join " ").Trim()
        if ([string]::IsNullOrWhiteSpace($msg)) {
            $msg = "No error output from Playwright."
        }
        throw ("Playwright PDF rendering failed for {0}. {1}" -f $Url, $msg)
    }
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
import warnings
import logging
from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas

# Suppress warnings
logging.disable(logging.CRITICAL)
warnings.filterwarnings("ignore")

pdf_path = sys.argv[1]

try:
    reader = PdfReader(pdf_path)
    writer = PdfWriter()
    
    # Preserve the outline/bookmarks from the original
    outline = reader.outline if hasattr(reader, 'outline') else None
    
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

    # Re-add outline if it existed
    if outline:
        try:
            writer.outline = outline
        except Exception:
            pass

    with open(pdf_path, "wb") as f:
        writer.write(f)
except Exception:
    pass
'@

    $script | python - $PdfPath 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add page numbers to: $PdfPath"
    }
}

function Convert-HtmlToPdf {
    param(
        [string]$Root,
        [string]$SiteRoot,
        [System.IO.FileInfo[]]$MarkdownFiles
    )

    $baseVersion = "2.6.1"
    $releaseDate = "March 2026"
    $versionState = Get-PdfVersionState -Root $Root

    $reportChanges = New-Object System.Collections.Generic.List[object]
    $usePlaywright = Get-UsePlaywright
    if (-not $usePlaywright) {
        $browserExe = Get-BrowserExecutable
    }
    Install-PythonModuleIfMissing -ModuleName "pypdf"
    Install-PythonModuleIfMissing -ModuleName "reportlab"

    $pdfRoot = Join-Path $SiteRoot "pdf"
    if (-not (Test-Path $pdfRoot)) {
        New-Item -ItemType Directory -Path $pdfRoot -Force | Out-Null
    }

    $failedPdfPages = New-Object System.Collections.Generic.List[string]
    $server = Start-StaticServer -SiteRoot $SiteRoot
    try {
        foreach ($md in $MarkdownFiles) {
            $relativeMd = Get-RelativePath -BasePath $Root -TargetPath $md.FullName
            $existingEntry = $null
            if ($versionState.Files.ContainsKey($relativeMd)) {
                $existingEntry = $versionState.Files[$relativeMd]
            }
            $oldVersion = $null
            $oldHash = $null
            if ($existingEntry) {
                $oldVersion = $existingEntry.Version
                $oldHash = $existingEntry.ContentHash
            }
            $fileHash = (Get-FileHash -Algorithm SHA256 -Path $md.FullName).Hash
            $releaseInfo = Update-PdfVersionStateForFile -State $versionState -RelativePath $relativeMd -FileHash $fileHash -BaseVersion $baseVersion -ReleaseDate $releaseDate
            if (-not $existingEntry -or $oldHash -ne $fileHash) {
                $status = if ($existingEntry) { "updated" } else { "new" }
                [void]$reportChanges.Add([PSCustomObject]@{
                    Path = $relativeMd
                    Status = $status
                    OldVersion = $oldVersion
                    NewVersion = $releaseInfo.Version
                    OldHash = $oldHash
                    NewHash = $fileHash
                })
            }
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
  <img class="pdf-cover-logo" src="/images/ICT logo.png" alt="ICT logo" />
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

            if ($usePlaywright) {
                try {
                    Invoke-PlaywrightPdf -Url $url -PdfPath $pdfOutputPath -TimeoutSeconds 180
                    Add-PdfPageNumbers -PdfPath $pdfOutputPath
                    Set-PdfOpenWithOutlinePane -PdfPath $pdfOutputPath
                }
                catch {
                    [void]$failedPdfPages.Add("${relativeHtml} :: $($_.Exception.Message)")
                    Write-Warning "Skipping PDF for ${relativeHtml}: $($_.Exception.Message)"
                }
                finally {
                    Set-Content -Path $htmlPath -Value $originalHtml -Encoding UTF8
                }
                continue
            }

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
                "--disable-blink-features=AutomationControlled",
                "--disable-extensions",
                "--disable-plugins",
                "--disable-images",
                "--print-to-pdf=$pdfOutputPath",
                "--print-to-pdf-no-header",
                "--no-pdf-header-footer",
                "--generate-pdf-document-outline",
                $url
            )

            try {
                $renderResult = Invoke-BrowserWithTimeout -BrowserExe $browserExe -Arguments $chromeArgs -TimeoutSeconds 180
                $browserExitCode = $renderResult.ExitCode
                $pdfReady = (Test-Path $pdfOutputPath) -and ((Get-Item $pdfOutputPath).Length -gt 0)

                if (-not $pdfReady) {
                    $fallbackArgs = @($chromeArgs)
                    $fallbackArgs[0] = "--headless"
                    $renderResult = Invoke-BrowserWithTimeout -BrowserExe $browserExe -Arguments $fallbackArgs -TimeoutSeconds 180
                    $browserExitCode = $renderResult.ExitCode
                    $pdfReady = (Test-Path $pdfOutputPath) -and ((Get-Item $pdfOutputPath).Length -gt 0)
                }

                if (-not $pdfReady) {
                    $reason = if ($renderResult.TimedOut) { "timeout" } else { "exit code $browserExitCode" }
                    throw "PDF rendering failed for $relativeHtml ($reason)"
                }

                Add-PdfPageNumbers -PdfPath $pdfOutputPath
                Set-PdfOpenWithOutlinePane -PdfPath $pdfOutputPath
            }
            catch {
                [void]$failedPdfPages.Add("${relativeHtml} :: $($_.Exception.Message)")
                Write-Warning "Skipping PDF for ${relativeHtml}: $($_.Exception.Message)"
            }
            finally {
                Set-Content -Path $htmlPath -Value $originalHtml -Encoding UTF8
            }
        }

        if ($failedPdfPages.Count -gt 0) {
            Write-Warning "PDF generation skipped for $($failedPdfPages.Count) page(s)."
            foreach ($item in $failedPdfPages) {
                Write-Warning $item
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
    Save-PdfVersionState -Root $Root -State $versionState

    Save-PdfVersionReport -Root $Root -ReleaseDate $releaseDate -Changes $reportChanges
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

function Remove-PdfLinkFromHtml {
    param([string]$HtmlPath)

    if (-not (Test-Path $HtmlPath)) {
        return
    }

    $htmlText = Get-Content -Path $HtmlPath -Raw -Encoding UTF8
    $downloadBlockPattern = "(?is)<p\s+class=""pdf-download""[^>]*>.*?</p>"
    if ($htmlText -match $downloadBlockPattern) {
        $newHtml = [System.Text.RegularExpressions.Regex]::Replace($htmlText, $downloadBlockPattern, "", 1)
        Set-Content -Path $HtmlPath -Value $newHtml -Encoding UTF8
    }
}
function Add-SecurityMetaToHtml {
    param([string]$SiteRoot)

    if (-not (Test-Path $SiteRoot)) {
        return
    }

    $csp = "default-src 'self'; base-uri 'self'; object-src 'none'; form-action 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; upgrade-insecure-requests"
    $referrer = "strict-origin-when-cross-origin"

    $metaCsp = '<meta http-equiv="Content-Security-Policy" content="{0}">' -f $csp
    $metaRef = '<meta http-equiv="Referrer-Policy" content="{0}">' -f $referrer

    $htmlFiles = Get-ChildItem -Path $SiteRoot -Recurse -File -Filter "*.html" |
        Where-Object { $_.FullName -notmatch '[\\/](public|pdf)[\\/]' }

    foreach ($file in $htmlFiles) {
        $html = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($html)) {
            continue
        }

        $html = [System.Text.RegularExpressions.Regex]::Replace($html, "(?is)<meta[^>]+http-equiv=[`"']Content-Security-Policy[`"'][^>]*>\s*", '')
        $html = [System.Text.RegularExpressions.Regex]::Replace($html, "(?is)<meta[^>]+http-equiv=[`"']Referrer-Policy[`"'][^>]*>\s*", '')
        $html = [System.Text.RegularExpressions.Regex]::Replace($html, "(?is)<meta[^>]+name=[`"']referrer[`"'][^>]*>\s*", '')

        if ($html -match '(?i)<head>') {
            $inject = "<head>" + [Environment]::NewLine + "    " + $metaCsp + [Environment]::NewLine + "    " + $metaRef
            $html = [System.Text.RegularExpressions.Regex]::Replace($html, '(?i)<head>', $inject, 1)
            Set-Content -Path $file.FullName -Value $html -Encoding UTF8
        }
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
import warnings
import logging
from pypdf import PdfWriter

# Suppress all logging and warnings
logging.disable(logging.CRITICAL)
warnings.filterwarnings("ignore")

list_path = sys.argv[1]
out_path = sys.argv[2]

try:
    writer = PdfWriter()
    with open(list_path, "r", encoding="utf-8") as f:
        for line in f:
            p = line.strip()
            if p and os.path.exists(p):
                try:
                    writer.append(p, import_outline=True)
                except Exception:
                    try:
                        writer.append(p, import_outline=False)
                    except Exception:
                        pass

    # Add outline/bookmarks support to output
    writer.add_outline_item("Table of Contents", 0)
    
    with open(out_path, "wb") as out:
        writer.write(out)
except Exception:
    pass
"@
        $script | python - $listPath $combinedPath 2>$null
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

$updateTocScript = Join-Path $repoRoot "tools\update-toc.ps1"
if (Test-Path $updateTocScript) {
    Write-Host "Updating toc.yml from markdown files..."
    & $updateTocScript -Root $repoRoot
}

$markdownFiles = Get-MarkdownFiles -Root $repoRoot

if (-not $SkipBuild) {
    Invoke-DocFxBuild -Root $repoRoot
}

if (-not $SkipPdf) {
    Convert-HtmlToPdf -Root $repoRoot -SiteRoot $siteRoot -MarkdownFiles $markdownFiles
    New-CombinedPdf -Root $repoRoot -SiteRoot $siteRoot -MarkdownFiles $markdownFiles
}

if (-not $SkipInject) {
    Add-PdfLinksToHtml -Root $repoRoot -SiteRoot $siteRoot -MarkdownFiles $markdownFiles
}

Add-SecurityMetaToHtml -SiteRoot $siteRoot

Write-Host "Done."


















