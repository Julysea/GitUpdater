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
# Try common AutoIt installation paths
$commonPaths = @(
    'd:\DevelopTools\SDK\autoit',
    'C:\Program Files (x86)\AutoIt3',
    'C:\Program Files\AutoIt3',
    "$env:TEMP\install",
    "$env:USERPROFILE\AutoIt3"
)
$compiler = $null
foreach ($path in $commonPaths) {
    $testCompiler = Join-Path $path 'Aut2Exe\Aut2exe_x64.exe'
    if (Test-Path $testCompiler) {
        $compiler = $testCompiler
        break
    }
}

# Step 0: Check if AutoIt is installed
Write-Output "Checking AutoIt installation..."
if (-not $compiler) {
    Write-Error "AutoIt compiler not found in common locations."
    Write-Output ""
    Write-Output "Please install AutoIt v3 from: https://www.autoitscript.com/downloads/"
    Write-Output "Or add your AutoIt installation path to the common paths list in this script."
    exit 1
}
Write-Output "Found AutoIt compiler at: $compiler"

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
