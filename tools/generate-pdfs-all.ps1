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

function Normalize-RelativePath {
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

function Ensure-Command {
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

function Invoke-DocFxBuild {
    param([string]$Root)

    Ensure-Command -CommandName "docfx"
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

    Ensure-Command -CommandName "python"

    $pythonArgs = @("-m", "http.server", $Port, "--bind", "127.0.0.1", "--directory", $SiteRoot)
    $process = Start-Process -FilePath "python" -ArgumentList $pythonArgs -PassThru -WindowStyle Hidden

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

function Convert-HtmlToPdf {
    param(
        [string]$Root,
        [string]$SiteRoot,
        [System.IO.FileInfo[]]$MarkdownFiles
    )

    $browserExe = Get-BrowserExecutable
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

            $originalHtml = Get-Content -Path $htmlPath -Raw
            $forcedLightScript = @"
<script>
  try { localStorage.setItem('theme', 'light'); } catch (e) {}
  document.documentElement.setAttribute('data-bs-theme', 'light');
</script>
"@
            $tempHtml = $originalHtml -replace "(?i)<head>", ("<head>" + [Environment]::NewLine + $forcedLightScript)
            Set-Content -Path $htmlPath -Value $tempHtml -Encoding UTF8

            $urlPath = Normalize-RelativePath $relativeHtml
            $url = "http://127.0.0.1:$($server.Port)/$urlPath"
            Write-Host "Rendering browser PDF: $(Normalize-RelativePath $relativeHtml)"

            $chromeArgs = @(
                "--headless",
                "--disable-gpu",
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
                & $browserExe @chromeArgs | Out-Null
                if (-not (Test-Path $pdfOutputPath)) {
                    throw "PDF rendering failed for $relativeHtml"
                }
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

function Set-PdfOpenWithOutlinePane {
    param([string]$PdfPath)

    if (-not (Test-Path $PdfPath)) {
        return
    }

    # Chromium generates readable catalog dictionaries in these PDFs.
    # Inject PageMode so supporting viewers open with the bookmarks pane.
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

function Insert-PdfLink {
    param(
        [string]$HtmlPath,
        [string]$RelativePdfPath
    )

    if (-not (Test-Path $HtmlPath)) {
        return
    }

    $htmlText = Get-Content -Path $HtmlPath -Raw

    $iconSvg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16' aria-hidden='true'><path fill='#1f2937' d='M6 2h9l5 5v13a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z'/><path fill='#d32f2f' d='M15 2v5h5zM4 14h16v6H4z'/><path fill='#fff' d='M6.4 18.5h.9c.7 0 1.1-.3 1.1-.9 0-.6-.4-.9-1.1-.9h-.9v1.8zm0 .8V21H5.3v-5h2.1c1.3 0 2.1.6 2.1 1.7S8.7 19.4 7.4 19.4h-1zm4.7.8h-1.8v-5h1.8c1.5 0 2.5.9 2.5 2.5s-1 2.5-2.5 2.5zm-.7-.9h.6c.8 0 1.4-.5 1.4-1.6s-.6-1.6-1.4-1.6h-.6zm4 .9h-1.1v-5h3.1v.9h-2v1.2h1.8v.9h-1.8z'/></svg>"
    $iconData = "data:image/svg+xml,{0}" -f [System.Uri]::EscapeDataString($iconSvg)
    $linkHtml = [Environment]::NewLine +
        "<p class=""pdf-download"" style=""margin:12px 0 20px;"">" +
        "<a class=""pdf-download-btn"" href=""$RelativePdfPath"" download style=""display:inline-flex;align-items:center;gap:8px;padding:8px 14px;border:1px solid #c7cdd4;border-radius:6px;background:#e5e7eb;color:#1f2937;text-decoration:none;font-weight:600;"">" +
        "<img src=""$iconData"" alt="""" width=""16"" height=""16"" style=""display:block;"" />" +
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

function Inject-PdfLinks {
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
        Insert-PdfLink -HtmlPath $htmlPath -RelativePdfPath $relativePdfForLink
        Write-Host "Inserted link in: $(Normalize-RelativePath $relativeHtml)"
    }
}

$repoRoot = Get-RepoRoot
$siteRoot = Join-Path $repoRoot "_site"
$markdownFiles = Get-MarkdownFiles -Root $repoRoot

if (-not $SkipBuild) {
    Invoke-DocFxBuild -Root $repoRoot
}

if (-not $SkipPdf) {
    Convert-HtmlToPdf -Root $repoRoot -SiteRoot $siteRoot -MarkdownFiles $markdownFiles
}

if (-not $SkipInject) {
    Inject-PdfLinks -Root $repoRoot -SiteRoot $siteRoot -MarkdownFiles $markdownFiles
}

Write-Host "Done."
