#!/bin/sh
# Runs SQL Server DB Script Exporter (SqlServerDbScriptExporter.cs; works from bash, zsh and sh). All arguments
# are passed through, e.g.:
#   ./run.sh                  (no arguments: asks for everything, remembering the last answers)
#   ./run.sh --help
#   ./run.sh -S localhost -d MyDb -U mylogin --trust-server-certificate -o ./Database
# If it is not executable yet: chmod +x run.sh (or run it as: sh run.sh ...)

set -eu

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
exec dotnet run "$script_dir/SqlServerDbScriptExporter.cs" -- "$@"
