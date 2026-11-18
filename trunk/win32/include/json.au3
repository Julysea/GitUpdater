#include-once
; ---------------------------------------------------------------------------
; Minimal JSON reading helpers
; ---------------------------------------------------------------------------
#include <StringConstants.au3>

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

