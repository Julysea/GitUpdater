# GitUpdater

GitUpdater 是一个受 [DCUpdater](../dcupdater) 启发的 Windows GitHub Releases 更新器。

它从 **GitHub Releases** 读取最新一条发布，下载用户指定的发布资源，按需解压到 `GitUpdater.exe` 所在目录，显示下载进度、更新说明和完成状态。

**GitUpdater 只负责更新，不负责启动软件。** 更新完成后不会自动启动目标程序。

## 特点

* 不内置任何仓库规则
* 设置窗口的仓库和资源文件默认都为空，只在输入框上方显示示例提示
* 用户自己填写 GitHub 仓库地址和资源文件名
* 支持 `[$ver]` / `[$tag]` 版本占位符，适合资源名带版本号的仓库
* 读取 Releases 列表第一条，和 GitHub 页面上的 Releases 顺序一致
* 只比较最新 tag 字符串：相同就跳过，不同就更新；不做 rc/beta 语义版本比较
* 不需要更新时显示"当前已是最新版本"提示，等待用户点击"关闭"
* 下载进度、失败自动重试、更新说明
* 确认窗口显示更新内容，只有点"是"才开始更新
* 点"否"或关闭窗口不会更新
* 更新完成后显示"更新完成"，等待用户点击"关闭"才退出
* 不自动启动被更新的软件
* 安装目录固定为 `GitUpdater.exe` 所在目录
* 进程检查使用仓库名 + `.exe`（例如 `opencode.exe`、`marktext.exe`）
* 匿名访问 GitHub，不需要 Token
* 自动解压常用压缩包（zip / 7z / rar / tar / tar.gz / tar.bz2 / tar.xz）；其他格式只下载，不处理
* 中文/英文内置，不需要外部翻译文件
* 日志文件
* 自定义图标

## 目录结构

```
GitUpdater/
  README.md
  README_EN.md
  gitupdater.ico            ; Application icon
  trunk/win32/
    GitUpdater.au3          ; AutoIt source code
    README.txt
    gitupdater.ini.example  ; Configuration example
```

## 快速开始

1. 编译 `trunk/win32/GitUpdater.au3`，得到 `GitUpdater.exe`。
2. 把 `GitUpdater.exe` 放到要更新的程序目录，例如：
   * opencode：`D:\Apps\opencode\`
   * marktext：marktext 的安装目录
3. 运行 `GitUpdater.exe`。第一次运行会显示设置窗口。
4. 填写 **GitHub 仓库** 和 **资源文件**。输入框上方有示例提示。
5. 点“确定”后，如果发现新版本，会弹出确认窗口并显示更新内容。
6. 点“是”开始下载，点“否”或关闭窗口则直接退出，不会更新。
7. 更新完成后窗口显示“更新完成”，点“关闭”退出。
8. GitUpdater 不会启动目标程序，需要你自己启动。

> 更新前请关闭目标目录里的目标程序。GitUpdater 会根据仓库名推导进程名并检查。

## 示例配置

### opencode

```text
GitHub 仓库:
https://github.com/anomalyco/opencode

资源文件:
opencode-windows-x64.zip
```

### marktext

marktext 的资源名带版本号：

```text
marktext-win-x64-0.24.0-rc.1.zip
```

使用 `[$ver]` 占位符：

```text
GitHub 仓库:
https://github.com/marktext/marktext

资源文件:
marktext-win-x64-[$ver].zip
```

程序会读取最新 tag，例如 `v0.24.0-rc.1`，把 `[$ver]` 替换成不带开头 `v` 的版本号：

```text
marktext-win-x64-0.24.0-rc.1.zip
```

## 编译

需要安装 [AutoIt v3](https://www.autoitscript.com/site/autoit/)（建议同时安装 SciTE / AutoIt3Wrapper）：

* 右键 `trunk/win32/GitUpdater.au3` → **Compile (x64)**
* 或者使用命令行：

```bat
"C:\Program Files (x86)\AutoIt3\SciTE\AutoIt3Wrapper\AutoIt3Wrapper.exe" /in "trunk\win32\GitUpdater.au3" /out "GitUpdater.exe"
```

生成的 `GitUpdater.exe` 默认输出到源码目录。

> 源码包含中文，必须保存为 **UTF-8 with BOM**。

## 配置

配置文件为 `GitUpdater.exe` 同目录下的 `gitupdater.ini`，第一次运行设置窗口后自动生成。
也可以在启动时加 `--settings` 重新打开设置窗口。

### `[General]`

| 键 | 默认值 | 说明 |
| --- | --- | --- |
| `Update` | `ask` | `yes` 直接更新，`ask` 显示确认窗口，`no` 不检查也不更新（直接退出） |
| `UpdateOnceADay` | `no` | `yes` 时每天最多检查一次；同一天内再次运行直接退出 |
| `LogFile` | `gitupdater.log` | 日志文件路径；留空则关闭日志 |

### `[Internet]`

| 键 | 默认值 | 说明 |
| --- | --- | --- |
| `SoftwareUrl` | 空 | **必填**，软件 GitHub 仓库地址 |
| `AssetFile` | 空 | **必填**，发布资源文件名；支持 `[$ver]` / `[$tag]` 占位符 |
| `UserAgent` | `GitUpdater/1.0` | GitHub API 请求的 User-Agent |
| `DownloadRetries` | `2` | 下载失败后的重试次数（总尝试次数 = 重试次数 + 1） |

### `[Extract]`

| 键 | 默认值 | 说明 |
| --- | --- | --- |
| `StripRootFolder` | `yes` | 如果压缩包只有一个顶层文件夹，自动把里面的内容移到安装目录 |
| `DeleteDownloadedFiles` | `yes` | 压缩包解压成功后删除下载文件；只下载模式会保留文件 |

### `[Error]`

| 键 | 默认值 | 说明 |
| --- | --- | --- |
| `SupressInetRead` | `no` | `yes` 时静默网络错误（不弹窗）；致命错误仍会提示 |

### `[Meta]`

| 键 | 默认值 | 说明 |
| --- | --- | --- |
| `ConfigVersion` | `1` | 配置版本 |

### 运行时写入的状态

* `LastUpdateDate`：最后一次检查/更新的日期
* `LastUpdatedVersion`：最后一次更新的 tag，例如 `v0.24.0-rc.1`
* `LastReleaseUrl`：最后一次更新的 Release 页面

### 已移除的旧配置

以下配置现在会被忽略：

* `InstallDir`：安装目录固定为 `@ScriptDir`
* `PostExecution`：GitUpdater 不再启动软件
* `ProcessName`：改为根据仓库名推导
* `ExtractCommand`：改为按压缩包格式自动解压
* `ReleaseTag`：固定读取 Releases 第一条
* `AssetPattern`：改为 `AssetFile`，支持 `[$ver]` / `[$tag]`
* `ApiToken`：匿名访问 GitHub
* `TranslationFile`：中英文已内置

### 新增配置

* `DownloadRetries`：下载失败后的重试次数，默认 `2`

## 资源文件占位符

`AssetFile` 是资源文件名，不是正则表达式，也不是通配符。

支持两个占位符：

| 占位符 | 含义 | 示例 |
| --- | --- | --- |
| `[$ver]` | 最新 tag 去掉开头的 `v` | `v0.24.0-rc.1` → `0.24.0-rc.1` |
| `[$tag]` | 完整最新 tag | `v0.24.0-rc.1` → `v0.24.0-rc.1` |

示例：

```ini
; opencode
AssetFile=opencode-windows-x64.zip

; marktext
AssetFile=marktext-win-x64-[$ver].zip

; 资源名包含完整 tag
AssetFile=myapp-[$tag].zip
```

* 文件名不区分大小写。
* 必须和 GitHub Release 里的资源文件名完全一致（占位符替换后）。
* 不填写或填写后没有匹配项时，会显示可用资源列表。
* 不做自动选择，不内置任何仓库规则。

## 解压与下载策略

GitUpdater 根据资源文件扩展名自动处理，不需要配置解压命令：

| 格式 | 处理方式 |
| --- | --- |
| `.zip` | PowerShell 自动解压 |
| `.7z` / `.rar` | 使用 7-Zip 解压（需要安装 7-Zip） |
| `.tar` / `.tar.gz` / `.tgz` | 使用 Windows 自带 tar 解压 |
| `.tar.bz2` / `.tbz2` / `.tbz` | 使用 Windows 自带 tar 解压 |
| `.tar.xz` / `.txz` | 使用 Windows 自带 tar 解压 |
| 其他格式 | **只下载**，不解压、不运行 |

* 7z/rar 会优先查找 7-Zip；找不到时尝试用 Windows tar，仍失败则提示错误。
* 只下载模式会保留下载的文件，即使 `DeleteDownloadedFiles=yes`。
* 只有压缩包解压成功后，才会根据 `DeleteDownloadedFiles` 决定是否删除。
* `setup.exe`、`.msi` 等安装程序不会被自动运行。

## 版本判断

GitUpdater **不解析版本号**，只比较最新 tag 字符串：

* 上次记录是 `v0.24.0-rc.1`，最新也是 `v0.24.0-rc.1` → 跳过，显示“当前已是最新版本”，等待点击“关闭”
* 上次记录是 `v0.24.0-rc.1`，最新是 `v0.24.0-rc.2` → 更新
* 上次记录是 `v0.24.0-rc.1`，最新是 `v0.24.0` → 更新

使用 `--force` 可以忽略相同 tag，强制重新下载。

## 命令行参数

| 参数 | 说明 |
| --- | --- |
| `--settings` | 打开设置窗口，保存后退出 |
| `--force` | 忽略“每天只检查一次”和相同 tag 判断，直接更新 |

例如：

```bat
GitUpdater.exe --settings
GitUpdater.exe --force
```

## 工作流程

1. 读取 `gitupdater.ini`。
2. 如果仓库或资源文件为空，显示设置窗口。
3. 安装目录固定为 `GitUpdater.exe` 所在目录，检查写权限。
4. 根据仓库名推导进程名（例如 `marktext` → `marktext.exe`），检查目标程序是否在运行。
   * 如果目标程序正在运行 → 提示用户关闭，退出。
   * 如果目标文件是只读的 → 提示用户，退出。
5. 如果 `Update` 不是 `yes` / `ask`，直接退出。
6. 如果启用了"每天只检查一次"，并且今天已经检查过，直接退出。
7. 调用 GitHub API：
   * `GET /repos/{owner}/{repo}/releases?per_page=1`
   * 取 Releases 列表第一条
8. 读取 `tag_name`、`body`（更新说明）和 `assets`。
9. 替换 `[$ver]` / `[$tag]`，按完整文件名匹配资源。
10. 比较最新 tag 与 `LastUpdatedVersion`：
    * 相同且没有 `--force` → 显示"当前已是最新版本"，等待用户点击"关闭"
    * 相同且有 `--force` → 继续更新
    * 不同 → 继续
11. 如果需要更新且 `Update=ask`，显示确认窗口：
    * 展示仓库、当前版本、可用版本、更新内容
    * 只有点"是"才继续
    * 点"否"或关闭窗口则退出，不下载
12. 显示下载进度并下载资源，失败时按 `DownloadRetries` 重试。
13. 根据扩展名处理下载文件：
    * zip / 7z / rar / tar / tar.gz / tar.bz2 / tar.xz → 自动解压
    * 其他格式 → 只下载
14. 写入 `LastUpdatedVersion` / `LastUpdateDate`，按规则清理下载文件。
15. 显示"更新完成"或"下载完成"，等待用户点击"关闭"后退出。
16. **不启动被更新的软件。**

## 注意事项

* GitUpdater 不会自动启动目标程序。
* 更新前必须关闭目标目录里的目标程序，否则文件可能被占用。
* GitUpdater 更新的是**它自己所在目录**。要更新哪个目录的程序，就把 `GitUpdater.exe` 放到那个目录。
* 进程名根据仓库名推导；如果实际进程名不同，检查可能不生效，文件占用时会报错。
* 不做语义版本比较，只比较 tag 字符串。
* 非压缩包格式只下载，文件会保留。
* 7z/rar 解压需要安装 7-Zip；zip 和 tar 系列使用 Windows 自带工具。
* GitHub 未认证 API 限额约为每小时 60 次；不需要 Token。
* 如果安装在 `Program Files` 等受保护目录，可能需要以管理员身份运行。
* 界面语言根据 Windows 显示语言自动选择，没有外部翻译文件。
* 中文源码必须保存为 UTF-8 with BOM。
* `Update=no` 时不检查更新，直接退出。
* `UpdateOnceADay=yes` 时，同一天内第二次运行直接退出，不弹窗。
* 下载失败时自动重试，总尝试次数 = `DownloadRetries` + 1。
* 压缩包解压成功后，根据 `DeleteDownloadedFiles` 决定是否删除下载文件。
* 只下载模式（非压缩包）始终保留下载文件。
