@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0build-with-pdf.ps1" %*
