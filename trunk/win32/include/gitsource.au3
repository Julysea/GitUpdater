#include-once
; ---------------------------------------------------------------------------
; Repository URL parsing and release lookup
;
; The release host is detected from the configured URL instead of assuming
; GitHub:
;   GitHub      https://github.com/owner/repo        -> api.github.com
;   Gitea       https://host/owner/repo (Forgejo, Codeberg, self-hosted)
;                                                    -> /api/v1/repos/...
;   GitLab      https://host/group/repo              -> /api/v4/projects/...
;   GitHub Ent. https://host/owner/repo              -> /api/v3/repos/...
; A /releases or /releases/tag/<tag> suffix is ignored, so the address can be
; copied straight from the browser.
; ---------------------------------------------------------------------------

; Split a repository URL into its parts.
; Returns a 4-element array [base, host, namespace, repo], or an empty array
; when the URL cannot be understood. "owner/repo" is treated as GitHub.
Func ParseRepoUrl($url)
	Local $result[0]
	Local $s = StringStripWS($url, 3)
	Local $m = 0
	Local $host = ''
	Local $path = ''
	Local $parts = 0
	Local $seg = ''
	Local $keep = 0
	Local $start = 1
	Local $i = 0
	Local $ns = ''
	Local $repo = ''
	Local $out[4]

	If $s = '' Then Return $result

	If Not StringRegExp($s, '(?i)^https?://') Then
		If StringRegExp($s, '^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+') Then
			$s = 'https://github.com/' & $s
		Else
			$s = 'https://' & $s
		EndIf
	EndIf

	$m = StringRegExp($s, '(?i)^(https?://)([^/?#]+)(.*)$', 1)
	If @error Then Return $result
	$host = StringLower($m[1])
	$path = StringRegExpReplace($m[2], '[?#].*$', '')
	$path = StringRegExpReplace($path, '/+$', '')
	If $path = '' Then Return $result

	$parts = StringSplit(StringTrimLeft($path, 1), '/', 1)
	If $parts[0] < 2 Then Return $result

	; https://api.github.com/repos/owner/repo
	$start = 1
	If $host = 'api.github.com' Then
		If $parts[0] >= 3 And StringLower($parts[1]) = 'repos' Then $start = 2
	EndIf

	; Drop trailing page segments such as /releases, /releases/tag/v1, /-/releases
	; or /src/...
	$keep = $parts[0]
	For $i = $start To $parts[0]
		$seg = StringLower($parts[$i])
		If StringRegExp($seg, '^(-|releases?|tags?|src|archive|tree|blob|raw|commits?|issues?|pulls?|merge_requests|wiki|compare|activity|branches?|milestones?|labels?|settings|projects?|graphs?|network|pulse|contributors|stars|watchers|forks|discussions|actions|packages|security|insights)$') Then
			$keep = $i - 1
			ExitLoop
		EndIf
	Next
	If $keep - $start < 1 Then Return $result

	For $i = $start To $keep - 1
		If $ns <> '' Then $ns &= '/'
		$ns &= $parts[$i]
	Next
	$repo = StringRegExpReplace($parts[$keep], '(?i)\.git$', '')
	If $repo = '' Then Return $result

	$out[0] = $m[0] & $host
	$out[1] = $host
	$out[2] = $ns
	$out[3] = $repo
	Return $out
EndFunc

; Host part of a URL, lowercase, without scheme and path.
Func UrlHost($url)
	Local $m = StringRegExp($url, '(?i)^https?://([^/?#]+)', 1)
	If @error Then Return ''
	Return StringLower($m[0])
EndFunc

; True for github.com and its subdomains (api.github.com, ...).
Func IsGithubHost($host)
	Local $h = StringLower($host)
	Return $h = 'github.com' Or StringRight($h, 11) = '.github.com'
EndFunc

; Extract the repository name, e.g.
; https://github.com/Zoo-Code-Or/Zoo-Code -> Zoo-Code
Func GetSoftwareName($url)
	Local $info = ParseRepoUrl($url)
	If UBound($info) = 0 Then Return ''
	Return $info[3]
EndFunc

Func GetProcessName($url)
	Local $name = GetSoftwareName($url)
	If $name = '' Then Return ''
	Return $name & '.exe'
EndFunc

; Detect which release API the host provides. GitHub is recognised by the
; host name; everything else is probed, because self-hosted Gitea/Forgejo and
; GitLab instances are not distinguishable by the URL alone.
Func DetectProvider($info)
	Local $base = $info[0]
	Local $body = ''
	Local $err = 0

	If IsGithubHost($info[1]) Then Return 'github'

	; Gitea/Forgejo expose an unauthenticated version endpoint.
	$body = HttpGet($base & '/api/v1/version')
	$err = @error
	If $err = 0 Then
		If JsonGetString($body, 'version') <> '' Then Return 'gitea'
	EndIf

	; GitLab project ids are URL-encoded "group/repo" paths.
	$body = HttpGet($base & '/api/v4/projects/' & GitLabProjectId($info) & '/releases?per_page=1')
	$err = @error
	If $err = 0 Then Return 'gitlab'

	; GitHub Enterprise Server uses the same API under /api/v3.
	$body = HttpGet($base & '/api/v3/repos/' & $info[2] & '/' & $info[3] & '/releases?per_page=1')
	$err = @error
	If $err = 0 Then Return 'ghe'

	Return ''
EndFunc

Func GitLabProjectId($info)
	Return StringReplace($info[2] & '/' & $info[3], '/', '%2F')
EndFunc

Func ReleaseApiUrl($provider, $info)
	Switch $provider
		Case 'gitea'
			Return $info[0] & '/api/v1/repos/' & $info[2] & '/' & $info[3] & '/releases?limit=1'
		Case 'gitlab'
			Return $info[0] & '/api/v4/projects/' & GitLabProjectId($info) & '/releases?per_page=1'
		Case 'ghe'
			Return $info[0] & '/api/v3/repos/' & $info[2] & '/' & $info[3] & '/releases?per_page=1'
		Case Else
			Return 'https://api.github.com/repos/' & $info[2] & '/' & $info[3] & '/releases?per_page=1'
	EndSwitch
EndFunc

; Fetch the newest release as JSON. Sets $g_repoProvider for the asset parser.
Func FetchRelease()
	Local $info = ParseRepoUrl($g_softwareUrl)
	Local $provider = ''
	Local $url = ''
	Local $json = ''
	Local $err = 0
	Local $status = 0

	$g_repoProvider = ''
	If UBound($info) = 0 Then
		LogW('[ERROR] Invalid repository URL: ' & $g_softwareUrl)
		Return SetError(1, 0, '')
	EndIf

	$provider = DetectProvider($info)
	If $provider = '' Then
		LogW('[ERROR] No supported release API on: ' & $info[0])
		Return SetError(1, $g_lastHttpStatus, '')
	EndIf
	$g_repoProvider = $provider

	; Take the first entry of the public releases list. This follows the
	; "Releases" page (including pre-releases), instead of "latest" which only
	; returns stable releases.
	$url = ReleaseApiUrl($provider, $info)

	LogW('Release API (' & $provider & '): ' & $url)
	$json = HttpGet($url)
	$err = @error
	$status = @extended
	If $err Then
		LogW('[ERROR] Release API request failed, @error=' & $err & ', HTTP=' & $status)
		Return SetError(2, $status, '')
	EndIf
	Return $json
EndFunc
