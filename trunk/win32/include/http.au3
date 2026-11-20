#include-once
; ---------------------------------------------------------------------------
; HTTP client (WinHttp)
; ---------------------------------------------------------------------------
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

Func HttpGetWithSettings($url)
	Local $json = HttpGet($url)
	If @error Then
		; Return error code so caller can decide what to do
		Return SetError(@error, @extended, '')
	EndIf
	Return $json
EndFunc

Func ComErrorHandler()
	; Swallow COM errors. HttpGet checks the HTTP status explicitly.
EndFunc

