# 📦 APK Modding Guide — precise, tested, copy-paste ready

The classic Android APK pipeline, end to end:

```
PULL → STUDY → DECODE → EDIT → REBUILD → SIGN → INSTALL → (loop)
```

> **Tested environment** — Windows 11 · Temurin JDK 21.0.12 · apktool 3.0.3 ·
> jadx 1.5.6 · uber-apk-signer 1.3.0 · adb 1.0.41 (24 Oct 2026).
> Every command below was actually run and verified. Where old guides are
> wrong for current versions, it's called out with ⚠️.

## ⚠️ Rules of the road

- **Only mod apps you own, open-source apps, or apps you have permission
  to modify.** Your own builds and F-Droid apps are perfect targets.
- **Never distribute modded APKs.** This is for learning and personal use.
- **If an app defends its license or integrity, walk away.** Defeating
  license checks / DRM / anti-tamper is off-limits — this guide stops at
  that line.
- Repacked "modded" APKs from random sites are a **major malware risk** —
  don't install them.

---

## 1️⃣ One-time setup

### 1.1 Java + adb

```powershell
winget install EclipseAdoptium.Temurin.21.JDK   # Java 17+ required; 21 tested
winget install Google.PlatformTools             # adb
```

**Open a NEW terminal after installing.** Older terminals keep the old PATH —
this is the #1 beginner blocker (`The term 'java' is not recognized…`).

Verify:

```powershell
java -version    # → openjdk version "21.0.12" …
adb version      # → Android Debug Bridge version 1.0.41
```

### 1.2 The three modding tools

| Tool | Version tested | Direct download |
|---|---|---|
| apktool | 3.0.3 | https://github.com/iBotPeaches/Apktool/releases/download/v3.0.3/apktool_3.0.3.jar |
| jadx | 1.5.6 | https://github.com/skylot/jadx/releases/download/v1.5.6/jadx-1.5.6.zip |
| uber-apk-signer | 1.3.0 | https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar |

Target layout (jadx zip extracted into `jadx\`):

```
C:\Users\<you>\ApkMod\
├── apktool_3.0.3.jar
├── uber-apk-signer-1.3.0.jar
├── jadx\bin\jadx.bat, jadx-gui.bat      ← from jadx-1.5.6.zip
├── apktool.bat                          ← wrappers (below)
├── jadx.bat / jadx-gui.bat
├── uber-apk-signer.bat
├── pull-apk.ps1                         ← from this repo, scripts/
├── apk\                                 ← pulled APKs land here
└── work\                                ← decoded project (apktool d)
```

**Wrappers** — one small `.bat` per tool so you never type `java -jar …`:

```bat
@echo off
rem apktool.bat
java -jar "%~dp0apktool_3.0.3.jar" %*
```

```bat
@echo off
rem uber-apk-signer.bat
java -jar "%~dp0uber-apk-signer-1.3.0.jar" %*
```

```bat
@echo off
rem jadx.bat  (jadx's own scripts look at JAVA_HOME, then PATH)
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
call "%~dp0jadx\bin\jadx.bat" %*
```

> If `java` isn't on PATH in your terminal, pin the full path instead.
> Find it with `(Get-Command java).Source` or `where java`, e.g.:
> `"C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot\bin\java.exe" -jar "%~dp0apktool_3.0.3.jar" %*`
> (`%~dp0` = the wrapper's own folder, so jars sit next to the `.bat`.)

**Add `ApkMod` to PATH (optional, for running commands from anywhere):**
`Win+R` → `sysdm.cpl` → Advanced → Environment Variables → *User variables*
→ `Path` → New → paste the ApkMod folder. Open a **new** terminal.

---

## 2️⃣ Step 1 — Get the APK

1. Phone: **Settings → About phone → tap "Build number" 7×** → back →
   **Developer options → USB debugging** ON.
2. Plug in, then check:

   ```powershell
   adb devices
   # List of devices attached
   # R58N12ABCD    device        ✅ ready
   # R58N12ABCD    unauthorized  → unlock phone, tap "Allow" (tick "always")
   # (nothing)                   → other cable/port? `adb kill-server` first
   ```

3. Find the package name (the `com.foo.bar` you pass around):

   ```powershell
   adb shell pm list packages -3             # all user-installed apps
   adb shell pm list packages | findstr kwen # keyword search
   # output format: package:com.example.app  →  strip the "package:" prefix
   ```

4. Pull it:

   ```powershell
   .\pull-apk.ps1 com.example.app
   # Pulling /data/app/~~X/com.example.app-Y/base.apk -> …\ApkMod\apk\com.example.app.apk
   ```

   Script refused? `PSSecurityException: … running scripts is disabled on this
   system` → run once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

   Manual equivalent:

   ```powershell
   adb shell pm path com.example.app        # → package:/data/app/…/base.apk
   adb pull /data/app/…/base.apk apk\com.example.app.apk
   ```

**Split APKs (precise rule):** `pm path` prints **one line = single APK**,
**multiple lines = split bundle** (base + config splits). First mods: only use
apps with one line — the script warns you if it saw more. F-Droid apps are
usually single-APK.

---

## 3️⃣ Step 2 — Study the code (read-only)

```powershell
jadx -d out\java apk\com.example.app.apk   # → readable .java tree
jadx-gui apk\com.example.app.apk           # → browse/search in a GUI
```

Find and **write down**:

- **Text to change** → its resource name (e.g. `app_name`) or a literal in code
- **Logic to change** → fully-qualified class + method, e.g.
  `com.example.feature.Checks → boolean isUnlocked()`

This output is your **map** — you never rebuild from it (jadx output does not
round-trip back into an APK).

Search it: VS Code / Notepad++ `Ctrl+Shift+F` scoped to `out\java`, or:

```powershell
Select-String -Path out\java\**\*.java -Pattern "isUnlocked"
```

---

## 4️⃣ Step 3 — Decode into editable form

```powershell
apktool d apk\com.example.app.apk -o work -f
```

- `-o work` — **always pass it**: default output dir is `apk.out`, not `work`
- `-f` — overwrite an existing `work\`
- decode warning `Invalid resource config detected. Dropping resources` but
  you still want a project? add `--keep-broken-res` and fix that XML later

Result:

```
work\
├── AndroidManifest.xml   readable XML: package, label, permissions, components
├── apktool.yml           build metadata (apkFileName, SDKs, doNotCompress)
├── res\                  resources — EASIEST edits live here
│   ├── values\strings.xml     default texts: <string name="app_name">…
│   ├── values\colors.xml, bools.xml, dimens.xml …
│   ├── xml\*.xml              preference defaults (android:defaultValue)
│   ├── mipmap-*\ic_launcher*.png  launcher icons
│   └── values-*\              translations (values-hi, values-fr …)
├── smali\                THE CODE — first dex
├── smali_classes2\        second dex (if present) — search ALL smali* folders
├── assets\               raw files: web content, json, fonts
├── lib\                  native .so libraries — avoid for now
├── original\             original manifest + old signature — DO NOT EDIT
└── unknown\              files apktool doesn't interpret
```

---

## 5️⃣ Step 4 — Edit (one change at a time!)

### 🟢 Tier A — resources (safest)

Worked example — **rename the app**:

1. `work\AndroidManifest.xml` → find `android:label="@string/app_name"`
   (it may instead be a literal like `android:label="Old Name"`)
2. `work\res\values\strings.xml` → `<string name="app_name">Old Name</string>`
   → change only the text between the tags
3. Literal in the manifest instead? Edit it there. **One source, not both.**

XML precision rules:

- `&` must be written `&amp;` (and `<` as `&lt;`) — a raw `&` breaks the build
- don't touch tags/attributes unless you mean to
- save as **UTF-8** (Notepad++: Encoding → UTF-8; Windows 11 Notepad already is)

Other Tier-A edits:

- **boolean defaults** → `res\values\bools.xml` / `booleans.xml`, or
  `res\xml\*.xml` (`android:defaultValue="false"` → `"true"`)
- **icon** → replace `res\mipmap-*\ic_launcher.png`: **same filename, same
  pixel size**, replace every density folder you touch, and
  `ic_launcher_round.png` too if the manifest references it

### 🟡 Tier B — AndroidManifest.xml

```xml
android:label="New Name"       <!-- app name in the launcher -->
android:enabled="false"        <!-- on <activity>/<service>/<receiver>: disable it -->
```

Removing a `uses-permission` line is risky — apps crash when they call APIs
they no longer hold permission for.

Debuggable build (richer logcat while testing):

```powershell
apktool b work -o app-mod.apk --debuggable    # sets android:debuggable="true"
```

### 🔴 Tier C — smali (actual logic)

1. **Map the class:** `com.example.feature.Checks` (jadx) →
   `work\smali\com\example\feature\Checks.smali` — search **all** `smali*`
   folders in case of multidex.
2. **Find the method** by the name you saw in jadx:
   a `.method … isUnlocked()Z` block ending in `.end method`.
3. Smali rules that actually bite beginners:

   | Rule | Detail |
   |---|---|
   | registers | use only what's declared: `.locals N` → `v0…`; params are `p0` (`this`), `p1`… |
   | types | `Ljava/lang/String;` (object types **end with `;`**), `Z`=boolean, `I`=int, `V`=void |
   | strings | `const-string v0, "text"` — double quotes, `"` inside escaped as `\"` |
   | booleans | `const/4 v0, 0x1` = true, `const/4 v0, 0x0` = false |
   | structure | every `.method` needs its `.end method`; every path out must `return…`/`throw` |

4. Minimal safe edit example:

   ```smali
   const-string v0, "Upgrade to Pro"    # before
   const-string v0, "Hello, Mod!"       # after — same register, same shape
   ```

Broken smali fails the build with an exact **file:line** error → fix right there.
Change **one thing**, then build and test.

---

## 6️⃣ Step 5 — Rebuild

```powershell
apktool b work -o app-mod.apk
# I: Built apk into: C:\…\app-mod.apk
```

- no `-o`? output goes to `work\dist\<name>.apk` (name from `apktool.yml`)
- force a full rebuild: add `-f`
- ⚠️ **apktool 3.x has no `--use-aapt2` flag** — aapt2 is built in. Old guides
  still tell you to add it; here it just fails with
  `Unrecognized option: --use-aapt2`.

---

## 7️⃣ Step 6 — Sign (mandatory)

Android refuses any APK whose signature doesn't match its contents — and your
edit broke the original signature, so **every mod gets re-signed**:

```powershell
uber-apk-signer -a app-mod.apk
# Signed apk : app-mod-aligned-debugSigned.apk      ← same folder as input
# - zipalign verified
# - signature verified [v2, v3]
```

Output suffixes (verified):

| Signing with | Output file |
|---|---|
| default debug keystore | `<name>-aligned-debugSigned.apk` |
| your own keystore | `<name>-aligned-signed.apk` |
| plus | `<output>.idsig` — sidecar file, ignore it |

Your own keystore (stable identity across rebuilds):

```powershell
keytool -genkeypair -v -keystore my.keystore -alias key1 -keyalg RSA `
  -keysize 2048 -validity 10000 -storepass changeit -keypass changeit `
  -dname "CN=You, O=You, C=IN"

uber-apk-signer -a app-mod.apk --ks my.keystore --ksAlias key1 `
  --ksPass changeit --ksKeyPass changeit
```

> ⚠️ the key-password flag is **`--ksKeyPass`** — older cheat sheets write
> `--keyPass`, which uber-apk-signer 1.3.0 doesn't accept.
> Sign in place instead of creating a new file? add `--overwrite`.

**Installing over an app that's already on the phone:** the new signature must
match the installed one. You don't have the developer's keystore, so:

```powershell
adb uninstall com.example.app    # ⚠️ wipes that app's data — back up first
```

---

## 8️⃣ Step 7 — Install & test

```powershell
adb install -r app-mod-aligned-debugSigned.apk    # -r = replace existing
# Success

adb shell pm list packages | findstr example       # confirm it's installed
```

Crash on launch? Read the log:

```powershell
adb logcat -c                                      # clear old noise
adb logcat | findstr /i "FATAL AndroidRuntime"     # reproduce, then Ctrl+C
```

What to read: `FATAL EXCEPTION: main` → `Process: com.example.app, PID: …` →
the exception line under it is your bug.

**The loop:** fix → `apktool b` → sign → install. You decode **once**;
after that it's edit/build/sign forever.

---

## 📋 Cheat sheet

```powershell
adb devices
adb shell pm list packages | findstr example
.\pull-apk.ps1 com.example.app

jadx -d out\java apk\com.example.app.apk          # study (never rebuild from it)
apktool d apk\com.example.app.apk -o work -f      # decode
# …edit ONE thing inside work\…
apktool b work -o app-mod.apk                     # rebuild
uber-apk-signer -a app-mod.apk                    # align + sign
adb install -r app-mod-aligned-debugSigned.apk    # install + test
```

(Plain-text version for Notepad / offline: [`COMMANDS.txt`](COMMANDS.txt))

---

## 🧯 Common errors — exact strings → fixes

| You see | Because | Do this |
|---|---|---|
| `Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match…]` | modded signature ≠ installed app's | `adb uninstall com.example.app` (loses data), then install |
| `Failure [INSTALL_FAILED_VERSION_DOWNGRADE]` | your base APK is older than what's installed | uninstall first, then install |
| `INSTALL_FAILED_ALREADY_EXISTS` | replacing without `-r` | add `-r` |
| `INSTALL_PARSE_FAILED_NOT_APKS` | it's an XAPK/APKS bundle, not an APK | pick a single-APK app |
| `The term 'java' is not recognized…` | stale terminal PATH | open a NEW terminal, or pin the full java path in the wrapper |
| `… running scripts is disabled on this system` | PowerShell execution policy | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| `Unrecognized option: --use-aapt2` | flag doesn't exist in apktool 3.x | drop it (aapt2 is built in) |
| `Invalid resource config detected. Dropping resources` | decode dropped a resource | re-decode with `--keep-broken-res`, fix that XML, rebuild |
| `brut.androlib.AndrolibException: …framework…` | missing framework | `apktool if framework.apk` |
| `java.lang.UnsupportedClassVersionError` | Java too old | install JDK 17+ (`java -version` must show it) |
| build error pointing at `Some.smali:123` | your smali edit is malformed | fix line 123 — register/type/quotes/`.end method` |
| jadx outputs nothing / `Unsupported file format` | bundle, protected, or not an APK | wrong file type — go back to Step 1 |
| `adb devices` shows `unauthorized` | phone prompt not accepted | unlock phone → Allow |
| app force-closes only after your edit | your change broke logic | `adb logcat` → read the exception → revert last change |

---

## 🏅 Good habits

- `work\` is your source of truth — if it gets mangled, delete it and decode
  fresh from the original APK (your edits are the only thing you'd redo).
- One change at a time — build + install + test after **each**.
- Keep the **original APK untouched**; work only on copies.
- Never distribute modded APKs.

## 📜 License

MIT — see [LICENSE](LICENSE). Guide content is educational; you're responsible
for only modding apps you have the right to modify.
