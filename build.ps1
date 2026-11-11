# GitUpdater build script
# Cleans build/ directory, compiles from source, and copies exe to build/
#
# Usage (PowerShell):
#   .\build.ps1
#
# Prerequisites:
#   AutoIt v3 installed at C:\Program Files (x86)\AutoIt3\
#   (or set $autoitInstall to your portable AutoIt path)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$sourcePath = Join-Path $scriptDir 'trunk\win32\GitUpdater.au3'
$iconPath = Join-Path $scriptDir 'gitupdater.ico'
$buildDir = Join-Path $scriptDir 'build'
$exePath = Join-Path $buildDir 'GitUpdater.exe'

# AutoIt compiler path — change this to your AutoIt installation
$autoitInstall = Join-Path $env:TEMP 'install'
$compiler = Join-Path $autoitInstall 'Aut2Exe\Aut2exe_x64.exe'

# Step 1: Clean build directory
if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

# Step 2: Compile
Write-Output "Compiling..."
$p = Start-Process -FilePath $compiler -ArgumentList @('/in',$sourcePath,'/out',$exePath,'/icon',$iconPath) -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0) { Write-Output "COMPILE FAILED"; exit 1 }

# Step 3: Done
Write-Output "Done."
Get-ChildItem $buildDir | Select-Object Name, @{N='Size(KB)';E={[math]::Round($_.Length/1KB,1)}}
