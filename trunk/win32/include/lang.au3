#include-once
; ---------------------------------------------------------------------------
; Language detection and translation helper
; ---------------------------------------------------------------------------
Func SetLanguage()
	Local $lang = @MUILang
	If $lang = '' Then $lang = @OSLang

	$g_lang = 'en'
	If StringInStr('|0804|1004|0404|0C04|1404|', '|' & $lang & '|') Then $g_lang = 'zh'

	$g_tOKButton = T('&Ok', '确定(&O)')
	$g_tCancelButton = T('&Cancel', '取消(&C)')
	$g_tYesButton = T('&Yes', '是(&Y)')
	$g_tNoButton = T('&No', '否(&N)')
	$g_tCloseButton = T('&Close', '关闭(&C)')
	$g_tSettingsButton = T('&Settings', '重新定义配置(&S)')
	$g_tStatusFormTitle = T('GitUpdater Status', 'GitUpdater 状态')
	$g_tStatusDownloadLabel = T('Downloading', '正在下载')
	$g_tStatusCompleteLabel = T('Complete', '完成')
	$g_tStatusExtractLabel = T('Extracting', '正在解压')
	$g_tStatusChangelogLabel = T('Release notes', '更新说明')
	$g_tUpdateCompleteLabel = T('Update complete', '更新完成')
	$g_tDownloadCompleteLabel = T('Download complete', '下载完成')
	$g_tColon = T(': ', '：')
EndFunc

Func T($en, $zh)
	If $g_lang = 'zh' Then Return $zh
	Return $en
EndFunc

