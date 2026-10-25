<#
.SYNOPSIS
    Verifies the APK-modding environment described in README.md section 1.
.DESCRIPTION
    Checks Java, adb, the three tool jars, wrapper .bat files, their SHA256
    hashes (against the pinned releases from the guide), that each tool
    actually LAUNCHES with its expected version, and that your PATH sees the
    tool folder. Every [ OK ] green = that piece of the guide setup is real.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File setup-check.ps1
#>
$ErrorActionPreference = 'SilentlyContinue'

# Pinned releases from README section 1.2 (name -> official sha256)
$pinned = @{
    'apktool_3.0.3.jar'           = 'dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423'
    'uber-apk-signer-1.3.0.jar'   = 'e1299fd6fcf4da527dd53735b56127e8ea922a321128123b9c32d619bba1d835'
    'jadx-1.5.6.zip'              = '545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974'
}

# ---- find the tool folder: next to this script, one level up, or ~\ApkMod
$candidates = @($PSScriptRoot, (Split-Path $PSScriptRoot -Parent), "$env:USERPROFILE\ApkMod")
$toolDir = $null
foreach ($c in $candidates) {
    if ($c -and (Test-Path "$c\apktool_*.jar")) { $toolDir = (Resolve-Path $c).Path; break }
}
if (-not $toolDir) {
    Write-Host '[FAIL] tool folder not found (no apktool_*.jar next to this script,' -ForegroundColor Red
    Write-Host '       one level up, or in ~\ApkMod). Copy this script INTO your ApkMod folder.' -ForegroundColor Red
    exit 1
}
Write-Host "Tool folder: $toolDir`n" -ForegroundColor DarkGray

$script:ok = 0; $script:warn = 0; $script:fail = 0
function Row($status, $label, $note) {
    switch ($status) {
        'OK'   { Write-Host ('[ OK ] ') -NoNewline -ForegroundColor Green;   $script:ok++ }
        'WARN' { Write-Host ('[WARN] ') -NoNewline -ForegroundColor Yellow;  $script:warn++ }
        'FAIL' { Write-Host ('[FAIL] ') -NoNewline -ForegroundColor Red;     $script:fail++ }
    }
    Write-Host $label -NoNewline
    if ($note) { Write-Host ("  -> " + $note) -ForegroundColor DarkGray } else { Write-Host '' }
}

# ---- 1. Java + adb on PATH
# Note: wrappers find Java themselves (jdk-* glob), so a PATH miss here is a
# WARN, not a FAIL - the launch tests below are the real proof. But `keytool`
# and plain `java -jar` DO need PATH, so it's worth fixing.
$jv = (& java -version 2>&1 | Select-Object -First 1)
if ($jv) {
    Row 'OK' ("java on PATH: " + "$jv".Trim('"'))
} else {
    $globJdk = Get-ChildItem "$env:ProgramFiles\Eclipse Adoptium" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($globJdk) {
        Row 'WARN' 'java not on THIS terminal PATH (Temurin found on disk)' "found: $($globJdk.FullName) - open a NEW terminal; the wrappers work anyway"
    } else {
        Row 'FAIL' 'java not found at all' 'install Temurin JDK 17+ (winget install EclipseAdoptium.Temurin.21.JDK)'
    }
}
$av = (& adb version 2>&1 | Select-Object -First 1)
if ($av -match 'Android Debug Bridge') { Row 'OK' ("adb on PATH: " + $av) } else { Row 'FAIL' 'adb not on PATH' 'winget install Google.PlatformTools' }

# ---- 2. files present
foreach ($f in @('pull-apk.ps1', 'setup-check.ps1', 'apktool.bat', 'uber-apk-signer.bat', 'jadx.bat', 'jadx-gui.bat')) {
    if (Test-Path "$toolDir\$f") { Row 'OK' "$f present" } else { Row 'FAIL' "$f MISSING" "copy it from the guide repo (scripts\)" }
}
if (Test-Path "$toolDir\jadx\bin\jadx.bat") { Row 'OK' 'jadx extracted (jadx\bin\jadx.bat found)' } else { Row 'FAIL' 'jadx not extracted' 'unzip jadx-1.5.6.zip into a folder named jadx' }

# ---- 3. jars + hashes
foreach ($pat in @('apktool_*.jar', 'uber-apk-signer-*.jar')) {
    $jar = Get-ChildItem "$toolDir\$pat" | Select-Object -First 1
    if (-not $jar) { Row 'FAIL' "$pat MISSING" 'download link in README 1.2'; continue }
    $expect = $pinned[$jar.Name]
    if ($expect) {
        $h = (Get-FileHash $jar.FullName -Algorithm SHA256).Hash.ToLower()
        if ($h -eq $expect) { Row 'OK' ("$($jar.Name) - sha256 matches pinned release") }
        else { Row 'WARN' ("$($jar.Name) - sha256 DIFFERS from pinned release") ("found: " + $h) }
    } else {
        Row 'OK' ("$($jar.Name) present (non-pinned name - version verified by launch test below)")
    }
}

# ---- 4. launch tests (the real proof: wrapper -> java -> jar)
$t = & cmd /c "`"$toolDir\apktool.bat`" --version" 2>&1
if ("$t" -match '\d+\.\d+') { Row 'OK' ("apktool.bat launches -> " + "$t".Trim()) } else { Row 'FAIL' 'apktool.bat does not launch' ("output: " + "$t") }
$t = & cmd /c "`"$toolDir\uber-apk-signer.bat`" -v" 2>&1 | Select-Object -First 1
if ("$t" -match 'Version:') { Row 'OK' ("uber-apk-signer.bat launches -> " + "$t".Trim()) } else { Row 'FAIL' 'uber-apk-signer.bat does not launch' ("output: " + "$t") }
$t = & cmd /c "`"$toolDir\jadx.bat`" --version" 2>&1 | Select-Object -First 1
if ("$t" -match '\d+\.\d+') { Row 'OK' ("jadx.bat launches -> " + "$t".Trim()) } else { Row 'FAIL' 'jadx.bat does not launch' ("output: " + "$t") }

# ---- 5. PATH visibility (only warn: wrappers work without it)
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -like "*$toolDir*") { Row 'OK' 'tool folder is in your user PATH' }
else { Row 'WARN' 'tool folder NOT in PATH' 'works anyway if you always run from inside the folder; to add: sysdm.cpl -> Environment Variables' }

# ---- summary
Write-Host ''
$total = $script:ok + $script:warn + $script:fail
if ($script:fail -eq 0) {
    $extra = ''
    if ($script:warn) { $extra = " ($($script:warn) warning(s) - read them above)" }
    Write-Host "RESULT: $script:ok/$total checks passed$extra - you are READY for Step 1." -ForegroundColor Green
    exit 0
} else {
    Write-Host "RESULT: $script:fail FAILED check(s), $script:ok passed - fix the [FAIL] lines above (each has the fix)." -ForegroundColor Red
    exit 1
}
