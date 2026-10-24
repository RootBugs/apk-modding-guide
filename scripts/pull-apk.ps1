# pull-apk.ps1 - Pull an installed app's APK from a connected Android device
# Usage: .\pull-apk.ps1 com.example.app
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Package
)

$ErrorActionPreference = 'Stop'
$outDir = Join-Path $PSScriptRoot 'apk'
New-Item -ItemType Directory -Force $outDir | Out-Null

# List what we're pulling (fails fast if device not connected)
adb shell pm path $Package | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Device not reachable or package '$Package' not found." }

$paths = adb shell pm path $Package |
    ForEach-Object { ($_ -replace '^package:', '').Trim() } |
    Where-Object { $_ }

$i = 0
foreach ($p in $paths) {
    if ($paths.Count -eq 1) {
        $name = "$Package.apk"
    } else {
        $name = if ($i -eq 0) { "$Package.apk" } else { "$Package.split$i.apk" }
    }
    $dest = Join-Path $outDir $name
    Write-Output "Pulling $p -> $dest"
    adb pull $p $dest | Out-Null
    $i++
}

Write-Output "Done. $(if ($paths.Count -gt 1) { "Warning: $($paths.Count) split APKs - modding split APKs is advanced; prefer a non-split app for your first mod." })"
Get-ChildItem $outDir -Filter "$Package*" | Select-Object Name, Length
