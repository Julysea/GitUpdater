#include-once
; ---------------------------------------------------------------------------
; Archive extraction and installation
; ---------------------------------------------------------------------------
#include <File.au3>

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

Func ProcessDownload($archive, $destDir, $newTag)
	Local $tmpDir = $destDir & '.gitupdater_tmp'
	Local $kind = GetArchiveKind($archive)
	Local $cmd = ''
	Local $rc = 0
	Local $srcDir = ''
	Local $root = ''
	Local $copyOk = False
	Local $sevenZip = ''
	Local $binDir = ''
	Local $oldDirs = 0
	Local $ver = StringRegExpReplace($newTag, '^[vVMm]', '')

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

	; Locate the configured path inside the extracted archive
	If $g_binPath <> '' Then
		$binDir = FindPathInArchive($tmpDir, $g_binPath)
		If $binDir <> '' Then
			$srcDir = $binDir
			LogW('Using configured path: ' & $binDir)
		Else
			LogW('[WARN] Configured path not found in archive: ' & $g_binPath & ' (extracting all)')
		EndIf
	EndIf
	If $binDir = '' Then
		$srcDir = $tmpDir
		If $g_stripRoot = 'yes' Then
			$root = FindSingleRoot($tmpDir)
			If $root <> '' Then $srcDir = $root
		EndIf
	EndIf

	LogW('Copying extracted files: ' & $srcDir & ' -> ' & $destDir)
	$copyOk = CopyTree($srcDir, $destDir)
	If Not $copyOk Then
		LogW('[ERROR] Some files could not be copied. Temporary folder kept: ' & $tmpDir)
		DirRemove($tmpDir, 1)
		Return False
	EndIf

	; Remove old version directories (directories whose name starts with a version pattern)
	$oldDirs = RemoveOldVersionDirs($destDir, $ver)
	If $oldDirs > 0 Then
		LogW('Removed ' & $oldDirs & ' old version directory(ies)')
	EndIf

	DirRemove($tmpDir, 1)
	$g_didProcess = True
	Return True
EndFunc

; Find the directory at the given path (case-insensitive) inside $dir.
; Supports single-level paths like "BIN" or nested paths like "foo/bar".
; Windows separators and leading/trailing slashes are accepted as well:
; "foo\bar\", "\foo/bar" and "/foo//bar/" all mean "foo/bar".
Func FindPathInArchive($dir, $path)
	Local $parts = 0
	Local $current = $dir
	Local $i = 0

	$path = NormalizeArchivePath($path)
	If $path = '' Then Return ''

	$parts = StringSplit($path, '/', 2)
	For $i = 0 To UBound($parts) - 1
		If $parts[$i] = '' Or $parts[$i] = '.' Then ContinueLoop
		$current = FindChildDir($current, $parts[$i])
		If $current = '' Then Return ''
	Next
	Return $current
EndFunc

; Normalize a user-supplied archive path: trim spaces, treat "\" as "/",
; collapse duplicate separators and drop leading/trailing ones.
Func NormalizeArchivePath($path)
	$path = StringStripWS($path, 3)
	$path = StringReplace($path, '\', '/')
	While StringInStr($path, '//') > 0
		$path = StringReplace($path, '//', '/')
	WEnd
	$path = StringRegExpReplace($path, '^/+', '')
	$path = StringRegExpReplace($path, '/+$', '')
	Return $path
EndFunc

; Find a child directory named $name (case-insensitive) under $parent.
Func FindChildDir($parent, $name)
	Local $hFind = FileFindFirstFile($parent & '\*')
	Local $item = ''
	Local $isDir = 0

	While True
		$item = FileFindNextFile($hFind)
		If @error Then ExitLoop
		$isDir = @extended
		If $isDir And StringCompare($item, $name, 0) = 0 Then
			FileClose($hFind)
			Return $parent & '\' & $item
		EndIf
	WEnd
	FileClose($hFind)
	Return ''
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

; Remove directories in $destDir whose name looks like a version number
; but is NOT the current version. A version directory matches patterns like
; "156.0.8078", "156.0.8078.80", "156.0.8078_80", etc.
Func RemoveOldVersionDirs($destDir, $currentVer)
	Local $count = 0
	Local $hFind = FileFindFirstFile($destDir & '\*')
	Local $name = ''
	Local $isDir = 0
	Local $verPattern = '^\d+\.\d+'

	While True
		$name = FileFindNextFile($hFind)
		If @error Then ExitLoop
		$isDir = @extended
		If Not $isDir Then ContinueLoop

		; Skip if it matches the current version
		If StringInStr($name, $currentVer) > 0 Then ContinueLoop

		; Check if the name looks like a version directory
		If StringRegExp($name, $verPattern) Then
			Local $fullPath = $destDir & '\' & $name
			LogW('Removing old version directory: ' & $fullPath)
			DirRemove($fullPath, 1)
			If @error Then
				LogW('[WARN] Could not remove: ' & $fullPath)
			Else
				$count += 1
			EndIf
		EndIf
	WEnd
	FileClose($hFind)
	Return $count
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

