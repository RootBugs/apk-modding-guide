# 📦 APK Modding Guide — from zero to your first mod

A beginner-friendly, end-to-end guide to the classic Android APK pipeline:

```
PULL → STUDY → DECODE → EDIT → REBUILD → SIGN → INSTALL → (loop)
```

No fluff, no "download our tool" — just the real tools everyone in the
Android community uses, and exactly what to do with them.

## ⚠️ Rules of the road

- **Only mod apps you own, open-source apps, or apps you have permission
  to modify.** Your own builds and F-Droid apps are perfect targets.
- **Never distribute modded APKs.** This is for learning and personal use.
- **If an app defends its license or integrity, walk away.** Defeating
  license checks / DRM / anti-tamper is off-limits — this guide stops at
  that line.
- Repacked "modded" APKs from random sites are a **major malware risk** —
  don't install them.

## 🧰 The tools

| Tool | What it does |
|---|---|
| [Java (JDK 17+)](https://adoptium.net/) | Runs everything below |
| [apktool](https://apktool.org/) | Decode APK → editable files, rebuild it |
| [jadx](https://github.com/skylot/jadx) | Decompile to readable Java (study only — never rebuilt) |
| [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer) | Zipalign + sign so Android accepts your APK |
| `adb` (platform-tools) | Pull APKs from your phone, install mods |
| `pull-apk.ps1` (this repo) | One-command APK fetch from a connected device |

### Windows quick setup (winget)

```powershell
winget install EclipseAdoptium.Temurin.21.JDK
winget install Git.Git
```

Then drop `apktool.jar`, the jadx zip, and `uber-apk-signer.jar` into a
folder and add it to your `PATH`. That's it — the rest of this guide works
from any terminal.

## 🚀 The pipeline

### Step 1 — Get the APK

Enable **USB debugging** on your phone (Settings → Developer options),
plug it in, approve the prompt, then:

```powershell
.\pull-apk.ps1 com.example.app     # → apk\com.example.app.apk
```

Use **single-APK apps** for your first mods — split APKs (APKS/XAPK bundles)
add a whole extra layer of pain.

### Step 2 — Study the code first (read-only)

```powershell
jadx -d out\java app.apk           # decompile to Java
jadx-gui app.apk                   # ...or browse it in a GUI
```

Find *where* the thing you want to change lives: which class, which string
name, which resource. Write it down. This output is your **map** — you
never edit it or rebuild from it.

### Step 3 — Decode into editable form

```powershell
apktool d app.apk -o work
```

```
work\
├── AndroidManifest.xml   app name, permissions, components, version
├── apktool.yml           build config
├── res\                  EASIEST edits: layouts, strings, colors, icons
│   └── values\strings.xml, booleans.xml, colors.xml ...
├── smali\                THE CODE (Dalvik bytecode, disassembled)
├── assets\               raw files (web content, json, fonts)
├── lib\                  native .so libraries — avoid for now
└── original\             original manifest/signature — leave alone
```

### Step 4 — Edit (one change at a time!)

| Tier | Where | Examples |
|---|---|---|
| 🟢 Easy | `res\values\*.xml`, mipmaps | app name, texts, default toggles, colors, icon swap (keep exact filename + size) |
| 🟡 Medium | `AndroidManifest.xml` | label, permissions, disable a component |
| 🔴 Hard | `smali\` | actual logic — find the method in jadx first, then edit the same method in smali |

Smali is strict: registers (`v0`, `p1`), types, and every code path must
return properly. One wrong instruction = crash. Change **one thing**, then
build and test.

### Step 5 — Rebuild

```powershell
apktool b work -o app-mod.apk
```

Resource build errors? Try `--use-aapt2`.

### Step 6 — Sign (mandatory)

Android refuses any APK whose signature doesn't match its contents — and
your edit broke the original signature, so **every mod gets re-signed**:

```powershell
uber-apk-signer -a app-mod.apk
# → app-mod-aligned-debugSigned.apk
```

Installing *over* an app that's already installed? The signature has to
match, so either sign with the app's original keystore, or uninstall the
original first (⚠️ that wipes its data):

```powershell
adb uninstall com.example.app
```

### Step 7 — Install & test

```powershell
adb install -r app-mod-aligned-debugSigned.apk
```

Crashes on launch? Read the crash log:

```powershell
adb logcat -c
adb logcat | findstr /i "FATAL AndroidRuntime"
```

Fix → rebuild → resign → reinstall. **That's the loop.** You only decode
once; after that it's edit/build/sign forever.

## 📋 Cheat sheet

```powershell
.\pull-apk.ps1 com.example.app
jadx -d out\java app.apk
apktool d app.apk -o work
# ...edit files inside work\...
apktool b work -o app-mod.apk
uber-apk-signer -a app-mod.apk
adb install -r app-mod-aligned-debugSigned.apk
```

(Also included as plain text: [`COMMANDS.txt`](COMMANDS.txt) — for Notepad
and offline reading.)

## 🧯 Common errors

| Symptom | Fix |
|---|---|
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | modded signature ≠ installed signature: uninstall first (loses data) or sign with the original keystore |
| `INSTALL_FAILED_ALREADY_EXISTS` | add the `-r` flag |
| `INSTALL_PARSE_FAILED_NOT_APKS` | it's an XAPK/bundle, not a normal APK |
| apktool resource build fails | add `--use-aapt2` |
| app force-closes after your edit | check logcat, revert your last change |
| apktool framework error | `apktool if framework.apk` |
| app refuses to run modified | **stop** — it's protecting itself; don't defeat license/integrity checks |

## 🏅 Good habits

- Keep `work\` as your source of truth; if it breaks, delete it and decode
  fresh from the original APK.
- One change at a time — build + test after each.
- Use your own keystore for apps you build:

```powershell
keytool -genkeypair -v -keystore my.keystore -alias key1 -keyalg RSA -keysize 2048 -validity 10000 -storepass changeit -keypass changeit -dname "CN=You, O=You, C=IN"
```

## 📜 License

MIT — see [LICENSE](LICENSE). Guide content is educational; you're
responsible for only modding apps you have the right to modify.
