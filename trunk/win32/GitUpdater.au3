#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile_x64=GitUpdater.exe
#AutoIt3Wrapper_icon=..\..\gitupdater.ico
#AutoIt3Wrapper_Res_Comment=GitHub Release Updater
#AutoIt3Wrapper_Res_Description=Downloads and installs the latest release from a GitHub repository
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

; ---------------------------------------------------------------------------
; GitUpdater
;
; A small updater inspired by DCUpdater. It reads the newest release from a
; GitHub repository, downloads the release asset with the configured file
; name, extracts it into the folder containing GitUpdater.exe, shows progress
; and release notes, and waits for the user to close the completion window.
; It does not start the updated application.
;
; Example configuration (shown as hints in the settings window):
;   https://github.com/anomalyco/opencode
;   asset: opencode-windows-x64.zip
;   asset with version: marktext-win-x64-[$ver].zip
;
; Layout (this file is the entry point: Global state and Main()):
;   include\lang.au3       language detection and T() translation helper
;   include\log.au3        logging, error dialogs and exit helpers
;   include\helpers.au3    path, folder and process helpers
;   include\config.au3     gitupdater.ini load/save
;   include\http.au3       WinHttp GET client
;   include\json.au3       minimal JSON reading helpers
;   include\github.au3     repository URL and release info
;   include\assets.au3     release asset name matching
;   include\download.au3   asset download and progress window
;   include\archive.au3    archive extraction and file installation
;   include\ui.au3         settings, confirmation and status windows
;
; All modules are included once; functions are global in AutoIt, so the
; include order only matters for top-level code (there is none in the modules).
; ---------------------------------------------------------------------------

#include <File.au3>
#include <Date.au3>
#include <ButtonConstants.au3>
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <ComboConstants.au3>
#include <MsgBoxConstants.au3>
#include <StringConstants.au3>

; Project modules
#include "include\lang.au3"
#include "include\log.au3"
#include "include\helpers.au3"
#include "include\config.au3"
#include "include\http.au3"
#include "include\json.au3"
#include "include\github.au3"
#include "include\assets.au3"
#include "include\download.au3"
#include "include\archive.au3"
#include "include\ui.au3"

Global $g_workingDir = @ScriptDir & '\'
Global $g_iniFile = $g_workingDir & 'gitupdater.ini'

; Settings (defaults are used on the first run and then written to the ini)
Global $g_softwareUrl = ''
Global $g_assetFile = ''
Global $g_installDir = '@ScriptDir'
Global $g_processName = ''
Global $g_update = 'ask'
Global $g_onceADay = 'no'
Global $g_deleteDownloaded = 'yes'
Global $g_stripRoot = 'yes'
Global $g_binPath = ''
Global $g_logFile = 'gitupdater.log'
Global $g_apiToken = ''
Global $g_userAgent = 'GitUpdater/1.0'
Global $g_downloadRetries = 2
Global $g_suppressErrors = 'no'

; Runtime state
Global $g_lang = 'en'
Global $g_force = False
Global $g_installPath = ''
Global $g_downloadFile = ''
Global $g_statusForm = 0
Global $g_statusDescription = 0
Global $g_statusCompleteLabel = 0
Global $g_statusCompleteValue = 0
Global $g_statusCloseButton = 0
Global $g_didProcess = False
Global $g_restartCount = 0
Global $g_updateApproved = False

; Translations
Global $g_tOKButton = '&Ok'
Global $g_tCancelButton = '&Cancel'
Global $g_tYesButton = '&Yes'
Global $g_tNoButton = '&No'
Global $g_tCloseButton = '&Close'
Global $g_tBackButton = '&Back'
Global $g_tSettingsButton = '&Settings'
Global $g_tStatusFormTitle = 'GitUpdater Status'
Global $g_tStatusDownloadLabel = 'Downloading'
Global $g_tStatusCompleteLabel = 'Complete'
Global $g_tStatusExtractLabel = 'Extracting'
Global $g_tStatusChangelogLabel = 'Release notes'
Global $g_tUpdateCompleteLabel = 'Update complete'
Global $g_tDownloadCompleteLabel = 'Download complete'
Global $g_tColon = ': '

; Keep COM errors from opening a dialog. HttpGet handles HTTP failures itself.
Global $g_comError = ObjEvent('AutoIt.Error', 'ComErrorHandler')

Main()
Exit

Func Main()
	Local $firstRun = Not FileExists($g_iniFile)
	Local $settingsOnly = StringInStr($CmdLineRaw, '--settings') > 0
	Local $lastDate = ''
	Local $days = 0
	Local $targetExe = ''
	Local $json = ''
	Local $tag = ''
	Local $releaseName = ''
	Local $releaseUrl = ''
	Local $releaseBody = ''
	Local $lastVersion = ''
	Local $lastRepo = ''
	Local $currentText = ''
	Local $assets = 0
	Local $assetIndex = -1
	Local $available = ''
	Local $i = 0
	Local $assetName = ''
	Local $assetUrl = ''
	Local $assetSize = 0
	Local $assetFile = ''
	Local $resolvedAsset = ''
	Local $assetInfo = ''
	Local $assetChoice = ''
	Local $willProcess = False

	LogW('******** GitUpdater starting ********')

	If StringInStr($CmdLineRaw, '--force') > 0 Then $g_force = True

	If Not $firstRun Then LoadSettings()
	SetLanguage()

	If $firstRun Or $settingsOnly Or $g_softwareUrl = '' Or $g_assetFile = '' Then
		If Not ShowSettings() Then
			LogW('Settings canceled')
			Exit
		EndIf
		SaveSettings()
		If $settingsOnly Then
			LogW('Settings saved, exiting')
			Exit
		EndIf
	EndIf

	If $g_force Then $g_update = 'yes'

	$g_processName = GetProcessName($g_softwareUrl)
	$g_installPath = ResolveDir($g_installDir)
	If Not FolderExists($g_installPath) Then
		If DirCreate($g_installPath) Then
			LogW('Created install folder: ' & $g_installPath)
		Else
			FatalError(T('Could not create install folder:', '无法创建安装目录：') & @CRLF & $g_installPath)
			CancelExit()
		EndIf
	EndIf

	If Not IsDirWritable($g_installPath) Then
		FatalError(T('The install folder is not writable:', '安装目录不可写：') & @CRLF & $g_installPath & @CRLF & @CRLF & T('Move GitUpdater to a writable folder or run it as administrator.', '请把 GitUpdater 放到可写目录，或以管理员身份运行。'))
		CancelExit()
	EndIf

	If $g_update <> 'yes' And $g_update <> 'ask' Then
		LogW('Update is disabled (Update=' & $g_update & ')')
		okExit()
	EndIf

	; Return early when the update check already ran today.
	If $g_onceADay = 'yes' And Not $g_force Then
		$lastDate = IniRead($g_iniFile, 'General', 'LastUpdateDate', '')
		If $lastDate <> '' Then
			$days = _DateDiff('d', $lastDate, _NowCalcDate())
			If @error = 0 And $days < 1 Then
				LogW('Already checked today: ' & $lastDate)
				okExit()
			EndIf
		EndIf
	EndIf

	; Do not update while the application is running.
	If $g_processName <> '' Then
		$targetExe = $g_installPath & $g_processName
		If IsTargetRunning($targetExe) Then
			LogW('Application is running: ' & $targetExe)
			MsgBox($MB_ICONINFORMATION, 'GitUpdater', $targetExe & T(' is running.', ' 正在运行。') & @CRLF & @CRLF & T('Please close it and run GitUpdater again.', '请关闭它后重新运行 GitUpdater。'))
			CancelExit()
		EndIf

		If FileExists($targetExe) And StringInStr(FileGetAttrib($targetExe), 'R') Then
			LogW('Target file is read-only: ' & $targetExe)
			MsgBox($MB_ICONINFORMATION, 'GitUpdater', T('The target file is read-only:', '目标文件是只读的：') & @CRLF & $targetExe & @CRLF & @CRLF & T('Close the application and try again.', '请关闭程序后重试。'))
			CancelExit()
		EndIf
	EndIf

	$json = FetchRelease()
	If @error Then
		NetworkError(T('Could not read release information from GitHub:', '无法从 GitHub 获取 Release 信息：') & @CRLF & $g_softwareUrl)
		okExit()
	EndIf

	$tag = JsonGetString($json, 'tag_name')
	$releaseName = JsonGetString($json, 'name')
	$releaseUrl = JsonGetString($json, 'html_url')
	$releaseBody = JsonGetString($json, 'body')
	If $tag = '' Then $tag = $releaseName
	If $tag = '' Then
		NetworkError(T('The GitHub release does not contain a version tag:', 'GitHub Release 中没有版本标签：') & @CRLF & $g_softwareUrl)
		okExit()
	EndIf

	$lastVersion = IniRead($g_iniFile, 'General', 'LastUpdatedVersion', '')
	$lastRepo = IniRead($g_iniFile, 'General', 'LastUpdatedRepo', '')
	If $lastRepo <> '' And $lastRepo <> GetSoftwareName($g_softwareUrl) Then $lastVersion = ''
	If $lastVersion <> '' And Not $g_force And $lastVersion = $tag Then
		LogW('Already up to date (same tag): ' & $tag)
		If ShowNoUpdate($tag) = 'settings' Then RedefineSettings()
		IniWrite($g_iniFile, 'General', 'LastUpdateDate', _NowCalcDate())
		okExit()
	EndIf

	If $g_update = 'ask' And Not $g_force And Not $g_updateApproved Then
		$currentText = $lastVersion
		If $currentText = '' Then
			If $g_processName <> '' And FileExists($g_installPath & $g_processName) Then
				$currentText = T('(installed, version unknown)', '(已安装，版本未知)')
			Else
				$currentText = T('(not installed)', '(未安装)')
			EndIf
		EndIf
		Local $confirmResult = ConfirmUpdate($g_softwareUrl, $currentText, $tag, $releaseBody)
		If $confirmResult = 'settings' Then
			LogW('Redefining configuration from update prompt')
			RedefineSettings()
		ElseIf $confirmResult = 'yes' Then
			; Continue this run instead of restarting: a restart would load
			; Update=ask again and show the same prompt in an endless loop.
			LogW('Update confirmed by user')
			$g_updateApproved = True
		Else
			LogW('Update declined by user')
			IniWrite($g_iniFile, 'General', 'LastUpdateDate', _NowCalcDate())
			okExit()
		EndIf
	EndIf

	$assets = ParseAssets($json)
	If UBound($assets) = 0 Then
		FatalError(T('The release does not contain any downloadable assets:', '该 Release 没有可下载的资源：') & @CRLF & $g_softwareUrl)
		okExit()
	EndIf

	$resolvedAsset = ResolveAssetName($g_assetFile, $tag)
	$assetIndex = PickAsset($assets, $resolvedAsset)
	Local $isExactMatch = ($assetIndex >= 0)

	; The configured file name does not exist in the release. Find the closest
	; asset name and always ask the user before downloading a different file.
	If Not $isExactMatch Then
		Local $nearScore = 0
		$assetIndex = FindClosestAsset($assets, $resolvedAsset, $nearScore)
		If $assetIndex = -1 Then
			$available = ''
			For $i = 0 To UBound($assets) - 1
				$available &= @CRLF & '  - ' & $assets[$i][0]
			Next
			$assetInfo = $g_assetFile
			If $resolvedAsset <> $g_assetFile Then $assetInfo &= ' -> ' & $resolvedAsset
			FatalError(T('No release asset matched the configured file name:', '没有找到匹配的资源文件：') & @CRLF & $assetInfo & @CRLF & @CRLF & T('Available assets:', '可用资源：') & $available)
			okExit()
		EndIf

		LogW('No exact asset. Closest match: ' & $assets[$assetIndex][0] & ' (' & Round($nearScore) & '%)')
		$assetChoice = ConfirmAsset($g_assetFile, $resolvedAsset, $assets[$assetIndex][0], $nearScore, $tag, $releaseBody, $assets)
		If $assetChoice = 'settings' Then
			LogW('Redefining configuration from asset prompt')
			RedefineSettings()
		ElseIf $assetChoice <> 'yes' Then
			LogW('Closest asset declined by user: ' & $assets[$assetIndex][0])
			IniWrite($g_iniFile, 'General', 'LastUpdateDate', _NowCalcDate())
			okExit()
		EndIf
		LogW('Closest asset accepted by user: ' & $assets[$assetIndex][0])
	EndIf

	$assetName = $assets[$assetIndex][0]
	$assetUrl = $assets[$assetIndex][1]
	$assetSize = $assets[$assetIndex][2]
	$assetFile = StringRegExpReplace($assetName, '[\\/:*?"<>|]', '_')
	$g_downloadFile = $g_installPath & $assetFile

	LogW('Remote version: ' & $tag)
	If $resolvedAsset <> $g_assetFile Then LogW('Resolved asset: ' & $g_assetFile & ' -> ' & $resolvedAsset)
	LogW('Selected asset: ' & $assetName & ' (' & $assetSize & ' bytes)')

	If Not DownloadAsset($assetUrl, $assetSize, $tag, $releaseBody) Then
		okExit()
	EndIf

	$willProcess = (GetArchiveKind($assetName) <> '')
	If $willProcess Then
		If $g_statusDescription <> 0 Then GUICtrlSetData($g_statusDescription, $g_tStatusExtractLabel & $g_tColon)
		If $g_statusCompleteValue <> 0 Then GUICtrlSetData($g_statusCompleteValue, '0 %')
	EndIf

	If Not ProcessDownload($g_downloadFile, $g_installPath, $tag) Then
		FatalError(T('Could not process the downloaded file:', '无法处理下载的文件：') & @CRLF & $g_downloadFile)
		GUIDelete($g_statusForm)
		CleanUpDownload()
		okExit()
	EndIf

	If $g_didProcess Then
		If $g_statusDescription <> 0 Then GUICtrlSetData($g_statusDescription, $g_tUpdateCompleteLabel & $g_tColon)
	Else
		If $g_statusDescription <> 0 Then GUICtrlSetData($g_statusDescription, $g_tDownloadCompleteLabel & $g_tColon)
	EndIf
	If $g_statusCompleteValue <> 0 Then GUICtrlSetData($g_statusCompleteValue, '100 %')
	If $g_statusCloseButton <> 0 Then GUICtrlSetData($g_statusCloseButton, $g_tCloseButton)
	IniWrite($g_iniFile, 'General', 'LastUpdateDate', _NowCalcDate())
	IniWrite($g_iniFile, 'General', 'LastUpdatedVersion', $tag)
	IniWrite($g_iniFile, 'General', 'LastUpdatedRepo', GetSoftwareName($g_softwareUrl))
	If $releaseUrl <> '' Then IniWrite($g_iniFile, 'General', 'LastReleaseUrl', $releaseUrl)
	CleanUpDownload()

	If $g_didProcess Then
		LogW('Update complete: ' & $tag)
	Else
		LogW('Download complete: ' & $g_downloadFile)
	EndIf
	WaitForStatusClose()
	GUIDelete($g_statusForm)
	okExit()
EndFunc
