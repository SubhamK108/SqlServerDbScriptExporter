#!/usr/bin/env pwsh
# Runs SQL Server DB Script Exporter (SqlServerDbScriptExporter.cs). All arguments are passed through, e.g.:
#   .\run.ps1                 (no arguments: asks for everything, remembering the last answers)
#   .\run.ps1 --help
#   .\run.ps1 -S localhost -d WheelLog -U myuser --trust-server-certificate -o ..\WheelLogWebApp\Database

$ErrorActionPreference = 'Stop'

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host 'The .NET 10 SDK (or newer) is required: https://dotnet.microsoft.com/download' -ForegroundColor Red
    exit 1
}

$major = [int](((dotnet --version) -split '\.')[0])
if ($major -lt 10) {
    Write-Host "The .NET 10 SDK (or newer) is required, found $(dotnet --version): https://dotnet.microsoft.com/download" -ForegroundColor Red
    exit 1
}

dotnet run (Join-Path $PSScriptRoot 'SqlServerDbScriptExporter.cs') -- @args
exit $LASTEXITCODE
