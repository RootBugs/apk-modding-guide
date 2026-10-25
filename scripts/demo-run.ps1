<#
.SYNOPSIS
    Runs the guide's full pipeline on any APK: decode -> locate label ->
    (optional) edit app name -> rebuild -> sign. No phone needed.
.DESCRIPTION
    Meant to sit NEXT TO your tool wrappers (e.g. inside C:\Users\<you>\ApkMod),
    exactly like pull-apk.ps1. Prints the REAL tool output at every stage, so
    you can compare it with the transcripts in README.md.
    It works on the same rules as the guide: only run it on APKs you own or
    have permission to modify. It never installs anything.
.EXAMPLE
    .\demo-run.ps1 C:\path\to\your-app.apk
.EXAMPLE
    .\demo-run.ps1 C:\path\to\your-app.apk -NewLabel "My Mod"
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Apk,
    [string]$NewLabel = '',
    [string]$WorkDir = 'work-demo'
)

$ErrorActionPreference = 'Stop'

# ---- find the tool folder: next to this script, one level up, or ~\ApkMod
$toolDir = $null
foreach ($c in @($PSScriptRoot, (Split-Path $PSScriptRoot -Parent), "$env:USERPROFILE\ApkMod")) {
    if ($c -and (Test-Path "$c\apktool_*.jar")) { $toolDir = (Resolve-Path $c).Path; break }
}
if (-not $toolDir) { throw 'Tool folder not found (no apktool_*.jar next to this script). Run from your ApkMod folder.' }

$apktool  = "$toolDir\apktool.bat"
$signer   = "$toolDir\uber-apk-signer.bat"

function Stage($n, $title) {
    Write-Host ''
    Write-Host ("==== STAGE $n/5: $title " + '=' * [Math]::Max(0, 62 - $title.Length)) -ForegroundColor Cyan
}
function Fail($stage, $detail) {
    Write-Host ''
    Write-Host "STOPPED at stage $stage." -ForegroundColor Red
    Write-Host $detail -ForegroundColor Red
    exit 1
}

# ---- input APK
$apkFull = $Apk
if (-not [System.IO.Path]::IsPathRooted($apkFull)) { $apkFull = Join-Path (Get-Location).Path $apkFull }
if (-not (Test-Path $apkFull)) { throw "APK not found: $apkFull" }
$apkName = [System.IO.Path]::GetFileNameWithoutExtension($apkFull)
$workFull = if ([System.IO.Path]::IsPathRooted($WorkDir)) { $WorkDir } else { Join-Path (Get-Location).Path $WorkDir }

Write-Host "APK      : $apkFull" -ForegroundColor DarkGray
Write-Host "Work dir : $workFull" -ForegroundColor DarkGray

# ---- STAGE 1: decode
Stage 1 'DECODE'
& $apktool d $apkFull -o $workFull -f 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) { Fail 1 'apktool decode failed - see output above.' }

# ---- STAGE 2: locate the app label (the exact files the guide tells you about)
Stage 2 'LOCATE LABEL (res\values\*.xml + AndroidManifest.xml)'
$hits = Select-String -Path "$workFull\res\values\*.xml" -Pattern 'name="app_name"' -ErrorAction SilentlyContinue
if ($hits) {
    foreach ($h in $hits) { Write-Host ("  {0}:{1}: {2}" -f $h.Filename, $h.LineNumber, $h.Line.Trim()) -ForegroundColor DarkGray }
} else {
    Write-Host '  no <string name="app_name"> found (some apps name it differently).' -ForegroundColor Yellow
}
Select-String -Path "$workFull\AndroidManifest.xml" -Pattern 'android:label' -ErrorAction SilentlyContinue |
    Select-Object -First 2 | ForEach-Object { Write-Host ("  manifest: " + $_.Line.Trim()) -ForegroundColor DarkGray }

# ---- STAGE 3: edit (only if -NewLabel given and app_name exists)
Stage 3 'EDIT'
$edited = $false
if ($NewLabel) {
    $stringsFile = "$workFull\res\values\strings.xml"
    if (Test-Path $stringsFile) {
        $xml = [System.IO.File]::ReadAllText($stringsFile)
        $m = [regex]::Match($xml, '<string name="app_name">([^<]*)</string>')
        if ($m.Success) {
            $old = $m.Groups[1].Value
            $xml = $xml.Replace($m.Value, ('<string name="app_name">' + $NewLabel + '</string>'))
            [System.IO.File]::WriteAllText($stringsFile, $xml)   # UTF-8, NO BOM - see README BOM trap
            Write-Host "  app_name: '$old'  ->  '$NewLabel'" -ForegroundColor Green
            Write-Host "  written (UTF-8, no BOM): $stringsFile" -ForegroundColor DarkGray
            $edited = $true
        } else {
            Write-Host '  app_name string not found in strings.xml - skipping edit.' -ForegroundColor Yellow
        }
    } else {
        Write-Host '  res\values\strings.xml missing - skipping edit.' -ForegroundColor Yellow
    }
} else {
    Write-Host '  no -NewLabel given - building the APK unchanged (still a valid pipeline demo).' -ForegroundColor Yellow
}

# ---- STAGE 4: rebuild
Stage 4 'REBUILD'
$outApk = Join-Path (Split-Path $apkFull -Parent) ("{0}-demo.apk" -f $apkName)
& $apktool b $workFull -o $outApk 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) { Fail 4 'apktool build failed - see the [line,col] error above (README errors table).' }

# ---- STAGE 5: sign
Stage 5 'SIGN'
& $signer -a $outApk 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) { Fail 5 'uber-apk-signer failed - see output above.' }
$signed = Get-ChildItem (Split-Path $outApk -Parent) -Filter "$apkName-demo-aligned-*.apk" | Sort-Object LastWriteTime | Select-Object -Last 1
if (-not $signed) { Fail 5 'signed file not found next to the rebuilt apk.' }

# ---- summary
Write-Host ''
Write-Host ('==== DONE ' + '=' * 60) -ForegroundColor Green
Write-Host ("  rebuilt : " + $outApk)
Write-Host ("  SIGNED  : " + $signed.FullName) -ForegroundColor Green
Write-Host ('  edited app_name: ' + $(if ($edited) { 'yes' } else { 'no (demo only)' }))
Write-Host ''
Write-Host '  To install it on a phone (uninstall first if signatures differ):'
Write-Host ("      adb uninstall " + 'com.your.app') -ForegroundColor DarkGray
Write-Host ("      adb install -r `"" + $signed.FullName + '"') -ForegroundColor DarkGray
exit 0
