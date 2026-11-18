#include-once
; ---------------------------------------------------------------------------
; Configuration (gitupdater.ini) load and save
; ---------------------------------------------------------------------------
Func LoadSettings()
	$g_update = IniRead($g_iniFile, 'General', 'Update', $g_update)
	$g_onceADay = IniRead($g_iniFile, 'General', 'UpdateOnceADay', $g_onceADay)
	$g_logFile = IniRead($g_iniFile, 'General', 'LogFile', $g_logFile)

	$g_softwareUrl = IniRead($g_iniFile, 'Internet', 'SoftwareUrl', $g_softwareUrl)
	$g_assetFile = IniRead($g_iniFile, 'Internet', 'AssetFile', $g_assetFile)
	$g_userAgent = IniRead($g_iniFile, 'Internet', 'UserAgent', $g_userAgent)
	$g_downloadRetries = Int(IniRead($g_iniFile, 'Internet', 'DownloadRetries', $g_downloadRetries))
	If $g_downloadRetries < 0 Then $g_downloadRetries = 0

	$g_stripRoot = IniRead($g_iniFile, 'Extract', 'StripRootFolder', $g_stripRoot)
	$g_deleteDownloaded = IniRead($g_iniFile, 'Extract', 'DeleteDownloadedFiles', $g_deleteDownloaded)
	$g_binPath = IniRead($g_iniFile, 'Extract', 'BinPath', $g_binPath)

	$g_suppressErrors = IniRead($g_iniFile, 'Error', 'SupressInetRead', $g_suppressErrors)

	If $g_userAgent = '' Then $g_userAgent = 'GitUpdater/1.0'
	LogW('Settings loaded from: ' & $g_iniFile)
EndFunc

Func SaveSettings()
	IniWrite($g_iniFile, 'General', 'Update', $g_update)
	IniWrite($g_iniFile, 'General', 'UpdateOnceADay', $g_onceADay)
	IniWrite($g_iniFile, 'General', 'LogFile', $g_logFile)

	IniWrite($g_iniFile, 'Internet', 'SoftwareUrl', $g_softwareUrl)
	IniWrite($g_iniFile, 'Internet', 'AssetFile', $g_assetFile)
	IniWrite($g_iniFile, 'Internet', 'UserAgent', $g_userAgent)
	IniWrite($g_iniFile, 'Internet', 'DownloadRetries', $g_downloadRetries)

	IniWrite($g_iniFile, 'Extract', 'StripRootFolder', $g_stripRoot)
	IniWrite($g_iniFile, 'Extract', 'DeleteDownloadedFiles', $g_deleteDownloaded)
	IniWrite($g_iniFile, 'Extract', 'BinPath', $g_binPath)

	IniWrite($g_iniFile, 'Error', 'SupressInetRead', $g_suppressErrors)
	IniWrite($g_iniFile, 'Meta', 'ConfigVersion', '1')
	LogW('Settings written to: ' & $g_iniFile)
EndFunc

