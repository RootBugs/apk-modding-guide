<#
.SYNOPSIS
    Repository self-check: verifies README.md's internal links, explicit
    anchors, code fences, referenced script files, and that the pinned
    facts (versions + SHA256 hashes) stay in sync between README.md and
    COMMANDS.txt.
.DESCRIPTION
    The guide claims to be precise - this script is the enforcement.
    Run it after any edit; every [FAIL] prints what's wrong.
    Exit code 0 = all green, 1 = something drifted.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File readme-check.ps1
#>
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path "$repo\README.md")) { $repo = $PSScriptRoot }   # run from repo root copy too
$readme  = [System.IO.File]::ReadAllText("$repo\README.md")
$commands = [System.IO.File]::ReadAllText("$repo\COMMANDS.txt")

$script:ok = 0; $script:fail = 0
function Row($status, $label, $note) {
    switch ($status) {
        'OK'   { Write-Host '[ OK ] ' -NoNewline -ForegroundColor Green;  $script:ok++ }
        'FAIL' { Write-Host '[FAIL] ' -NoNewline -ForegroundColor Red;    $script:fail++ }
    }
    Write-Host $label -NoNewline
    if ($note) { Write-Host ('  -> ' + $note) -ForegroundColor DarkGray } else { Write-Host '' }
}

# ---- 1. every internal #anchor link points at an existing <a id="..."></a>
$anchorLinks = [regex]::Matches($readme, '\]\(#([a-z0-9\-_]+)\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$anchorDefs  = [regex]::Matches($readme, '<a id="([a-z0-9\-_]+)"></a>') | ForEach-Object { $_.Groups[1].Value }
$bad = @($anchorLinks | Where-Object { $_ -notin $anchorDefs })
if ($anchorLinks.Count -eq 0) { Row 'FAIL' 'no #anchor links found in README - regex broken?' }
elseif ($bad.Count -eq 0) { Row 'OK' ("internal anchors: " + $anchorLinks.Count + " TOC links, all have <a id> targets") }
else { Row 'FAIL' ("broken internal anchors: " + ($bad -join ', ')) }

# ---- 2. anchor ids unique
$dups = $anchorDefs | Group-Object | Where-Object Count -gt 1
if ($dups) { Row 'FAIL' ("duplicate <a id>: " + (($dups | ForEach-Object Name) -join ', ')) }
else { Row 'OK' ("<a id> definitions unique (" + $anchorDefs.Count + " total)") }

# ---- 3. relative file links exist on disk
$relLinks = [regex]::Matches($readme, '\]\(((?!#|https?:|mailto:)[^)]+)\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
foreach ($l in $relLinks) {
    $target = ($l -split '#')[0].TrimEnd('/')
    if (Test-Path (Join-Path $repo $target)) { Row 'OK' ("relative link exists: " + $l) }
    else { Row 'FAIL' ("relative link BROKEN: " + $l) }
}

# ---- 4. code fences balanced (an odd count = broken rendering)
$fenceCount = ([regex]::Matches($readme, '(?m)^\s*```')).Count
if ($fenceCount % 2 -eq 0) { Row 'OK' ("code fences balanced (" + $fenceCount + " fence lines)") }
else { Row 'FAIL' ("UNBALANCED code fences: " + $fenceCount + " ``` lines (odd = rendering breaks)") }

# ---- 5. every .ps1/.bat mentioned in README exists in scripts\ (or repo root)
$mentioned = [regex]::Matches($readme, '`([A-Za-z0-9\-_]+\.(ps1|bat))`') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
foreach ($f in $mentioned) {
    if ((Test-Path "$repo\scripts\$f") -or (Test-Path "$repo\$f")) { Row 'OK' ("referenced file ships in repo: " + $f) }
    else { Row 'FAIL' ("README mentions but repo lacks: " + $f) }
}

# ---- 6. pinned facts in sync between README.md and COMMANDS.txt
$facts = @{
    'sha256 apktool'      = 'dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423'
    'sha256 jadx'         = '545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974'
    'sha256 signer'       = 'e1299fd6fcf4da527dd53735b56127e8ea922a321128123b9c32d619bba1d835'
    'apktool version'     = '3.0.3'
    'jadx version'        = '1.5.6'
    'signer version'      = '1.3.0'
    'adb version'         = '1.0.41'
    'jdk version'         = '21.0.12'
    'critical flag fix'   = '--ksKeyPass'
    'myth fix'            = '--use-aapt2'
}
foreach ($k in ($facts.Keys | Sort-Object)) {
    $v = $facts[$k]
    $inR = $readme.Contains($v); $inC = $commands.Contains($v)
    if ($inR -and $inC) { Row 'OK' ("fact in both files: " + $k + " = " + $v) }
    else {
        $where = $(if (-not $inR) { 'README.md' } else { '' }) + $(if (-not $inC) { $(if (-not $inR) { ' + ' } else { '' }) + 'COMMANDS.txt' } else { '' })
        Row 'FAIL' ("fact missing from " + $where + ": " + $k + " = " + $v)
    }
}

# ---- summary
Write-Host ''
$total = $script:ok + $script:fail
if ($script:fail -eq 0) {
    Write-Host "RESULT: $script:ok/$total repo checks passed - guide is internally consistent." -ForegroundColor Green
    exit 0
} else {
    Write-Host "RESULT: $script:fail FAILED, $script:ok passed - fix the [FAIL] lines above." -ForegroundColor Red
    exit 1
}
