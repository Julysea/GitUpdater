# GitUpdater

GitUpdater is a Windows Releases updater inspired by [DCUpdater](../dcupdater). It supports GitHub, Gitea/Forgejo (including Codeberg and self-hosted instances) and GitLab.

It reads the latest release from the release host, downloads the specified release asset, extracts it into the folder containing `GitUpdater.exe` as needed, and shows download progress, release notes, and completion status. The host is detected from the configured URL, so a Releases page URL can be pasted as is.

**GitUpdater only handles updates, not launching software.** It does not start the target application after updating.

## Features

* No built-in repository rules
* The settings window has empty defaults for repository and asset file, with example hints displayed above the input boxes
* Users fill in their own repository URL (GitHub / Gitea / GitLab) and asset file name
* Supports `[$ver]` / `[$tag]` version placeholders, suitable for repositories with versioned asset names
* Reads the first entry of the Releases list, matching the order shown on the Releases page
* Uses download links from the release notes when a release has no attached assets
* Compares only the latest tag string: skips if the same, updates if different; no rc/beta semantic version comparison
* Shows "Already up to date" when no update is needed, with a "Settings" button (saving the configuration immediately re-checks for updates) and a "Close" button
* The settings window has only two buttons, "Ok" and "Cancel": "Ok" saves and returns to the previous window; "Cancel" or closing the window discards changes and returns to the previous window. On first run and with `--settings`, both exit the program
* Download progress, automatic retry on failure, release notes
* Confirmation window shows update details; updates only proceed after clicking "Yes"
* Clicking "No" or closing the window cancels the update
* Shows "Update complete" after finishing, waits for user to click "Close" before exiting
* Does not automatically start the updated application
* Install directory is fixed to the folder containing `GitUpdater.exe`
* Process check uses repository name + `.exe` (e.g., `opencode.exe`, `marktext.exe`)
* Anonymous GitHub access, no Token required (the token is only sent to GitHub hosts)
* Auto-extracts common archive formats (zip / 7z / rar / tar / tar.gz / tar.bz2 / tar.xz); other formats are downloaded only
* Built-in Chinese/English support, no external translation files needed
* Help button in the settings window opens the help page in the default browser; Chinese and English pages are embedded in the exe, the one matching the Windows UI language is chosen automatically, and it is extracted to the temp folder on first use (a `help_zh.html` / `help_en.html` next to the exe overrides the built-in page)
* Log file
* Custom icon

## Directory Structure

```
GitUpdater/
  README.md
  README_EN.md
  gitupdater.ico            ; Application icon
  trunk/win32/
    GitUpdater.au3          ; Entry script (globals, Main)
    include/                ; Modules grouped by feature
      lang.au3              ; Language detection and translation
      log.au3               ; Logging, error dialogs, exit
      helpers.au3           ; Path, folder and process helpers
      config.au3            ; Configuration load/save (gitupdater.ini)
      http.au3              ; HTTP client (WinHttp)
      json.au3              ; JSON reading
      gitsource.au3         ; Repository URL parsing, host detection and release info
      assets.au3            ; Release asset name matching
      download.au3          ; Download and progress window
      archive.au3           ; Extraction and file installation
      ui.au3                ; Settings, confirmation and status windows
    README.txt
    help_zh.html            ; Chinese help page source, embedded into the exe (extracted to %TEMP% when shown)
    help_en.html            ; English help page source, embedded into the exe (chosen by the UI language)
    gitupdater.ini.example  ; Configuration example
```

## Quick Start

1. Compile `trunk/win32/GitUpdater.au3` to produce `GitUpdater.exe`.
2. Place `GitUpdater.exe` in the directory of the program you want to update, for example:
   * opencode: `D:\Apps\opencode\`
   * marktext: marktext's installation directory
3. Run `GitUpdater.exe`. The first run shows the settings window.
4. Fill in the **repository URL** and **asset file**. Example hints are displayed above the input boxes.
5. After clicking "Ok" to save, if a new version is found, a confirmation window appears with update details. (When the settings window was opened from a prompt via "Settings", "Cancel" returns to that prompt instead of exiting.)
6. Click "Yes" to start downloading, or "No" / close the window to exit without updating.
7. After updating, the window shows "Update complete". Click "Close" to exit.
8. GitUpdater does not start the target program; you need to start it yourself.

> Please close the target application in the target directory before updating. GitUpdater derives the process name from the repository name and checks for it.

## Example Configurations

### opencode

```text
Repository URL:
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
Repository URL:
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
You can also add `--settings` at startup to reopen the settings window; "Ok" saves and exits, "Cancel" exits without saving.

### `[General]`

| Key | Default | Description |
| --- | --- | --- |
| `Update` | `ask` | `yes` updates directly, `ask` shows confirmation window, `no` skips checking and updating (exits immediately) |
| `UpdateOnceADay` | `no` | When `yes`, checks at most once per day; running again on the same day exits immediately |
| `LogFile` | `gitupdater.log` | Log file path; leave empty to disable logging |

### `[Internet]`

| Key | Default | Description |
| --- | --- | --- |
| `SoftwareUrl` | empty | **Required**, repository URL (GitHub / Gitea / GitLab, a `/releases` suffix is fine) |
| `AssetFile` | empty | **Required**, release asset file name; supports `[$ver]` / `[$tag]` placeholders |
| `UserAgent` | `GitUpdater/1.0` | User-Agent for release host API requests |
| `DownloadRetries` | `2` | Number of retries on download failure (total attempts = retries + 1) |

### `[Extract]`

| Key | Default | Description |
| --- | --- | --- |
| `StripRootFolder` | `yes` | If the archive has only one top-level folder, automatically moves its contents to the install directory |
| `DeleteDownloadedFiles` | `yes` | Deletes downloaded files after successful archive extraction; download-only mode keeps the file |
| `BinPath` | empty | Path inside the archive to extract (relative to archive root). Empty means extract all contents; `BIN` means extract only the `BIN` directory; `foo/bar` means extract the `foo/bar` path. Both `/` and `\` work as separators and leading/trailing slashes are ignored (`foo\bar\` is the same as `foo/bar`) |

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
* `LastUpdatedRepo`: Repository name that `LastUpdatedVersion` belongs to
* `LastReleaseUrl`: Release page URL of the last update

### Removed old configuration keys

The following configuration keys are now ignored:

* `InstallDir`: Install directory is fixed to `@ScriptDir`
* `PostExecution`: GitUpdater no longer starts the application
* `ProcessName`: Now derived from the repository name
* `ExtractCommand`: Now auto-extracts based on archive format
* `ReleaseTag`: Fixed to read the first entry of Releases
* `AssetPattern`: Replaced by `AssetFile`, supports `[$ver]` / `[$tag]`
* `ApiToken`: Anonymous GitHub access (sent to GitHub hosts only)
* `TranslationFile`: Chinese/English built-in

### New configuration keys

* `DownloadRetries`: Number of retries on download failure, default `2`
* `BinPath`: Path inside the archive to extract, default empty (extract all contents)

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
* Must exactly match the asset file name in the release (after placeholder replacement).
* If not filled in or no match is found after replacement, a list of available assets is shown; when a closest file name is found, a window asks whether to download it.
* The asset confirmation window offers "Settings" to change the asset name: "Ok" saves and re-checks, "Cancel" returns to that window.
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

* Previous: `v0.24.0-rc.1`, latest: `v0.24.0-rc.1` → skip, shows "Already up to date" with "Settings" and "Close" buttons
* Previous: `v0.24.0-rc.1`, latest: `v0.24.0-rc.2` → update
* Previous: `v0.24.0-rc.1`, latest: `v0.24.0` → update

The recorded version is also bound to the repository name: if `SoftwareUrl` is changed to another repository later, the check runs again even when the tag is the same instead of reporting "already up to date".

Use `--force` to ignore the same tag and force re-download.

## Command Line Arguments

| Argument | Description |
| --- | --- |
| `--settings` | Open the settings window; "Ok" saves and exits, "Cancel" exits without saving |
| `--force` | Ignore "once per day" and same-tag checks, update directly |

For example:

```bat
GitUpdater.exe --settings
GitUpdater.exe --force
```

## Workflow

1. Read `gitupdater.ini`.
2. If the repository or asset file is empty (first run), show the settings window: "Ok" saves and continues, "Cancel" or closing exits.
3. Install directory is fixed to the folder containing `GitUpdater.exe`; check write permission.
4. Derive process name from the repository name (e.g., `marktext` → `marktext.exe`), check if the target application is running.
   * If the target application is running → prompt user to close it, exit.
   * If the target file is read-only → prompt user, exit.
5. If `Update` is not `yes` / `ask`, exit immediately.
6. If "once per day" is enabled and a check has already been done today, exit immediately.
7. Detect the release host from the URL and call the matching API:
   * GitHub: `GET https://api.github.com/repos/{owner}/{repo}/releases?per_page=1`
   * Gitea/Forgejo: `GET {site}/api/v1/repos/{owner}/{repo}/releases?limit=1`
   * GitLab: `GET {site}/api/v4/projects/{group%2Frepo}/releases?per_page=1`
   * Take the first entry of the Releases list
8. Read `tag_name`, the release notes (`body`, or `description` on GitLab), and `assets`; when there are no attachments, use the links from the release notes instead.
9. Replace `[$ver]` / `[$tag]`, match assets by full file name.
10. Compare the latest tag with `LastUpdatedVersion` (and verify `LastUpdatedRepo` still matches the configured repository):
    * Same and no `--force` → show "Already up to date":
        * "Settings" → open the settings window: "Ok" saves and restarts the check; "Cancel" returns to the "Already up to date" window without a new request
        * "Close" → exit
    * Same and with `--force` → continue updating
    * Different → continue
11. If an update is needed and `Update=ask`, show the confirmation window:
    * Display repository, current version, available version, and release notes
    * Only proceed after clicking "Yes"
    * Clicking "No" or closing the window exits without downloading
    * "Settings" → open the settings window: "Ok" saves and re-checks; "Cancel" returns to the confirmation window
12. Show download progress and download the asset; retry on failure according to `DownloadRetries`.
13. Process the downloaded file based on extension:
    * zip / 7z / rar / tar / tar.gz / tar.bz2 / tar.xz → auto-extract
    * Other formats → download only
14. Extract the specified path from the archive based on `BinPath` configuration (empty means extract all contents).
15. Remove old version directories (directories with a different version number).
16. Write `LastUpdatedVersion` / `LastUpdateDate`, clean up downloaded files according to rules.
17. Show "Update complete" or "Download complete", wait for user to click "Close" before exiting.
18. **Does not start the updated application.**

## Notes

* GitUpdater does not automatically start the target application.
* The target application in the target directory must be closed before updating, otherwise files may be in use.
* GitUpdater updates **the directory it resides in**. To update a program in a specific directory, place `GitUpdater.exe` in that directory.
* The process name is derived from the repository name; if the actual process name differs, the check may not work, and file-in-use errors will occur.
* No semantic version comparison; only tag strings are compared.
* Non-archive formats are downloaded only; files are kept.
* 7z/rar extraction requires 7-Zip to be installed; zip and tar formats use Windows built-in tools.
* Unauthenticated GitHub API rate limit is approximately 60 requests per hour; no Token needed. `ApiToken` is only sent to GitHub hosts, never to other sites.
* If installed in protected directories like `Program Files`, you may need to run as administrator.
* The interface language is automatically selected based on Windows display language; no external translation files.
* The source file contains Chinese strings and must be saved as **UTF-8 with BOM**.
* When `Update=no`, no update check is performed; the program exits immediately.
* When `UpdateOnceADay=yes`, running a second time on the same day exits immediately without a dialog.
* On download failure, automatic retries are performed; total attempts = `DownloadRetries` + 1.
* After successful archive extraction, the downloaded file is deleted according to `DeleteDownloadedFiles`.
* Download-only mode (non-archive formats) always keeps the downloaded file.
