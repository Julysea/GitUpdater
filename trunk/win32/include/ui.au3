#include-once
; ---------------------------------------------------------------------------
; Windows and dialogs
; ---------------------------------------------------------------------------
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <ComboConstants.au3>

Func CheckboxValue($ctrl)
	If GUICtrlRead($ctrl) = $GUI_CHECKED Then Return 'yes'
	Return 'no'
EndFunc

Func PrepareNotes($notes)
	If $notes = '' Then $notes = T('(No release notes)', '(没有更新说明)')
	$notes = StringRegExpReplace($notes, "\r?\n", @CRLF)
	If StringLen($notes) > 50000 Then $notes = StringLeft($notes, 50000) & @CRLF & '...'
	Return $notes
EndFunc

Func BuildAssetList($assets)
	Local $result = ''
	Local $i = 0
	For $i = 0 To UBound($assets) - 1
		$result &= '  - ' & $assets[$i][0] & @CRLF
	Next
	Return $result
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

; $mode = 'initial'  : first run or --settings. The caller exits on 'cancel'.
;         'redefine' : opened from a previous window. The caller returns to it
;                      on 'cancel' and restarts the check on 'ok'.
; The dialog always has two buttons: 确定 saves and returns 'ok',
; 取消 / close discards and returns 'cancel'. Values are only applied on 'ok'.
Func ShowSettings($mode = 'initial')
	Local $form = GUICreate(T('GitUpdater Settings', 'GitUpdater 设置'), 520, 520)
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
	Local $lblBinPath = GUICtrlCreateLabel(T('Extract path in archive (empty = all):', '指定释放内容路径（默认为空，表示全部）：'), 8, 284, 496, 17)
	Local $edtBinPath = GUICtrlCreateInput($g_binPath, 8, 304, 496, 21)
	Local $lblArchiveHint = GUICtrlCreateLabel(T('Archives: extract automatically; other formats: download only.', '压缩包会自动解压升级；其他格式只下载，不处理。'), 8, 334, 496, 17)
	Local $lblArchiveFormats = GUICtrlCreateLabel(T('Supported: zip, 7z, rar, tar, tar.gz, tar.bz2, tar.xz', '支持：zip、7z、rar、tar、tar.gz、tar.bz2、tar.xz'), 8, 354, 496, 17)
	Local $lblLog = GUICtrlCreateLabel(T('Log file:', '日志文件：'), 8, 384, 496, 17)
	Local $edtLog = GUICtrlCreateInput($g_logFile, 8, 404, 496, 21)
	Local $btnOk = GUICtrlCreateButton($g_tOKButton, 416, 460, 80, 25, $WS_GROUP)
	Local $btnCancel = GUICtrlCreateButton($g_tCancelButton, 330, 460, 80, 25, $WS_GROUP)
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

	LogW('Settings opened: ' & $mode)
	GUISetState(@SW_SHOW, $form)
	While True
		$msg = GUIGetMsg()
		If $msg <> 0 Then
			Switch $msg
				Case $GUI_EVENT_CLOSE, $btnCancel
					GUIDelete($form)
					Return 'cancel'
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
	$g_binPath = StringStripWS(GUICtrlRead($edtBinPath), 3)
	$g_logFile = StringStripWS(GUICtrlRead($edtLog), 3)

	If $g_update = '' Then $g_update = 'ask'

	; 确定 = save and return. The caller decides whether to continue or exit.
	SaveSettings()
	GUIDelete($form)
	Return 'ok'
EndFunc

Func ConfirmUpdate($repo, $current, $version, $notes)
	Local $form = GUICreate('GitUpdater - ' & GetSoftwareName($repo), 520, 500)
	Local $lblTitle = GUICtrlCreateLabel(T('A new version is available.', '发现新版本。'), 8, 10, 496, 17)
	Local $lblRepo = GUICtrlCreateLabel(T('Repository: ', '仓库：') & $repo, 8, 36, 496, 17)
	Local $lblCurrent = GUICtrlCreateLabel(T('Installed: ', '当前版本：') & $current, 8, 60, 496, 17)
	Local $lblVersion = GUICtrlCreateLabel(T('Available: ', '可用版本：') & $version, 8, 84, 496, 17)
	Local $lblNotes = GUICtrlCreateLabel(T('Release notes:', '更新内容：'), 8, 112, 496, 17)
	Local $editNotes = GUICtrlCreateEdit(PrepareNotes($notes), 8, 134, 496, 300, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_AUTOHSCROLL, $ES_READONLY, $ES_WANTRETURN, $WS_HSCROLL, $WS_VSCROLL))
	Local $btnSettings = GUICtrlCreateButton($g_tSettingsButton, 202, 450, 120, 25, $WS_GROUP)
	Local $btnYes = GUICtrlCreateButton($g_tYesButton, 416, 450, 80, 25, $WS_GROUP)
	Local $btnNo = GUICtrlCreateButton($g_tNoButton, 330, 450, 80, 25, $WS_GROUP)
	Local $msg = 0

	GUICtrlSetTip($btnSettings, T('Redefine the configuration, then check for updates again', '重新定义配置，然后重新检查更新'))
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
					Return 'yes'
				Case $btnSettings
					GUIDelete($form)
					Return 'settings'
			EndSwitch
		EndIf
	WEnd
EndFunc

Func ConfirmAsset($configured, $resolved, $matched, $score, $version, $notes, $assets)
	Local $form = GUICreate('GitUpdater - ' & GetSoftwareName($g_softwareUrl), 520, 520)
	Local $lblTitle = GUICtrlCreateLabel(T('The configured file name was not found in this release.', '该 Release 中没有配置的文件名。'), 8, 10, 496, 17)
	Local $lblQuestion = GUICtrlCreateLabel(T('Download the closest file instead?', '是否下载名称最接近的文件？'), 8, 32, 496, 17)
	Local $lblVersion = GUICtrlCreateLabel(T('Available: ', '可用版本：') & $version, 8, 58, 496, 17)
	Local $lblConfigured = GUICtrlCreateLabel(T('Configured file: ', '配置的文件：') & $configured, 8, 80, 496, 17)
	Local $lblResolved = GUICtrlCreateLabel(T('Looked for: ', '查找的文件：') & $resolved, 8, 102, 496, 17)
	Local $lblMatched = GUICtrlCreateLabel(T('Closest file: ', '最接近的文件：') & $matched, 8, 124, 496, 17)
	Local $lblScore = GUICtrlCreateLabel(T('Similarity: ', '相似度：') & Round($score) & ' %', 8, 146, 496, 17)
	Local $lblFiles = GUICtrlCreateLabel(T('Available files:', '可用文件：'), 8, 174, 496, 17)
	Local $editFiles = GUICtrlCreateEdit(BuildAssetList($assets), 8, 196, 496, 248, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $ES_AUTOHSCROLL, $ES_READONLY, $ES_WANTRETURN, $WS_HSCROLL, $WS_VSCROLL))
	Local $btnSettings = GUICtrlCreateButton($g_tSettingsButton, 202, 460, 120, 25, $WS_GROUP)
	Local $btnYes = GUICtrlCreateButton($g_tYesButton, 416, 460, 80, 25, $WS_GROUP)
	Local $btnNo = GUICtrlCreateButton($g_tNoButton, 330, 460, 80, 25, $WS_GROUP)
	Local $msg = 0

	GUICtrlSetColor($lblQuestion, 0x0000AA)
	GUICtrlSetTip($lblMatched, $matched)
	GUICtrlSetTip($btnSettings, T('Redefine the asset file name, then check for updates again', '重新定义资源文件名，然后重新检查更新'))
	GUICtrlSetState($btnYes, $GUI_FOCUS)
	GUISetState(@SW_SHOW, $form)
	WinActivate($form)

	While True
		$msg = GUIGetMsg()
		If $msg <> 0 Then
			Switch $msg
				Case $GUI_EVENT_CLOSE, $btnNo
					GUIDelete($form)
					Return 'no'
				Case $btnYes
					GUIDelete($form)
					Return 'yes'
				Case $btnSettings
					GUIDelete($form)
					Return 'settings'
			EndSwitch
		EndIf
	WEnd
EndFunc

; Shows the "already up to date" window. Returns 'close' or 'settings'.
Func ShowNoUpdate($tag)
	Local $form = GUICreate('GitUpdater - ' & GetSoftwareName($g_softwareUrl), 460, 200)
	Local $lblTitle = GUICtrlCreateLabel(T('You already have the latest version.', '当前已是最新版本。'), 16, 20, 428, 17)
	Local $lblVersion = GUICtrlCreateLabel(T('Latest version: ', '最新版本：') & $tag, 16, 52, 428, 17)
	Local $lblHint = GUICtrlCreateLabel(T('Repository or asset changed? Redefine the configuration.', '仓库或资源文件有变化？可以重新定义配置。'), 16, 92, 428, 17)
	Local $btnSettings = GUICtrlCreateButton($g_tSettingsButton, 232, 160, 120, 25, $WS_GROUP)
	Local $btnClose = GUICtrlCreateButton($g_tCloseButton, 364, 160, 80, 25, $WS_GROUP)
	Local $msg = 0

	GUICtrlSetColor($lblHint, 0x666666)
	GUICtrlSetTip($btnSettings, T('Open the settings window and check for updates again', '打开设置窗口，保存后重新检查更新'))
	GUICtrlSetState($btnClose, $GUI_FOCUS)
	GUISetState(@SW_SHOW, $form)
	WinActivate($form)

	While True
		$msg = GUIGetMsg()
		If $msg <> 0 Then
			Switch $msg
				Case $GUI_EVENT_CLOSE, $btnClose
					GUIDelete($form)
					Return 'close'
				Case $btnSettings
					GUIDelete($form)
					Return 'settings'
			EndSwitch
		EndIf
	WEnd
EndFunc

; Opens the settings window from a previous window.
; Returns 'ok' when the values were saved, 'cancel' when they were discarded.
; The caller decides whether to go back to its window or restart the check.
Func RedefineSettings()
	If ShowSettings('redefine') = 'cancel' Then
		LogW('Settings canceled, returning to the previous window')
		Return 'cancel'
	EndIf
	; The configuration may have changed, so ask again on the next check.
	$g_updateApproved = False
	LogW('Configuration saved, returning to the previous window')
	Return 'ok'
EndFunc

