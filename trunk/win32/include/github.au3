#include-once
; ---------------------------------------------------------------------------
; GitHub repository and release helpers
; ---------------------------------------------------------------------------
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

; Extract the repository name from a GitHub URL, e.g.
; https://github.com/Zoo-Code-Or/Zoo-Code -> Zoo-Code
Func GetSoftwareName($url)
	Local $base = GetApiBase($url)
	Local $parts = 0
	Local $repo = ''
	If $base = '' Then Return ''

	$parts = StringSplit($base, '/')
	If $parts[0] < 1 Then Return ''
	$repo = $parts[$parts[0]]
	Return $repo
EndFunc

Func GetProcessName($url)
	Local $name = GetSoftwareName($url)
	If $name = '' Then Return ''
	Return $name & '.exe'
EndFunc

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

