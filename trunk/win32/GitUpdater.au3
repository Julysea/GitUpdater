#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile_x64=GitUpdater.exe
#AutoIt3Wrapper_icon=..\..\gitupdater.ico
#AutoIt3Wrapper_Res_Comment=GitHub Release Updater
#AutoIt3Wrapper_Res_Description=Downloads and installs the latest release from a GitHub repository
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

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
; ---------------------------------------------------------------------------

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

; Translations
Global $g_tOKButton = '&Ok'
Global $g_tCancelButton = '&Cancel'
Global $g_tYesButton = '&Yes'
Global $g_tNoButton = '&No'
Global $g_tCloseButton = '&Close'
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
	If $lastVersion <> '' And Not $g_force And $lastVersion = $tag Then
		LogW('Already up to date (same tag): ' & $tag)
		IniWrite($g_iniFile, 'General', 'LastUpdateDate', _NowCalcDate())
		ShowNoUpdate($tag)
		okExit()
	EndIf

	If $g_update = 'ask' And Not $g_force Then
		$currentText = $lastVersion
		If $currentText = '' Then
			If $g_processName <> '' And FileExists($g_installPath & $g_processName) Then
				$currentText = T('(installed, version unknown)', '(已安装，版本未知)')
			Else
				$currentText = T('(not installed)', '(未安装)')
			EndIf
		EndIf
		If Not ConfirmUpdate($g_softwareUrl, $currentText, $tag, $releaseBody) Then
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
		If Not ConfirmAsset($g_assetFile, $resolvedAsset, $assets[$assetIndex][0], $nearScore, $tag, $releaseBody, $assets) Then
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

	If Not ProcessDownload($g_downloadFile, $g_installPath) Then
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

; ---------------------------------------------------------------------------
; Settings
; ---------------------------------------------------------------------------
Func ShowSettings()
	Local $form = GUICreate(T('GitUpdater Settings', 'GitUpdater 设置'), 520, 450)
	Local $lblSoftware = GUICtrlCreateLabel(T('GitHub repository:', 'GitHub 仓库：'), 8, 10, 496, 17)
	Local $hintSoftware = GUICtrlCreateLabel(T('Example: https://github.com/anomalyco/opencode', '示例：https://github.com/anomalyco/opencode'), 8, 30, 496, 17)
	Local $edtSoftware = GUICtrlCreateInput($g_softwareUrl, 8, 50, 496, 21)
	Local $lblAsset = GUICtrlCreateLabel(T('Asset file:', '资源文件：'), 8, 82, 496, 17)
	Local $hintAsset1 = GUICtrlCreateLabel(T('Example: opencode-windows-x64.zip', '示例：opencode-windows-x64.zip'), 8, 102, 496, 17)
	Local $hintAsset2 = GUICtrlCreateLabel(T('With version: marktext-win-x64-[$ver].zip ([$ver] has no leading v)', '带版本号：marktext-win-x64-[$ver].zip（[$ver] 不含开头的 v）'), 8, 120, 496, 17)
	Local $edtAsset = GUICtrlCreateInput($g_assetFile, 8, 140, 496, 21)
	Local $lblUpdate = GUICtrlCreateLabel(T('Update:', '更新：'), 8, 174, 80, 17)
	Local $cboUpdate = GUICtrlCreateCombo('', 100, 170, 150, 25, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
	Local $chkOnce = GUICtrlCreateCheckbox(T('Limit update check to once a day', '每天只检查一次更新'), 8, 200, 496, 17)
	Local $chkDelete = GUICtrlCreateCheckbox(T('Delete downloaded archive after extraction', '解压后删除下载的压缩包'), 8, 228, 496, 17)
	Local $chkStrip = GUICtrlCreateCheckbox(T('Strip a single root folder from the archive', '自动去掉压缩包的单层根目录'), 8, 256, 496, 17)
	Local $lblArchiveHint = GUICtrlCreateLabel(T('Archives: extract automatically; other formats: download only.', '压缩包会自动解压升级；其他格式只下载，不处理。'), 8, 290, 496, 17)
	Local $lblArchiveFormats = GUICtrlCreateLabel(T('Supported: zip, 7z, rar, tar, tar.gz, tar.bz2, tar.xz', '支持：zip、7z、rar、tar、tar.gz、tar.bz2、tar.xz'), 8, 310, 496, 17)
	Local $lblLog = GUICtrlCreateLabel(T('Log file:', '日志文件：'), 8, 344, 496, 17)
	Local $edtLog = GUICtrlCreateInput($g_logFile, 8, 364, 496, 21)
	Local $btnOk = GUICtrlCreateButton($g_tOKButton, 416, 410, 80, 25, $WS_GROUP)
	Local $btnCancel = GUICtrlCreateButton($g_tCancelButton, 330, 410, 80, 25, $WS_GROUP)
	Local $msg = 0
	Local $updateLabels = ''
	Local $updateSelection = ''

	GUICtrlSetColor($hintSoftware, 0x666666)
	GUICtrlSetColor($hintAsset1, 0x666666)
	GUICtrlSetColor($hintAsset2, 0x666666)
	GUICtrlSetColor($lblArchiveFormats, 0x666666)

	GUICtrlSetTip($edtSoftware, T('Repository URL, for example https://github.com/anomalyco/opencode', '仓库地址，例如 https://github.com/anomalyco/opencode'))
	GUICtrlSetTip($edtAsset, T('Asset file name. Use [$ver] for the latest version without the leading v (e.g. v0.107.0 -> 0.107.0), and [$tag] for the full tag. If the actual filename contains a v (e.g. TriliumNotes-v0.107.0-...), write it as TriliumNotes-v[$ver]-....', '资源文件名。[$ver] 表示最新版本号（去掉开头的 v，如 v0.107.0 -> 0.107.0），[$tag] 表示完整标签。如果实际文件名中包含 v（如 TriliumNotes-v0.107.0-...），需要写成 TriliumNotes-v[$ver]-...。'))
	GUICtrlSetTip($lblArchiveHint, T('ZIP and TAR formats use Windows built-in tools. 7z/RAR require 7-Zip.', 'zip 和 tar 系列使用 Windows 自带工具；7z/rar 需要安装 7-Zip。'))

	$updateLabels = T('yes|ask|no', '是|询问|否')
	$updateSelection = $g_update
	If $g_lang = 'zh' Then
		Switch $g_update
			Case 'yes'
				$updateSelection = '是'
			Case 'ask'
				$updateSelection = '询问'
			Case 'no'
				$updateSelection = '否'
		EndSwitch
	EndIf
	GUICtrlSetData($cboUpdate, $updateLabels, $updateSelection)
	If $g_onceADay = 'yes' Then GUICtrlSetState($chkOnce, $GUI_CHECKED)
	If $g_deleteDownloaded = 'yes' Then GUICtrlSetState($chkDelete, $GUI_CHECKED)
	If $g_stripRoot = 'yes' Then GUICtrlSetState($chkStrip, $GUI_CHECKED)

	GUISetState(@SW_SHOW, $form)
	While True
		$msg = GUIGetMsg()
		If $msg <> 0 Then
			Switch $msg
				Case $GUI_EVENT_CLOSE, $btnCancel
					GUIDelete($form)
					Return False
				Case $btnOk
					If StringStripWS(GUICtrlRead($edtSoftware), 3) = '' Or StringStripWS(GUICtrlRead($edtAsset), 3) = '' Then
						MsgBox($MB_ICONWARNING, 'GitUpdater', T('Please enter the GitHub repository and asset file.', '请填写 GitHub 仓库和资源文件。'))
					Else
						ExitLoop
					EndIf
			EndSwitch
		EndIf
	WEnd

	$g_softwareUrl = StringStripWS(GUICtrlRead($edtSoftware), 3)
	$g_assetFile = StringStripWS(GUICtrlRead($edtAsset), 3)
	$g_update = GUICtrlRead($cboUpdate)
	If $g_lang = 'zh' Then
		Switch $g_update
			Case '是'
				$g_update = 'yes'
			Case '询问'
				$g_update = 'ask'
			Case '否'
				$g_update = 'no'
		EndSwitch
	EndIf
	$g_onceADay = CheckboxValue($chkOnce)
	$g_deleteDownloaded = CheckboxValue($chkDelete)
	$g_stripRoot = CheckboxValue($chkStrip)
	$g_logFile = StringStripWS(GUICtrlRead($edtLog), 3)

	If $g_update = '' Then $g_update = 'ask'

	GUIDelete($form)
	Return True
EndFunc

Func CheckboxValue($ctrl)
	If GUICtrlRead($ctrl) = $GUI_CHECKED Then Return 'yes'
	Return 'no'
EndFunc

Func ConfirmUpdate($repo, $current, $version, $notes)
	Local $form = GUICreate('GitUpdater', 520, 500)
	Local $lblTitle = GUICtrlCreateLabel(T('A new version is available.', '发现新版本。'), 8, 10, 496, 17)
	Local $lblRepo = GUICtrlCreateLabel(T('Repository: ', '仓库：') & $repo, 8, 36, 496, 17)
	Local $lblCurrent = GUICtrlCreateLabel(T('Installed: ', '当前版本：') & $current, 8, 60, 496, 17)
	Local $lblVersion = GUICtrlCreateLabel(T('Available: ', '可用版本：') & $version, 8, 84, 496, 17)
	Local $lblNotes = GUICtrlCreateLabel(T('Release notes:', '更新内容：'), 8, 112, 496, 17)
	Local $editNotes = GUICtrlCreateEdit(PrepareNotes($notes), 8, 134, 496, 300, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_AUTOHSCROLL, $ES_READONLY, $ES_WANTRETURN, $WS_HSCROLL, $WS_VSCROLL))
	Local $btnYes = GUICtrlCreateButton($g_tYesButton, 416, 450, 80, 25, $WS_GROUP)
	Local $btnNo = GUICtrlCreateButton($g_tNoButton, 330, 450, 80, 25, $WS_GROUP)
	Local $msg = 0

	GUICtrlSetState($btnYes, $GUI_FOCUS)
	GUISetState(@SW_SHOW, $form)
	WinActivate($form)

	While True
		$msg = GUIGetMsg()
		If $msg <> 0 Then
			Switch $msg
				Case $GUI_EVENT_CLOSE, $btnNo
					GUIDelete($form)
					Return False
				Case $btnYes
					GUIDelete($form)
					Return True
			EndSwitch
		EndIf
	WEnd
EndFunc

Func ConfirmAsset($configured, $resolved, $matched, $score, $version, $notes, $assets)
	Local $form = GUICreate('GitUpdater', 520, 520)
	Local $lblTitle = GUICtrlCreateLabel(T('The configured file name was not found in this release.', '该 Release 中没有配置的文件名。'), 8, 10, 496, 17)
	Local $lblQuestion = GUICtrlCreateLabel(T('Download the closest file instead?', '是否下载名称最接近的文件？'), 8, 32, 496, 17)
	Local $lblVersion = GUICtrlCreateLabel(T('Available: ', '可用版本：') & $version, 8, 58, 496, 17)
	Local $lblConfigured = GUICtrlCreateLabel(T('Configured file: ', '配置的文件：') & $configured, 8, 80, 496, 17)
	Local $lblResolved = GUICtrlCreateLabel(T('Looked for: ', '查找的文件：') & $resolved, 8, 102, 496, 17)
	Local $lblMatched = GUICtrlCreateLabel(T('Closest file: ', '最接近的文件：') & $matched, 8, 124, 496, 17)
	Local $lblScore = GUICtrlCreateLabel(T('Similarity: ', '相似度：') & Round($score) & ' %', 8, 146, 496, 17)
	Local $lblFiles = GUICtrlCreateLabel(T('Available files:', '可用文件：'), 8, 174, 496, 17)
	Local $editFiles = GUICtrlCreateEdit(BuildAssetList($assets), 8, 196, 496, 248, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_AUTOHSCROLL, $ES_READONLY, $ES_WANTRETURN, $WS_HSCROLL, $WS_VSCROLL))
	Local $btnYes = GUICtrlCreateButton($g_tYesButton, 416, 460, 80, 25, $WS_GROUP)
	Local $btnNo = GUICtrlCreateButton($g_tNoButton, 330, 460, 80, 25, $WS_GROUP)
	Local $msg = 0

	GUICtrlSetColor($lblQuestion, 0x0000AA)
	GUICtrlSetTip($lblMatched, $matched)
	GUICtrlSetState($btnYes, $GUI_FOCUS)
	GUISetState(@SW_SHOW, $form)
	WinActivate($form)

	While True
		$msg = GUIGetMsg()
		If $msg <> 0 Then
			Switch $msg
				Case $GUI_EVENT_CLOSE, $btnNo
					GUIDelete($form)
					Return False
				Case $btnYes
					GUIDelete($form)
					Return True
			EndSwitch
		EndIf
	WEnd
EndFunc

Func BuildAssetList($assets)
	Local $result = ''
	Local $i = 0
	For $i = 0 To UBound($assets) - 1
		$result &= '  - ' & $assets[$i][0] & @CRLF
	Next
	Return $result
EndFunc

Func PrepareNotes($notes)
	If $notes = '' Then $notes = T('(No release notes)', '(没有更新说明)')
	$notes = StringRegExpReplace($notes, "\r?\n", @CRLF)
	If StringLen($notes) > 50000 Then $notes = StringLeft($notes, 50000) & @CRLF & '...'
	Return $notes
EndFunc

Func WaitForStatusClose()
	Local $msg = 0
	While True
		$msg = GUIGetMsg()
		If $msg <> 0 Then
			If $msg = $GUI_EVENT_CLOSE Or $msg = $g_statusCloseButton Then Return
		EndIf
	WEnd
EndFunc

Func ShowNoUpdate($tag)
	Local $form = GUICreate('GitUpdater', 420, 170)
	Local $lblTitle = GUICtrlCreateLabel(T('You already have the latest version.', '当前已是最新版本。'), 16, 20, 388, 17)
	Local $lblVersion = GUICtrlCreateLabel(T('Latest version: ', '最新版本：') & $tag, 16, 52, 388, 17)
	Local $btnClose = GUICtrlCreateButton($g_tCloseButton, 170, 110, 80, 25, $WS_GROUP)
	Local $msg = 0

	GUICtrlSetState($btnClose, $GUI_FOCUS)
	GUISetState(@SW_SHOW, $form)
	WinActivate($form)

	While True
		$msg = GUIGetMsg()
		If $msg <> 0 Then
			If $msg = $GUI_EVENT_CLOSE Or $msg = $btnClose Then
				GUIDelete($form)
				Return
			EndIf
		EndIf
	WEnd
EndFunc

Func SaveSettings()
	IniWrite($g_iniFile, 'General', 'Update', $g_update)
	IniWrite($g_iniFile, 'General', 'UpdateOnceADay', $g_onceADay)
	IniWrite($g_iniFile, 'General', 'LogFile', $g_logFile)

	IniWrite($g_iniFile, 'Internet', 'SoftwareUrl', $g_softwareUrl)
	IniWrite($g_iniFile, 'Internet', 'AssetFile', $g_assetFile)
	IniWrite($g_iniFile, 'Internet', 'UserAgent', $g_userAgent)
	IniWrite($g_iniFile, 'Internet', 'DownloadRetries', $g_downloadRetries)

	IniWrite($g_iniFile, 'Extract', 'StripRootFolder', $g_stripRoot)
	IniWrite($g_iniFile, 'Extract', 'DeleteDownloadedFiles', $g_deleteDownloaded)

	IniWrite($g_iniFile, 'Error', 'SupressInetRead', $g_suppressErrors)
	IniWrite($g_iniFile, 'Meta', 'ConfigVersion', '1')
	LogW('Settings written to: ' & $g_iniFile)
EndFunc

Func LoadSettings()
	$g_update = IniRead($g_iniFile, 'General', 'Update', $g_update)
	$g_onceADay = IniRead($g_iniFile, 'General', 'UpdateOnceADay', $g_onceADay)
	$g_logFile = IniRead($g_iniFile, 'General', 'LogFile', $g_logFile)

	$g_softwareUrl = IniRead($g_iniFile, 'Internet', 'SoftwareUrl', $g_softwareUrl)
	$g_assetFile = IniRead($g_iniFile, 'Internet', 'AssetFile', $g_assetFile)
	$g_userAgent = IniRead($g_iniFile, 'Internet', 'UserAgent', $g_userAgent)
	$g_downloadRetries = Int(IniRead($g_iniFile, 'Internet', 'DownloadRetries', $g_downloadRetries))
	If $g_downloadRetries < 0 Then $g_downloadRetries = 0

	$g_stripRoot = IniRead($g_iniFile, 'Extract', 'StripRootFolder', $g_stripRoot)
	$g_deleteDownloaded = IniRead($g_iniFile, 'Extract', 'DeleteDownloadedFiles', $g_deleteDownloaded)

	$g_suppressErrors = IniRead($g_iniFile, 'Error', 'SupressInetRead', $g_suppressErrors)

	If $g_userAgent = '' Then $g_userAgent = 'GitUpdater/1.0'
	LogW('Settings loaded from: ' & $g_iniFile)
EndFunc

Func SetLanguage()
	Local $lang = @MUILang
	If $lang = '' Then $lang = @OSLang

	$g_lang = 'en'
	If StringInStr('|0804|1004|0404|0C04|1404|', '|' & $lang & '|') Then $g_lang = 'zh'

	$g_tOKButton = T('&Ok', '确定(&O)')
	$g_tCancelButton = T('&Cancel', '取消(&C)')
	$g_tYesButton = T('&Yes', '是(&Y)')
	$g_tNoButton = T('&No', '否(&N)')
	$g_tCloseButton = T('&Close', '关闭(&C)')
	$g_tStatusFormTitle = T('GitUpdater Status', 'GitUpdater 状态')
	$g_tStatusDownloadLabel = T('Downloading', '正在下载')
	$g_tStatusCompleteLabel = T('Complete', '完成')
	$g_tStatusExtractLabel = T('Extracting', '正在解压')
	$g_tStatusChangelogLabel = T('Release notes', '更新说明')
	$g_tUpdateCompleteLabel = T('Update complete', '更新完成')
	$g_tDownloadCompleteLabel = T('Download complete', '下载完成')
	$g_tColon = T(': ', '：')
EndFunc

Func T($en, $zh)
	If $g_lang = 'zh' Then Return $zh
	Return $en
EndFunc

; ---------------------------------------------------------------------------
; GitHub release handling
; ---------------------------------------------------------------------------
Func FetchRelease()
	Local $apiBase = GetApiBase($g_softwareUrl)
	Local $url = ''
	Local $json = ''
	Local $err = 0
	Local $ext = 0
	If $apiBase = '' Then
		LogW('[ERROR] Invalid GitHub repository: ' & $g_softwareUrl)
		Return SetError(1, 0, '')
	EndIf

	; Take the first entry of the public Releases list. This follows the
	; "Releases" page (including pre-releases), instead of /releases/latest
	; which only returns stable releases.
	$url = $apiBase & '/releases?per_page=1'

	LogW('GitHub API: ' & $url)
	$json = HttpGet($url)
	$err = @error
	$ext = @extended
	If $err Then
		LogW('[ERROR] GitHub API request failed, @error=' & $err & ', HTTP=' & $ext)
		Return SetError(2, $ext, '')
	EndIf
	Return $json
EndFunc

Func GetApiBase($url)
	Local $s = StringStripWS($url, 3)
	Local $m = 0
	If $s = '' Then Return ''
	$s = StringRegExpReplace($s, '/+$', '')

	$m = StringRegExp($s, '(?i)^https?://(?:www\.)?github\.com/([^/]+)/([^/#?]+)', 1)
	If Not @error Then Return 'https://api.github.com/repos/' & $m[0] & '/' & StringRegExpReplace($m[1], '(?i)\.git$', '')

	$m = StringRegExp($s, '(?i)^https?://api\.github\.com/repos/([^/]+)/([^/#?]+)', 1)
	If Not @error Then Return 'https://api.github.com/repos/' & $m[0] & '/' & StringRegExpReplace($m[1], '(?i)\.git$', '')

	$m = StringRegExp($s, '^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$', 1)
	If Not @error Then Return 'https://api.github.com/repos/' & $m[0] & '/' & StringRegExpReplace($m[1], '(?i)\.git$', '')

	Return ''
EndFunc

Func GetProcessName($url)
	Local $base = GetApiBase($url)
	Local $parts = 0
	Local $repo = ''
	If $base = '' Then Return ''

	$parts = StringSplit($base, '/')
	If $parts[0] < 1 Then Return ''
	$repo = $parts[$parts[0]]
	If $repo = '' Then Return ''
	Return $repo & '.exe'
EndFunc

Func HttpGet($url)
	Local $oHttp = ObjCreate('WinHttp.WinHttpRequest.5.1')
	Local $status = 0
	Local $text = ''
	If Not IsObj($oHttp) Then
		LogW('[ERROR] Could not create WinHttp.WinHttpRequest.5.1')
		Return SetError(1, 0, '')
	EndIf

	$oHttp.Open('GET', $url, False)
	$oHttp.SetTimeouts(0, 30000, 30000, 60000)
	$oHttp.SetRequestHeader('User-Agent', $g_userAgent)
	$oHttp.SetRequestHeader('Accept', 'application/vnd.github+json')
	If $g_apiToken <> '' Then $oHttp.SetRequestHeader('Authorization', 'Bearer ' & $g_apiToken)
	$oHttp.Send()

	$status = $oHttp.Status
	$text = $oHttp.ResponseText
	If $status < 200 Or $status >= 300 Then
		LogW('[ERROR] HTTP ' & $status & ': ' & $url)
		If $text <> '' Then LogW('HTTP response: ' & StringLeft($text, 1000))
		Return SetError(2, $status, '')
	EndIf
	Return $text
EndFunc

Func JsonGetString($json, $key)
	Local $needle = '"' & $key & '"'
	Local $pos = StringInStr($json, $needle)
	Local $i = 0
	Local $len = StringLen($json)
	Local $c = ''
	Local $start = 0
	If $pos = 0 Then Return ''

	$i = $pos + StringLen($needle)
	While $i <= $len
		$c = StringMid($json, $i, 1)
		If $c = ' ' Or $c = @TAB Or $c = @CR Or $c = @LF Then
			$i += 1
		Else
			ExitLoop
		EndIf
	WEnd
	If $i > $len Or StringMid($json, $i, 1) <> ':' Then Return ''

	$i += 1
	While $i <= $len
		$c = StringMid($json, $i, 1)
		If $c = ' ' Or $c = @TAB Or $c = @CR Or $c = @LF Then
			$i += 1
		Else
			ExitLoop
		EndIf
	WEnd
	If $i > $len Or StringMid($json, $i, 1) <> '"' Then Return ''

	$i += 1
	$start = $i
	While $i <= $len
		$c = StringMid($json, $i, 1)
		If $c = '\' Then
			$i += 2
		ElseIf $c = '"' Then
			Return JsonUnescape(StringMid($json, $start, $i - $start))
		Else
			$i += 1
		EndIf
	WEnd
	Return ''
EndFunc

Func ExtractJsonArray($json, $key)
	Local $needle = '"' & $key & '"'
	Local $pos = StringInStr($json, $needle)
	Local $start = 0
	Local $depth = 0
	Local $inStr = False
	Local $esc = False
	Local $i = 0
	Local $c = ''
	If $pos = 0 Then Return ''

	$start = StringInStr($json, '[', 1, 1, $pos + StringLen($needle))
	If $start = 0 Then Return ''

	For $i = $start To StringLen($json)
		$c = StringMid($json, $i, 1)
		If $inStr Then
			If $esc Then
				$esc = False
			ElseIf $c = '\' Then
				$esc = True
			ElseIf $c = '"' Then
				$inStr = False
			EndIf
		Else
			If $c = '"' Then
				$inStr = True
			ElseIf $c = '[' Then
				$depth += 1
			ElseIf $c = ']' Then
				$depth -= 1
				If $depth = 0 Then Return StringMid($json, $start, $i - $start + 1)
			EndIf
		EndIf
	Next
	Return ''
EndFunc

Func ParseAssets($json)
	Local $result[0][3]
	Local $arr = ExtractJsonArray($json, 'assets')
	Local $names = 0
	Local $urls = 0
	Local $sizes = 0
	Local $hasSizes = False
	Local $i = 0
	Local $size = 0
	If $arr = '' Then Return $result

	$names = StringRegExp($arr, '"name"\s*:\s*"((?:\\.|[^"\\])*)"', $STR_REGEXPARRAYGLOBALMATCH)
	If @error Then Return $result
	$urls = StringRegExp($arr, '"browser_download_url"\s*:\s*"((?:\\.|[^"\\])*)"', $STR_REGEXPARRAYGLOBALMATCH)
	If @error Then Return $result
	$sizes = StringRegExp($arr, '"size"\s*:\s*(\d+)', $STR_REGEXPARRAYGLOBALMATCH)
	$hasSizes = Not @error

	For $i = 0 To UBound($names) - 1
		If $i >= UBound($urls) Then ExitLoop
		$size = 0
		If $hasSizes Then
			If $i < UBound($sizes) Then $size = Number($sizes[$i])
		EndIf
		ReDim $result[UBound($result) + 1][3]
		$result[UBound($result) - 1][0] = JsonUnescape($names[$i])
		$result[UBound($result) - 1][1] = JsonUnescape($urls[$i])
		$result[UBound($result) - 1][2] = $size
	Next
	Return $result
EndFunc

Func ResolveAssetName($pattern, $tag)
	Local $ver = StringRegExpReplace($tag, '^[vV]', '')
	$pattern = StringReplace($pattern, '[$ver]', $ver)
	$pattern = StringReplace($pattern, '[$tag]', $tag)
	Return $pattern
EndFunc

Func PickAsset($assets, $assetFile)
	Local $i = 0
	Local $wanted = ''
	If UBound($assets) = 0 Then Return -1
	If $assetFile = '' Then Return 0

	$wanted = StringLower(StringStripWS($assetFile, 3))
	For $i = 0 To UBound($assets) - 1
		If StringLower(StringStripWS($assets[$i][0], 3)) = $wanted Then Return $i
	Next
	Return -1
EndFunc

; Find the asset whose name is closest to $assetFile. Returns the index or -1
; when even the best candidate is not similar enough. $bestScore receives the
; similarity in percent (0-100). Files with a different extension are skipped
; so a .zip request never matches an .exe by accident.
Func FindClosestAsset($assets, $assetFile, ByRef $bestScore)
	Local $i = 0
	Local $ext = GetFileExt($assetFile)
	Local $score = 0
	Local $idx = -1
	$bestScore = 0
	If UBound($assets) = 0 Then Return -1

	For $i = 0 To UBound($assets) - 1
		If $ext <> '' And GetFileExt($assets[$i][0]) <> $ext Then ContinueLoop
		$score = NameSimilarity($assetFile, $assets[$i][0])
		If $score > $bestScore Then
			$bestScore = $score
			$idx = $i
		EndIf
	Next

	If $idx = -1 Or $bestScore < 70 Then Return -1
	Return $idx
EndFunc

Func GetFileExt($name)
	Local $m = StringRegExp($name, '\.([^.\\/]+)$', 1)
	If @error Then Return ''
	Return StringLower($m[0])
EndFunc

Func NameSimilarity($a, $b)
	Local $s = StringLower(StringStripWS($a, 3))
	Local $t = StringLower(StringStripWS($b, 3))
	Local $maxLen = StringLen($s)
	If StringLen($t) > $maxLen Then $maxLen = StringLen($t)
	If $maxLen = 0 Then Return 100
	Return (1 - Levenshtein($s, $t) / $maxLen) * 100
EndFunc

Func Levenshtein($s, $t)
	Local $n = StringLen($s)
	Local $m = StringLen($t)
	Local $i = 0, $j = 0, $cost = 0
	Local $ca = '', $cb = ''
	If $n = 0 Then Return $m
	If $m = 0 Then Return $n

	Local $prev[$m + 1]
	Local $cur[$m + 1]
	For $j = 0 To $m
		$prev[$j] = $j
	Next
	For $i = 1 To $n
		$cur[0] = $i
		$ca = StringMid($s, $i, 1)
		For $j = 1 To $m
			$cb = StringMid($t, $j, 1)
			If $ca = $cb Then
				$cost = 0
			Else
				$cost = 1
			EndIf
			$cur[$j] = Min3($prev[$j] + 1, $cur[$j - 1] + 1, $prev[$j - 1] + $cost)
		Next
		For $j = 0 To $m
			$prev[$j] = $cur[$j]
		Next
	Next
	Return $prev[$m]
EndFunc

Func Min3($a, $b, $c)
	Local $r = $a
	If $b < $r Then $r = $b
	If $c < $r Then $r = $c
	Return $r
EndFunc

Func JsonUnescape($s)
	Local $out = ''
	Local $i = 1
	Local $len = StringLen($s)
	Local $c = ''
	Local $n = ''
	Local $hex = ''
	While $i <= $len
		$c = StringMid($s, $i, 1)
		If $c = '\' And $i < $len Then
			$n = StringMid($s, $i + 1, 1)
			Switch $n
				Case 'n'
					$out &= @LF
					$i += 2
				Case 'r'
					$out &= @CR
					$i += 2
				Case 't'
					$out &= @TAB
					$i += 2
				Case '"'
					$out &= '"'
					$i += 2
				Case '\'
					$out &= '\'
					$i += 2
				Case '/'
					$out &= '/'
					$i += 2
				Case 'u'
					$hex = StringMid($s, $i + 2, 4)
					If StringLen($hex) = 4 And StringRegExp($hex, '^[0-9A-Fa-f]{4}$') Then
						$out &= ChrW(Dec($hex))
						$i += 6
					Else
						$out &= $c
						$i += 1
					EndIf
				Case Else
					$out &= $c
					$i += 1
			EndSwitch
		Else
			$out &= $c
			$i += 1
		EndIf
	WEnd
	Return $out
EndFunc

; ---------------------------------------------------------------------------
; Download and installation
; ---------------------------------------------------------------------------
Func DownloadAsset($assetUrl, $assetSize, $tag, $releaseBody)
	Local $remoteSize = $assetSize
	Local $hDownload = 0
	Local $lastComplete = -1
	Local $downloadedBytes = 0
	Local $completed = 0
	Local $msg = 0
	Local $downloadError = 0
	Local $changelogText = PrepareNotes($releaseBody)
	Local $versionLabel = 0
	Local $changelogLabel = 0
	Local $changelogEdit = 0
	Local $attempt = 0
	Local $maxAttempts = 1
	Local $success = False

	$changelogText = PrepareNotes($releaseBody)

	If $remoteSize <= 0 Then
		$remoteSize = InetGetSize($assetUrl, 1)
		If @error Then $remoteSize = 0
	EndIf

	$g_statusForm = GUICreate($g_tStatusFormTitle, 520, 440)
	$g_statusDescription = GUICtrlCreateLabel($g_tStatusDownloadLabel & $g_tColon, 8, 8, 110, 17)
	$versionLabel = GUICtrlCreateLabel($tag, 120, 8, 384, 17)
	$g_statusCompleteLabel = GUICtrlCreateLabel($g_tStatusCompleteLabel & $g_tColon, 8, 32, 110, 17)
	$g_statusCompleteValue = GUICtrlCreateLabel('0 %', 120, 32, 384, 17)
	$changelogLabel = GUICtrlCreateLabel($g_tStatusChangelogLabel & $g_tColon, 8, 56, 110, 17)
	$changelogEdit = GUICtrlCreateEdit($changelogText, 8, 80, 496, 315, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_AUTOHSCROLL, $ES_READONLY, $ES_WANTRETURN, $WS_HSCROLL, $WS_VSCROLL))
	$g_statusCloseButton = GUICtrlCreateButton($g_tCancelButton, 220, 405, 80, 25, $WS_GROUP)
	GUISetState(@SW_SHOW, $g_statusForm)

	LogW('Downloading: ' & $assetUrl)
	LogW('Destination: ' & $g_downloadFile)

	$maxAttempts = $g_downloadRetries + 1
	For $attempt = 1 To $maxAttempts
		If $attempt > 1 Then
			LogW('Retrying download (' & $attempt & '/' & $maxAttempts & ')')
			GUICtrlSetData($g_statusDescription, $g_tStatusDownloadLabel & StringFormat(T(' (retry %d): ', '（重试 %d）：'), $attempt - 1))
			GUICtrlSetData($g_statusCompleteValue, '0 %')
			Sleep(2000)
		EndIf

		If FileExists($g_downloadFile) Then
			FileSetAttrib($g_downloadFile, '-R')
			FileDelete($g_downloadFile)
		EndIf

		$lastComplete = -1
		$downloadError = 0
		$hDownload = InetGet($assetUrl, $g_downloadFile, 1, 1)
		If $hDownload = 0 Then
			LogW('[ERROR] InetGet failed, @error=' & @error)
			$downloadError = -1
		Else
			Do
				$downloadedBytes = InetGetInfo($hDownload, 0)
				$completed = 0
				If $remoteSize > 0 Then
					$completed = Round($downloadedBytes / $remoteSize * 100)
					If $completed > 100 Then $completed = 100
				Else
					$completed = -1
				EndIf

				If $completed <> $lastComplete Then
					If $completed >= 0 Then
						GUICtrlSetData($g_statusCompleteValue, $completed & ' %')
					Else
						GUICtrlSetData($g_statusCompleteValue, Round($downloadedBytes / 1048576, 1) & ' MB')
					EndIf
					$lastComplete = $completed
				EndIf

				$msg = GUIGetMsg()
				If $msg <> 0 Then
					Switch $msg
						Case $GUI_EVENT_CLOSE, $g_statusCloseButton
							LogW('Download canceled')
							InetClose($hDownload)
							GUIDelete($g_statusForm)
							$g_statusForm = 0
							CleanUpDownload(True)
							okExit()
							Return False
					EndSwitch
				EndIf
				Sleep(100)
			Until InetGetInfo($hDownload, 2)

			$downloadError = InetGetInfo($hDownload, 4)
			InetClose($hDownload)
		EndIf

		If $downloadError = 0 And FileExists($g_downloadFile) And FileGetSize($g_downloadFile) > 0 Then
			$success = True
			ExitLoop
		EndIf

		If $downloadError = 0 Then $downloadError = -2
		LogW('[ERROR] Download attempt ' & $attempt & ' failed, error=' & $downloadError)
	Next

	If Not $success Then
		GUIDelete($g_statusForm)
		$g_statusForm = 0
		CleanUpDownload(True)
		FatalError(T('Could not download the release asset:', '无法下载 Release 资源：') & @CRLF & $assetUrl & @CRLF & @CRLF & T('Error code: ', '错误代码：') & $downloadError & @CRLF & T('Attempts: ', '尝试次数：') & $maxAttempts)
		Return False
	EndIf

	GUICtrlSetData($g_statusDescription, $g_tStatusDownloadLabel & $g_tColon)
	GUICtrlSetData($g_statusCompleteValue, '100 %')
	LogW('Download complete: ' & $g_downloadFile)
	Return True
EndFunc

Func ProcessDownload($archive, $destDir)
	Local $tmpDir = $destDir & '.gitupdater_tmp'
	Local $kind = GetArchiveKind($archive)
	Local $cmd = ''
	Local $rc = 0
	Local $srcDir = ''
	Local $root = ''
	Local $copyOk = False
	Local $sevenZip = ''

	$g_didProcess = False

	If Not FileExists($archive) Then
		LogW('[ERROR] File not found: ' & $archive)
		Return False
	EndIf

	If $kind = '' Then
		LogW('Download only: unsupported archive format for ' & $archive)
		Return True
	EndIf

	DirRemove($tmpDir, 1)
	If Not DirCreate($tmpDir) Then
		LogW('[ERROR] Could not create temp folder: ' & $tmpDir)
		Return False
	EndIf

	Switch $kind
		Case 'zip'
			$cmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command ""Expand-Archive -LiteralPath '" & $archive & "' -DestinationPath '" & $tmpDir & "' -Force"""
		Case '7z', 'rar'
			$sevenZip = Find7Zip()
			If $sevenZip <> '' Then
				$cmd = '"' & $sevenZip & '" x -y -o"' & $tmpDir & '" "' & $archive & '"'
			Else
				LogW('[WARN] 7-Zip not found, trying tar for ' & $kind)
				$cmd = 'tar -xf "' & $archive & '" -C "' & $tmpDir & '"'
			EndIf
		Case Else
			$cmd = 'tar -xf "' & $archive & '" -C "' & $tmpDir & '"'
	EndSwitch

	LogW('Extracting (' & $kind & '): ' & $cmd)
	$rc = RunWait($cmd, $destDir, @SW_HIDE)
	If @error <> 0 Or $rc <> 0 Then
		LogW('[ERROR] Extraction failed, @error=' & @error & ', exit code=' & $rc)
		DirRemove($tmpDir, 1)
		Return False
	EndIf

	$srcDir = $tmpDir
	If $g_stripRoot = 'yes' Then
		$root = FindSingleRoot($tmpDir)
		If $root <> '' Then $srcDir = $root
	EndIf

	LogW('Copying extracted files: ' & $srcDir & ' -> ' & $destDir)
	$copyOk = CopyTree($srcDir, $destDir)
	If Not $copyOk Then
		LogW('[ERROR] Some files could not be copied. Temporary folder kept: ' & $tmpDir)
		Return False
	EndIf

	DirRemove($tmpDir, 1)
	$g_didProcess = True
	Return True
EndFunc

Func GetArchiveKind($fileName)
	Local $s = StringLower($fileName)
	If StringRight($s, 4) = '.zip' Then Return 'zip'
	If StringRight($s, 3) = '.7z' Then Return '7z'
	If StringRight($s, 4) = '.rar' Then Return 'rar'
	If StringRight($s, 7) = '.tar.gz' Then Return 'tar'
	If StringRight($s, 8) = '.tar.bz2' Then Return 'tar'
	If StringRight($s, 8) = '.tar.zst' Then Return 'tar'
	If StringRight($s, 7) = '.tar.xz' Then Return 'tar'
	If StringRight($s, 4) = '.tar' Then Return 'tar'
	If StringRight($s, 4) = '.tgz' Then Return 'tar'
	If StringRight($s, 5) = '.tbz2' Then Return 'tar'
	If StringRight($s, 4) = '.tbz' Then Return 'tar'
	If StringRight($s, 4) = '.txz' Then Return 'tar'
	Return ''
EndFunc

Func Find7Zip()
	Local $candidates[3]
	Local $i = 0
	Local $tmp = @TempDir & '\gitupdater_where7z.txt'
	Local $line = ''

	$candidates[0] = EnvGet('ProgramFiles') & '\7-Zip\7z.exe'
	$candidates[1] = EnvGet('ProgramFiles(x86)') & '\7-Zip\7z.exe'
	$candidates[2] = @ProgramFilesDir & '\7-Zip\7z.exe'
	For $i = 0 To UBound($candidates) - 1
		If $candidates[$i] <> '\7-Zip\7z.exe' And FileExists($candidates[$i]) Then Return $candidates[$i]
	Next

	FileDelete($tmp)
	RunWait(@ComSpec & ' /c where 7z.exe > "' & $tmp & '" 2>nul', '', @SW_HIDE)
	If FileExists($tmp) Then
		$line = FileReadLine($tmp, 1)
		FileDelete($tmp)
		If $line <> '' And FileExists($line) Then Return $line
	EndIf

	Return ''
EndFunc

Func CopyTree($srcDir, $dstDir)
	Local $hFind = FileFindFirstFile($srcDir & '\*')
	Local $ok = True
	Local $name = ''
	Local $src = ''
	Local $dst = ''
	If $hFind = -1 Then Return True

	While True
		$name = FileFindNextFile($hFind)
		If @error Then ExitLoop
		$src = $srcDir & '\' & $name
		$dst = $dstDir & '\' & $name
		If @extended Then
			If Not DirCreate($dst) And Not FolderExists($dst) Then
				LogW('[WARN] Could not create folder: ' & $dst)
				$ok = False
			EndIf
			If Not CopyTree($src, $dst) Then $ok = False
		Else
			If FileExists($dst) Then FileSetAttrib($dst, '-R')
			If Not FileCopy($src, $dst, 9) Then
				LogW('[WARN] Could not copy file: ' & $src & ' -> ' & $dst)
				$ok = False
			EndIf
		EndIf
	WEnd
	FileClose($hFind)
	Return $ok
EndFunc

Func FindSingleRoot($dir)
	Local $hFind = FileFindFirstFile($dir & '\*')
	Local $name = ''
	Local $name2 = ''
	Local $isDir = 0
	Local $more = False
	If $hFind = -1 Then Return ''

	$name = FileFindNextFile($hFind)
	If @error Then
		FileClose($hFind)
		Return ''
	EndIf
	$isDir = @extended

	$name2 = FileFindNextFile($hFind)
	$more = Not @error
	FileClose($hFind)

	If $more Then Return ''
	If $isDir And $name <> '' Then Return $dir & '\' & $name
	Return ''
EndFunc

Func CleanUpDownload($force = False)
	If $g_downloadFile = '' Then Return

	If $force Or ($g_deleteDownloaded = 'yes' And $g_didProcess) Then
		If FileExists($g_downloadFile) Then
			LogW('Removing downloaded file: ' & $g_downloadFile)
			FileSetAttrib($g_downloadFile, '-R')
			FileDelete($g_downloadFile)
		EndIf
	Else
		LogW('Keeping downloaded file: ' & $g_downloadFile)
	EndIf
EndFunc

Func IsDirWritable($dir)
	Local $test = $dir & '.gitupdater_write_test.tmp'
	Local $h = FileOpen($test, 2)
	If $h = -1 Then Return False
	FileClose($h)
	FileDelete($test)
	Return True
EndFunc

; ---------------------------------------------------------------------------
; Logging and small helpers
; ---------------------------------------------------------------------------
Func LogW($msg)
	Local $path = ''
	Local $parent = ''
	If $g_logFile = '' Then Return
	$path = ResolveFile($g_logFile)
	If $path = '' Then Return
	$parent = StringRegExpReplace($path, '\\[^\\]+$', '')
	If $parent <> '' And Not FolderExists($parent) Then DirCreate($parent)
	_FileWriteLog($path, $msg)
EndFunc

Func okExit()
	LogW('******** Exiting script ********')
	Exit
EndFunc

Func CancelExit()
	LogW('******** Exiting script ********')
	Exit
EndFunc

Func FatalError($msg)
	LogW('[ERROR] ' & $msg)
	MsgBox($MB_ICONERROR, 'GitUpdater', $msg)
EndFunc

Func NetworkError($msg)
	LogW('[ERROR] ' & $msg)
	If $g_suppressErrors <> 'yes' Then MsgBox($MB_ICONERROR, 'GitUpdater', $msg)
EndFunc

Func ResolveFile($path)
	If $path = '' Then Return ''
	$path = StringReplace($path, '@ScriptDir', $g_workingDir)
	Return _PathFull($path, $g_workingDir)
EndFunc

Func ResolveDir($path)
	Local $full = ''
	If $path = '' Then Return $g_workingDir
	$path = StringReplace($path, '@ScriptDir', $g_workingDir)
	$full = _PathFull($path, $g_workingDir)
	If StringRight($full, 1) <> '\' Then $full &= '\'
	Return $full
EndFunc

Func FolderExists($path)
	If Not FileExists($path) Then Return False
	Return StringInStr(FileGetAttrib($path), 'D') > 0
EndFunc

Func IsTargetRunning($targetExe)
	Local $oWmi = 0
	Local $col = 0
	Local $proc = 0
	Local $name = ''
	Local $path = ''
	If $targetExe = '' Then Return False

	$oWmi = ObjGet('winmgmts:\\.\root\cimv2')
	If Not IsObj($oWmi) Then
		If $g_processName <> '' Then Return ProcessExists($g_processName)
		Return False
	EndIf

	$name = StringRegExpReplace($g_processName, "'", "''")
	$col = $oWmi.ExecQuery("SELECT ProcessId, ExecutablePath FROM Win32_Process WHERE Name = '" & $name & "'")
	If Not IsObj($col) Then Return False

	For $proc In $col
		$path = $proc.ExecutablePath
		If $path <> '' Then
			If StringLower($path) = StringLower($targetExe) Then Return True
		EndIf
	Next
	Return False
EndFunc

Func ComErrorHandler()
	; Swallow COM errors. HttpGet checks the HTTP status explicitly.
EndFunc
