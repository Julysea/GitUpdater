#include-once
; ---------------------------------------------------------------------------
; Asset download
; ---------------------------------------------------------------------------
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>

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

	$g_statusForm = GUICreate($g_tStatusFormTitle & ' - ' & GetSoftwareName($g_softwareUrl), 520, 440)
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

