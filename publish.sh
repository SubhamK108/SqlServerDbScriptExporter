#!/bin/sh
# Publishes SQL Server DB Script Exporter (SqlServerDbScriptExporter.cs) as an app (works from bash, zsh and sh).
# Same options as publish.ps1:
#   ./publish.sh                        one file for this OS that runs without .NET installed, into publish/<runtime>
#   ./publish.sh --no-self-contained    a smaller file that needs the .NET 10 runtime
#   ./publish.sh -r linux-x64 --compress -o ~/tools/exporter
#   ./publish.sh --help
# Native AOT is not an option: SMO does not support it.
# If it is not executable yet: chmod +x publish.sh (or run it as: sh publish.sh ...)

set -eu

usage() {
    cat <<'EOF'
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
EOF
}

# This machine's runtime identifier, e.g. linux-x64 or osx-arm64 (win-* under Git Bash / MSYS / Cygwin). A system
# it does not know stops with an error rather than a guess that would build an app that cannot run here.
detect_runtime() {
    case "$(uname -s)" in
        Darwin) os=osx ;;
        Linux) os=linux ;;
        MINGW* | MSYS* | CYGWIN*) os=win ;;
        *)
            echo "error: unknown system '$(uname -s)'; give the target platform with -r (see --help)." >&2
            return 1
            ;;
    esac
    case "$(uname -m)" in
        x86_64 | amd64) arch=x64 ;;
        arm64 | aarch64) arch=arm64 ;;
        armv7* | armv6*) arch=arm ;;
        *)
            echo "error: unknown architecture '$(uname -m)'; give the target platform with -r (see --help)." >&2
            return 1
            ;;
    esac
    echo "$os-$arch"
}

# Detected after the options, so -r also works on a machine detect_runtime does not know.
runtime=""
self_contained=true
single_file=true
compress=false
symbols=false
app_version=""
configuration=Release
output=""

while [ $# -gt 0 ]; do
    case "$1" in
        -r | --runtime | --app-version | -c | --configuration | -o | --output)
            if [ $# -lt 2 ] || [ "${2#-}" != "$2" ]; then
                echo "error: $1 needs a value." >&2
                exit 2
            fi
            ;;
    esac

    case "$1" in
        -r | --runtime) runtime="$2"; shift ;;
        --no-self-contained) self_contained=false ;;
        --no-single-file) single_file=false ;;
        --compress) compress=true ;;
        --symbols) symbols=true ;;
        --app-version) app_version="$2"; shift ;;
        -c | --configuration) configuration="$2"; shift ;;
        -o | --output) output="$2"; shift ;;
        -h | --help) usage; exit 0 ;;
        *)
            echo "error: unknown option '$1'. Run with --help for usage." >&2
            exit 2
            ;;
    esac
    shift
done

if [ -z "$runtime" ]; then
    runtime="$(detect_runtime)" || exit 2
fi

if [ "$compress" = true ] && { [ "$self_contained" = false ] || [ "$single_file" = false ]; }; then
    echo "error: --compress cannot be used with --no-self-contained or --no-single-file." >&2
    exit 2
fi

# major.minor.patch, optionally with a pre-release part (1.3.0-beta.1).
if [ -n "$app_version" ] && ! printf '%s' "$app_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'; then
    echo "error: --app-version '$app_version' is not a version like 1.2.0 or 1.3.0-beta.1." >&2
    exit 2
fi

if ! command -v dotnet >/dev/null 2>&1; then
    echo "The .NET 10 SDK (or newer) is required: https://dotnet.microsoft.com/download" >&2
    exit 1
fi

version="$(dotnet --version)"
if [ "${version%%.*}" -lt 10 ]; then
    echo "The .NET 10 SDK (or newer) is required, found $version: https://dotnet.microsoft.com/download" >&2
    exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$output" ]; then
    output="$script_dir/publish/$runtime"
fi

set -- publish "$script_dir/SqlServerDbScriptExporter.cs" \
    -c "$configuration" \
    -r "$runtime" \
    --self-contained "$self_contained" \
    "-p:PublishSingleFile=$single_file" \
    -o "$output"
if [ "$single_file" = true ]; then
    # SqlClient's native parts go inside the single file too.
    set -- "$@" -p:IncludeNativeLibrariesForSelfExtract=true
fi

if [ "$compress" = true ]; then
    set -- "$@" -p:EnableCompressionInSingleFile=true
fi

if [ "$symbols" = false ]; then
    # No .pdb: it is only for debugging.
    set -- "$@" -p:DebugType=none
fi

if [ -n "$app_version" ]; then
    set -- "$@" "-p:Version=$app_version"
fi

if [ "$self_contained" = true ]; then kind="self-contained"; else kind="needs the .NET 10 runtime"; fi
if [ "$single_file" = true ]; then shape="single file"; else shape="folder"; fi
echo "Publishing ${app_version:-0.0.0-dev} for $runtime ($shape, $kind, $configuration) into $output ..."
dotnet "$@"

echo
echo "Done: $output"