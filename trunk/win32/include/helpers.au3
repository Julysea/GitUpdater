#include-once
; ---------------------------------------------------------------------------
; Path, folder and process helpers
; ---------------------------------------------------------------------------
#include <File.au3>

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

Func IsDirWritable($dir)
	Local $test = $dir & '.gitupdater_write_test.tmp'
	Local $h = FileOpen($test, 2)
	If $h = -1 Then Return False
	FileClose($h)
	FileDelete($test)
	Return True
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

