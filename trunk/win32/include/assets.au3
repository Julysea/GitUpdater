#include-once
; ---------------------------------------------------------------------------
; Release asset name matching
; ---------------------------------------------------------------------------
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

