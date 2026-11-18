#include-once
; ---------------------------------------------------------------------------
; Logging and exit helpers
; ---------------------------------------------------------------------------
#include <File.au3>
#include <MsgBoxConstants.au3>

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

Func FatalError($msg)
	LogW('[ERROR] ' & $msg)
	MsgBox($MB_ICONERROR, 'GitUpdater', $msg)
EndFunc

Func NetworkError($msg)
	LogW('[ERROR] ' & $msg)
	If $g_suppressErrors <> 'yes' Then MsgBox($MB_ICONERROR, 'GitUpdater', $msg)
EndFunc

Func okExit()
	LogW('******** Exiting script ********')
	Exit
EndFunc

Func CancelExit()
	LogW('******** Exiting script ********')
	Exit
EndFunc

