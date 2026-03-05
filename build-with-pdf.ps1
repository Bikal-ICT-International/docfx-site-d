$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "tools\generate-pdfs-all.ps1"
if (-not (Test-Path $scriptPath)) {
    throw "Pipeline script not found: $scriptPath"
}

& powershell -ExecutionPolicy Bypass -File $scriptPath @args
