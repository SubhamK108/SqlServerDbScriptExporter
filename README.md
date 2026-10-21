# SQL Server DB Script Exporter

Script the schema and/or data of a SQL Server or Azure SQL database into `.sql` files — one file per object
in a folder per type, ready to keep in git, or everything in a single file that builds the database from scratch.

It asks for everything when started without arguments and remembers your answers, or runs unattended with
command-line options. Re-running it only rewrites the files whose objects actually changed, so your git diffs
show real changes, not noise.

## Features

- **One file per object** (`Table/`, `SP/`, `UDF/`, `UDT/`, `Views/`, plus a folder for table data), UTF-16 LE
  with CRLF line endings — or **a single file** in an order that runs on an empty database.
- **Schema, data or both**, for the entire database or for objects you pick (per type, from a list).
- **Clean diffs:** a file is only rewritten when its content changed. The `Script Date` in the headers is
  ignored, and so is the row order of data (SQL Server does not guarantee one).
- **Tables with everything:** keys, constraints, defaults, all index types (clustered, nonclustered, XML,
  spatial, columnstore, full-text), triggers and extended properties.
- **Procedures, functions and views** as `CREATE` or `CREATE OR ALTER`, with the name always written as
  `[schema].[name]`.
- **Leftovers:** files of objects that no longer exist are listed, and deleted on request. Hand-written files in
  the same folders are never touched.
- **Big databases:** output is written straight to disk instead of being held in memory (also for a single file
  of hundreds of MB), queries have no time limit, and a progress bar per step shows what is happening.
- **Runs anywhere:** Windows, macOS and Linux, x64 and ARM — a single executable, no .NET needed.

## Download

Get the file for your system from the [releases](https://github.com/SubhamK108/SqlServerDbScriptExporter/releases):

| System | Download |
|---|---|
| Windows (x64 / ARM64) | `SqlServerDbScriptExporter-<version>-win-x64.zip` / `-win-arm64.zip` |
| macOS (Apple Silicon / Intel) | `SqlServerDbScriptExporter-<version>-osx-arm64.tar.gz` / `-osx-x64.tar.gz` |
| Linux (x64 / ARM64 / ARM 32-bit) | `SqlServerDbScriptExporter-<version>-linux-x64.tar.gz` / `-linux-arm64.tar.gz` / `-linux-arm.tar.gz` |

Unpack it and run `SqlServerDbScriptExporter` (`.exe` on Windows). Each download is self-contained: nothing else to
install. Each release also has a `SHA256SUMS.txt` to check the downloads.

> **macOS:** the app is not notarized. If macOS refuses to open it, run
> `xattr -d com.apple.quarantine SqlServerDbScriptExporter` once.

## Quick start

### Interactive

Run it without arguments (or double-click it):

```
SqlServerDbScriptExporter
```

It asks for the server, login and password, lists the databases to pick from, then what to script and where to.
Every answer is remembered as the default for the next run (in `SqlServerDbScriptExporter.settings.json` next to
the executable) — except the password, which is never saved. If the connection fails, it says why and lets you
change the answers.

### Scripted

Give it the connection and what to do; it then asks for nothing but the password (see
[Password](#password)), so it can run from scripts and scheduled tasks:

```bash
# Every object of MyDb, one file per object, into a repo's Database folder
SqlServerDbScriptExporter -S myserver.database.windows.net -d MyDb -U mylogin -o ./Database

# Only the data of a few lookup tables, into Database/MetaData
SqlServerDbScriptExporter -S localhost -d MyDb -U mylogin --trust-server-certificate \
  --content data --objects dbo.Country,dbo.Status --data-folder MetaData -o ./Database

# Schema and data of the whole database in one file, e.g. to set up a copy elsewhere
SqlServerDbScriptExporter -S localhost -d MyDb -U mylogin --trust-server-certificate \
  --single-file --content all -o ./MyDb.sql --no-pause
```

When it finishes, it shows a summary (added, updated, renamed, deleted, unchanged, failed per folder) and waits
for a key, so a double-clicked window stays open. Add `--no-pause` for unattended runs (runs with redirected
input never wait).

## What it writes

### One file per object

Relative to the output folder (`-o`):

| Folder | File | Contains |
|---|---|---|
| `Table/` | `<schema>.<name>.Table.sql` | The table with its keys, constraints, defaults, indexes, triggers |
| `SP/` | `<schema>.<name>.StoredProcedure.sql` | A stored procedure |
| `UDF/` | `<schema>.<name>.UserDefinedFunction.sql` | A user-defined function |
| `UDT/` | `<schema>.<name>.UserDefinedTableType.sql` | A user-defined table type |
| `Views/` | `<schema>.<name>.View.sql` | A view |
| `Data/` | `<schema>.<name>.Table.sql` | A table's rows as `INSERT`s (folder name: `--data-folder`) |

Schema files start with an `/****** Object: … Script Date: … ******/` header, and every batch ends with `GO`.
Data files contain the `INSERT`s (with `SET IDENTITY_INSERT` where needed), with a `GO` after every 100 statements.

### Single file

With `--single-file`, everything goes into one file (`<database>.sql` by default), in an order that runs on an
empty database:

1. table types;
2. tables, functions, views and procedures, each after what it uses (dependency order) — tables without their
   foreign keys and triggers;
3. the data, parent tables first;
4. the foreign keys and the triggers.

So the rows can be inserted in any order, and triggers do not fire on them. If anything could not be scripted,
the file starts with a comment listing what is missing.

### Keeping a repo in sync

Point `-o` at the folder in your repo and re-run it whenever the database changed:

- Only the files whose object changed are rewritten; the others keep their old `Script Date`, so a re-run against
  an unchanged database gives an empty `git diff`.
- Files of objects that no longer exist are listed at the end. `--prune` deletes them (an interactive run asks).
- Choosing specific objects (`--objects`, or the list in interactive mode) leaves the files of all other objects
  alone — they are not treated as leftovers.
- **Hand-written files** (alter scripts, rollbacks, seeds, sub folders, …) in the same folders are never touched,
  as long as their names are not `<schema>.<name>.<type>.sql`. A file counts as generated by its name alone, so
  call them e.g. `dbo.X.Alter.sql` or `dbo.X.Rollback_1.sql`, not `dbo.X.Rollback.Table.sql` (pruning would delete
  that).

## Options

| Option | |
|---|---|
| **Connection** (SQL login) | |
| `-S`, `--server <name>` | Server, e.g. `localhost`, `.\SQLEXPRESS`, `myserver.database.windows.net` |
| `-d`, `--database <name>` | Database |
| `-U`, `--user <login>` | SQL login (the password: see [Password](#password)) |
| `--trust-server-certificate` | Accept a self-signed server certificate (typical for local servers) |
| **What** (the entire database by default) | |
| `--content <what>` | `schema` (default), `data` (of the tables), or `all` |
| `--only <types>` | Only these object types: a comma separated subset of `Table`, `SP`, `UDF`, `UDT`, `Views` |
| `--objects <names>` | Only these objects, of any type, e.g. `dbo.Country,[dbo].[usp_GetX]` (schema defaults to `dbo`) |
| `--create-or-alter` | Procedures, functions and views as `CREATE OR ALTER` (tables and table types always use `CREATE`) |
| **Where** | |
| `-o`, `--output <path>` | One file per object: the root folder. Single file: a folder (for `<database>.sql`) or a `.sql` file. Default: the current folder |
| `--single-file` | Everything in one file (see [Single file](#single-file)) |
| `--data-folder <name>` | One file per object: the folder for the data files (default: `Data`) |
| `--prune` | One file per object: delete generated files whose object no longer exists |
| **Other** | |
| `--no-pause` | Exit at the end without "Press any key to exit" |
| `--version` | Show the version |
| `-h`, `--help` | Show the help |

The same choice of objects covers the schema and the data: `--content all --objects dbo.Country` writes the
`Country` table and its rows. The exit code is `0` when everything worked, `1` when something failed (connection,
an object, a file) and `2` for invalid options.

## Password

The password is never an option on the command line and never saved. It is read from the `DB_EXPORT_PASSWORD`
environment variable, or asked for (hidden). In PowerShell you can set it for the current window without it
showing on screen or in the history:

```powershell
$env:DB_EXPORT_PASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host 'Password' -AsSecureString)).Password
```

The connection is always encrypted; use `--trust-server-certificate` for servers with a self-signed certificate.

## Running from source

You need the [.NET 10 SDK](https://dotnet.microsoft.com/download). The whole app is one file,
`SqlServerDbScriptExporter.cs` (a .NET [file-based app](https://learn.microsoft.com/dotnet/core/sdk/file-based-apps)),
and the run scripts start it with all arguments passed through:

```bash
./run.sh --help        # bash, zsh, sh
```

```powershell
.\run.ps1 --help       # PowerShell
```

When run this way, the settings file is kept next to `SqlServerDbScriptExporter.cs`.

## Building the executables

`publish.ps1` and `publish.sh` (same options) build the app into `publish/<platform>/`:

```bash
./publish.sh                                    # this machine: one self-contained executable
./publish.sh -r linux-arm64 --app-version 1.2.0 # another platform, with a version
./publish.sh --no-self-contained                # about 20 MB instead of 90, needs the .NET 10 runtime
./publish.sh --compress                         # about 40 MB, starts a bit slower
```

Run `./publish.sh --help` for all options. Native AOT is not possible: SMO, which the app uses for scripting,
does not support it.

## Releases

[`.github/workflows/release.yml`](.github/workflows/release.yml) builds all seven downloads and publishes them as a
GitHub release:

```bash
git tag release/1.2.0
git push origin release/1.2.0
```

A tag with a pre-release part (`release/1.3.0-beta.1`) becomes a pre-release. The release notes list the
downloads and then GitHub's generated notes (the changes since the previous release). To try it without
releasing, run the workflow by hand (Actions → Release → Run workflow) with a version: it only builds the
downloads, as workflow artifacts.

The version is the one in the tag; `--version` shows it. Local builds show `0.0.0-dev` (or what you pass with
`--app-version`).

## Limitations

- **SQL logins only:** no Windows authentication and no Microsoft Entra ID (Azure AD) sign-in.
- **Not scripted:** schemas, sequences, synonyms, alias types (`CREATE TYPE … FROM`), database-level triggers,
  and SQL Server security: logins, database users, database roles and permissions (`GRANT` / `DENY`). Tables of
  your own that hold users, roles or permissions are ordinary tables and are scripted like any other.
- The order of rows in the data files is the one SQL Server returns; it can differ between runs (which is why it
  does not count as a change).
- The macOS executables are not notarized (see [Download](#download)).

## License

[MIT](LICENSE)