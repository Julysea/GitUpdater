# GitUpdater

GitUpdater is a Windows GitHub Releases updater inspired by [DCUpdater](../dcupdater).

It reads the latest release from **GitHub Releases**, downloads the specified release asset, extracts it into the folder containing `GitUpdater.exe` as needed, and shows download progress, release notes, and completion status.

**GitUpdater only handles updates, not launching software.** It does not start the target application after updating.

## Features

* No built-in repository rules
* The settings window has empty defaults for repository and asset file, with example hints displayed above the input boxes
* Users fill in their own GitHub repository URL and asset file name
* Supports `[$ver]` / `[$tag]` version placeholders, suitable for repositories with versioned asset names
* Reads the first entry of the Releases list, matching the order shown on the GitHub Releases page
* Compares only the latest tag string: skips if the same, updates if different; no rc/beta semantic version comparison
* Shows "Already up to date" prompt when no update is needed, waits for user to click "Close"
* Download progress, automatic retry on failure, release notes
* Confirmation window shows update details; updates only proceed after clicking "Yes"
* Clicking "No" or closing the window cancels the update
* Shows "Update complete" after finishing, waits for user to click "Close" before exiting
* Does not automatically start the updated application
* Install directory is fixed to the folder containing `GitUpdater.exe`
* Process check uses repository name + `.exe` (e.g., `opencode.exe`, `marktext.exe`)
* Anonymous GitHub access, no Token required
* Auto-extracts common archive formats (zip / 7z / rar / tar / tar.gz / tar.bz2 / tar.xz); other formats are downloaded only
* Built-in Chinese/English support, no external translation files needed
* Log file
* Custom icon

## Directory Structure

```
GitUpdater/
  README.md
  README_EN.md
  gitupdater.ico            ; Application icon
  trunk/win32/
    GitUpdater.au3          ; AutoIt source code
    README.txt
    gitupdater.ini.example  ; Configuration example
```

## Quick Start

1. Compile `trunk/win32/GitUpdater.au3` to produce `GitUpdater.exe`.
2. Place `GitUpdater.exe` in the directory of the program you want to update, for example:
   * opencode: `D:\Apps\opencode\`
   * marktext: marktext's installation directory
3. Run `GitUpdater.exe`. The first run shows the settings window.
4. Fill in the **GitHub repository** and **asset file**. Example hints are displayed above the input boxes.
5. After clicking "Ok", if a new version is found, a confirmation window appears with update details.
6. Click "Yes" to start downloading, or "No" / close the window to exit without updating.
7. After updating, the window shows "Update complete". Click "Close" to exit.
8. GitUpdater does not start the target program; you need to start it yourself.

> Please close the target application in the target directory before updating. GitUpdater derives the process name from the repository name and checks for it.

## Example Configurations

### opencode

```text
GitHub repository:
https://github.com/anomalyco/opencode

Asset file:
opencode-windows-x64.zip
```

### marktext

marktext's asset names include the version number:

```text
marktext-win-x64-0.24.0-rc.1.zip
```

Using the `[$ver]` placeholder:

```text
GitHub repository:
https://github.com/marktext/marktext

Asset file:
marktext-win-x64-[$ver].zip
```

The program reads the latest tag, for example `v0.24.0-rc.1`, and replaces `[$ver]` with the version number without the leading `v`:

```text
marktext-win-x64-0.24.0-rc.1.zip
```

## Building

Install [AutoIt v3](https://www.autoitscript.com/site/autoit/) (SciTE / AutoIt3Wrapper recommended):

* Right-click `trunk/win32/GitUpdater.au3` → **Compile (x64)**
* Or use the command line:

```bat
"C:\Program Files (x86)\AutoIt3\SciTE\AutoIt3Wrapper\AutoIt3Wrapper.exe" /in "trunk\win32\GitUpdater.au3" /out "GitUpdater.exe"
```

The generated `GitUpdater.exe` is output to the source directory by default.

> The source file contains Chinese strings and must be saved as **UTF-8 with BOM**.

## Configuration

The configuration file is `gitupdater.ini` in the same directory as `GitUpdater.exe`, automatically generated after the first-run settings window.
You can also add `--settings` at startup to reopen the settings window.

### `[General]`

| Key | Default | Description |
| --- | --- | --- |
| `Update` | `ask` | `yes` updates directly, `ask` shows confirmation window, `no` skips checking and updating (exits immediately) |
| `UpdateOnceADay` | `no` | When `yes`, checks at most once per day; running again on the same day exits immediately |
| `LogFile` | `gitupdater.log` | Log file path; leave empty to disable logging |

### `[Internet]`

| Key | Default | Description |
| --- | --- | --- |
| `SoftwareUrl` | empty | **Required**, GitHub repository URL of the software |
| `AssetFile` | empty | **Required**, release asset file name; supports `[$ver]` / `[$tag]` placeholders |
| `UserAgent` | `GitUpdater/1.0` | User-Agent for GitHub API requests |
| `DownloadRetries` | `2` | Number of retries on download failure (total attempts = retries + 1) |

### `[Extract]`

| Key | Default | Description |
| --- | --- | --- |
| `StripRootFolder` | `yes` | If the archive has only one top-level folder, automatically moves its contents to the install directory |
| `DeleteDownloadedFiles` | `yes` | Deletes downloaded files after successful archive extraction; download-only mode keeps the file |

### `[Error]`

| Key | Default | Description |
| --- | --- | --- |
| `SupressInetRead` | `no` | When `yes`, suppresses network error dialogs; fatal errors still show a prompt |

### `[Meta]`

| Key | Default | Description |
| --- | --- | --- |
| `ConfigVersion` | `1` | Configuration version |

### Runtime-written state

* `LastUpdateDate`: Date of the last check/update
* `LastUpdatedVersion`: Tag of the last update, e.g., `v0.24.0-rc.1`
* `LastReleaseUrl`: Release page URL of the last update

### Removed old configuration keys

The following configuration keys are now ignored:

* `InstallDir`: Install directory is fixed to `@ScriptDir`
* `PostExecution`: GitUpdater no longer starts the application
* `ProcessName`: Now derived from the repository name
* `ExtractCommand`: Now auto-extracts based on archive format
* `ReleaseTag`: Fixed to read the first entry of Releases
* `AssetPattern`: Replaced by `AssetFile`, supports `[$ver]` / `[$tag]`
* `ApiToken`: Anonymous GitHub access
* `TranslationFile`: Chinese/English built-in

### New configuration keys

* `DownloadRetries`: Number of retries on download failure, default `2`

## Asset File Placeholders

`AssetFile` is the asset file name, not a regular expression or wildcard.

Two placeholders are supported:

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `[$ver]` | Latest tag without the leading `v` | `v0.24.0-rc.1` → `0.24.0-rc.1` |
| `[$tag]` | Full latest tag | `v0.24.0-rc.1` → `v0.24.0-rc.1` |

Examples:

```ini
; opencode
AssetFile=opencode-windows-x64.zip

; marktext
AssetFile=marktext-win-x64-[$ver].zip

; Asset name contains the full tag
AssetFile=myapp-[$tag].zip
```

* File name matching is case-insensitive.
* Must exactly match the asset file name in the GitHub Release (after placeholder replacement).
* If not filled in or no match is found after replacement, a list of available assets is shown.
* No automatic selection; no built-in repository rules.
* **Note**: `[$ver]` does **not** include the leading `v` after replacement. If the actual asset filename contains a `v` (e.g., `TriliumNotes-v0.107.0-windows-x64.zip`), write it as `TriliumNotes-v[$ver]-windows-x64.zip`; otherwise it resolves to `TriliumNotes-0.107.0-windows-x64.zip` and fails to match.

## Extraction and Download Strategy

GitUpdater handles files automatically based on the file extension, no extraction command configuration needed:

| Format | Handling |
| --- | --- |
| `.zip` | PowerShell auto-extract |
| `.7z` / `.rar` | 7-Zip extraction (requires 7-Zip installed) |
| `.tar` / `.tar.gz` / `.tgz` | Windows built-in tar |
| `.tar.bz2` / `.tbz2` / `.tbz` | Windows built-in tar |
| `.tar.xz` / `.txz` | Windows built-in tar |
| Other formats | **Download only**, no extraction, no execution |

* For 7z/rar, GitUpdater searches for 7-Zip first; if not found, it tries Windows tar and reports an error if that also fails.
* Download-only mode keeps the downloaded file even if `DeleteDownloadedFiles=yes`.
* Only after successful archive extraction does `DeleteDownloadedFiles` determine whether to delete the file.
* Installers like `setup.exe` and `.msi` are never run automatically.

## Version Comparison

GitUpdater **does not parse version numbers**; it only compares the latest tag string:

* Previous: `v0.24.0-rc.1`, latest: `v0.24.0-rc.1` → skip, shows "Already up to date", waits for "Close"
* Previous: `v0.24.0-rc.1`, latest: `v0.24.0-rc.2` → update
* Previous: `v0.24.0-rc.1`, latest: `v0.24.0` → update

Use `--force` to ignore the same tag and force re-download.

## Command Line Arguments

| Argument | Description |
| --- | --- |
| `--settings` | Open the settings window, save and exit |
| `--force` | Ignore "once per day" and same-tag checks, update directly |

For example:

```bat
GitUpdater.exe --settings
GitUpdater.exe --force
```

## Workflow

1. Read `gitupdater.ini`.
2. If the repository or asset file is empty, show the settings window.
3. Install directory is fixed to the folder containing `GitUpdater.exe`; check write permission.
4. Derive process name from the repository name (e.g., `marktext` → `marktext.exe`), check if the target application is running.
   * If the target application is running → prompt user to close it, exit.
   * If the target file is read-only → prompt user, exit.
5. If `Update` is not `yes` / `ask`, exit immediately.
6. If "once per day" is enabled and a check has already been done today, exit immediately.
7. Call the GitHub API:
   * `GET /repos/{owner}/{repo}/releases?per_page=1`
   * Take the first entry of the Releases list
8. Read `tag_name`, `body` (release notes), and `assets`.
9. Replace `[$ver]` / `[$tag]`, match assets by full file name.
10. Compare the latest tag with `LastUpdatedVersion`:
    * Same and no `--force` → show "Already up to date", wait for user to click "Close"
    * Same and with `--force` → continue updating
    * Different → continue
11. If an update is needed and `Update=ask`, show the confirmation window:
    * Display repository, current version, available version, and release notes
    * Only proceed after clicking "Yes"
    * Clicking "No" or closing the window exits without downloading
12. Show download progress and download the asset; retry on failure according to `DownloadRetries`.
13. Process the downloaded file based on extension:
    * zip / 7z / rar / tar / tar.gz / tar.bz2 / tar.xz → auto-extract
    * Other formats → download only
14. Write `LastUpdatedVersion` / `LastUpdateDate`, clean up downloaded files according to rules.
15. Show "Update complete" or "Download complete", wait for user to click "Close" before exiting.
16. **Does not start the updated application.**

## Notes

* GitUpdater does not automatically start the target application.
* The target application in the target directory must be closed before updating, otherwise files may be in use.
* GitUpdater updates **the directory it resides in**. To update a program in a specific directory, place `GitUpdater.exe` in that directory.
* The process name is derived from the repository name; if the actual process name differs, the check may not work, and file-in-use errors will occur.
* No semantic version comparison; only tag strings are compared.
* Non-archive formats are downloaded only; files are kept.
* 7z/rar extraction requires 7-Zip to be installed; zip and tar formats use Windows built-in tools.
* Unauthenticated GitHub API rate limit is approximately 60 requests per hour; no Token needed.
* If installed in protected directories like `Program Files`, you may need to run as administrator.
* The interface language is automatically selected based on Windows display language; no external translation files.
* The source file contains Chinese strings and must be saved as **UTF-8 with BOM**.
* When `Update=no`, no update check is performed; the program exits immediately.
* When `UpdateOnceADay=yes`, running a second time on the same day exits immediately without a dialog.
* On download failure, automatic retries are performed; total attempts = `DownloadRetries` + 1.
* After successful archive extraction, the downloaded file is deleted according to `DeleteDownloadedFiles`.
* Download-only mode (non-archive formats) always keeps the downloaded file.
