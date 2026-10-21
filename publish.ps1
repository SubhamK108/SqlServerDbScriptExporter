#!/usr/bin/env pwsh
# Publishes SQL Server DB Script Exporter (SqlServerDbScriptExporter.cs) as an app. Same options as publish.sh:
#   .\publish.ps1                       one file for this OS that runs without .NET installed, into publish\<runtime>
#   .\publish.ps1 --no-self-contained   a smaller file that needs the .NET 10 runtime
#   .\publish.ps1 -r linux-x64 --compress -o C:\Tools\Exporter
#   .\publish.ps1 --help
# Native AOT is not an option: SMO does not support it.

$ErrorActionPreference = 'Stop'

function Show-Usage {
    @'
Publishes SQL Server DB Script Exporter as an app.

Usage: publish.ps1 | publish.sh [options]

  -r, --runtime <rid>         Target platform, e.g. win-x64, win-arm64, linux-x64, linux-arm64, osx-x64,
                              osx-arm64 (default: this machine's)
      --no-self-contained     Leave out the .NET runtime: about 20 MB instead of about 90 MB (40 MB with
                              --compress), but the .NET 10 runtime must be installed to run it
      --no-single-file        A folder of files instead of one executable
      --compress              Compress the single file (smaller, starts a bit slower);
                              not with --no-self-contained or --no-single-file
      --symbols               Also write the .pdb (debug symbols: line numbers in stack traces);
                              not needed to run the app
      --app-version <version> The version stamped into the app (shown by --version), e.g. 1.2.0 or
                              1.3.0-beta.1 (default: 0.0.0-dev)
  -c, --configuration <name>  Build configuration (default: Release)
  -o, --output <folder>       Where to put the app (default: publish/<rid> next to this script)
  -h, --help                  Show this help

The app keeps its settings (SqlServerDbScriptExporter.settings.json) next to the executable.
'@
}

$runtime = [System.Runtime.InteropServices.RuntimeInformation]::RuntimeIdentifier
if (-not $runtime) {
    # Windows PowerShell 5.1 runs on .NET Framework, which has no RuntimeIdentifier (and only runs on Windows).
    $runtime = 'win-' + [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
}
$selfContained = $true
$singleFile = $true
$compress = $false
$symbols = $false
$appVersion = ''
$configuration = 'Release'
$output = ''

for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    $needsValue = $arg -in '-r', '--runtime', '--app-version', '-c', '--configuration', '-o', '--output'
    if ($needsValue -and ($i + 1 -ge $args.Count -or ([string]$args[$i + 1]).StartsWith('-'))) {
        Write-Host "error: $arg needs a value." -ForegroundColor Red
        exit 2
    }

    switch ($arg) {
        { $_ -in '-r', '--runtime' } { $runtime = [string]$args[++$i] }
        '--no-self-contained' { $selfContained = $false }
        '--no-single-file' { $singleFile = $false }
        '--compress' { $compress = $true }
        '--symbols' { $symbols = $true }
        '--app-version' { $appVersion = [string]$args[++$i] }
        { $_ -in '-c', '--configuration' } { $configuration = [string]$args[++$i] }
        { $_ -in '-o', '--output' } { $output = [string]$args[++$i] }
        { $_ -in '-h', '--help' } { Show-Usage; exit 0 }
        default {
            Write-Host "error: unknown option '$arg'. Run with --help for usage." -ForegroundColor Red
            exit 2
        }
    }
}

if ($compress -and (-not $selfContained -or -not $singleFile)) {
    Write-Host 'error: --compress cannot be used with --no-self-contained or --no-single-file.' -ForegroundColor Red
    exit 2
}

# major.minor.patch, optionally with a pre-release part (1.3.0-beta.1).
if ($appVersion -and $appVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$') {
    Write-Host "error: --app-version '$appVersion' is not a version like 1.2.0 or 1.3.0-beta.1." -ForegroundColor Red
    exit 2
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host 'The .NET 10 SDK (or newer) is required: https://dotnet.microsoft.com/download' -ForegroundColor Red
    exit 1
}

$major = [int](((dotnet --version) -split '\.')[0])
if ($major -lt 10) {
    Write-Host "The .NET 10 SDK (or newer) is required, found $(dotnet --version): https://dotnet.microsoft.com/download" -ForegroundColor Red
    exit 1
}

if ($output -eq '') {
    $output = Join-Path $PSScriptRoot "publish/$runtime"
}

$publishArgs = @(
    'publish', (Join-Path $PSScriptRoot 'SqlServerDbScriptExporter.cs'),
    '-c', $configuration,
    '-r', $runtime,
    '--self-contained', $selfContained.ToString().ToLowerInvariant(),
    "-p:PublishSingleFile=$($singleFile.ToString().ToLowerInvariant())",
    '-o', $output
)
if ($singleFile) {
    # SqlClient's native parts go inside the single file too.
    $publishArgs += '-p:IncludeNativeLibrariesForSelfExtract=true'
}

if ($compress) {
    $publishArgs += '-p:EnableCompressionInSingleFile=true'
}

if (-not $symbols) {
    # No .pdb: it is only for debugging.
    $publishArgs += '-p:DebugType=none'
}

if ($appVersion) {
    $publishArgs += "-p:Version=$appVersion"
}

$kind = if ($selfContained) { 'self-contained' } else { 'needs the .NET 10 runtime' }
$shape = if ($singleFile) { 'single file' } else { 'folder' }
$versionText = if ($appVersion) { $appVersion } else { '0.0.0-dev' }
Write-Host "Publishing $versionText for $runtime ($shape, $kind, $configuration) into $output ..."
& dotnet @publishArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host "Done: $output" -ForegroundColor Green
exit 0