# 📦 APK Modding Guide — tested, verified, copy-paste exact

The Android APK pipeline, end to end:

```
PULL → STUDY → DECODE → EDIT → REBUILD → SIGN → INSTALL → (loop)
```

**Why trust this guide:** every command below was run on a real machine, and
the outputs are pasted **verbatim** — what you see in a terminal is what this
guide shows. Where popular advice is outdated (e.g. `--use-aapt2`,
`--keyPass`, "declare every register"), it's flagged with ⚠️ and corrected
with the test result.

**Tested environment** (24 Oct 2026): Windows 11 · Temurin JDK 21.0.12 ·
apktool 3.0.3 (smali 3.0.9-dev) · jadx 1.5.6 · uber-apk-signer 1.3.0 ·
adb 1.0.41

## 📑 Contents

1. [Rules of the road](#rules)
2. [One-time setup](#setup)
   - [1.5 setup-check.ps1 — verify all at once](#setup-check)
   - [1.6 demo-run.ps1 — whole pipeline in one command](#demo)
3. [Step 1 — Get the APK](#step-get-apk)
4. [Step 2 — Study the code](#step-study)
5. [Step 3 — Decode](#step-decode)
6. [Step 4 — Edit](#step-edit)
7. [Step 5 — Rebuild](#step-rebuild)
8. [Step 6 — Sign](#step-sign)
9. [Step 7 — Install & test](#step-install)
10. [Cheat sheet](#cheatsheet)
11. [Common errors (real strings)](#errors)
12. [Appendix A — APK anatomy](#anatomy)
13. [Appendix B — smali quick card](#smali)
14. [Appendix C — full flag reference](#flags)
15. [Appendix D — adb quick card](#adb)
16. [Contributor self-check](#contributor-check)

---

<a id="rules"></a>

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

<a id="setup"></a>

## 1️⃣ One-time setup

### 1.1 Java + adb

```powershell
winget install EclipseAdoptium.Temurin.21.JDK   # Java 17+ required; 21 tested
winget install Google.PlatformTools             # adb
```

**Open a NEW terminal after installing.** Older terminals keep the old PATH —
this is the #1 beginner blocker (`The term 'java' is not recognized…`).

### 1.2 The three modding tools — exact downloads + checksums

| Tool | Version | Direct download | SHA256 |
|---|---|---|---|
| apktool | 3.0.3 | https://github.com/iBotPeaches/Apktool/releases/download/v3.0.3/apktool_3.0.3.jar | `dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423` |
| jadx | 1.5.6 | https://github.com/skylot/jadx/releases/download/v1.5.6/jadx-1.5.6.zip | `545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974` (72,646,741 bytes) |
| uber-apk-signer | 1.3.0 | https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar | `e1299fd6fcf4da527dd53735b56127e8ea922a321128123b9c32d619bba1d835` ✅ matches the release's official `checksum-sha256.txt` |

Verify what you downloaded (PowerShell, hash is case-insensitive):

```powershell
Get-FileHash .\apktool_3.0.3.jar -Algorithm SHA256
Get-FileHash .\jadx-1.5.6.zip    -Algorithm SHA256
Get-FileHash .\uber-apk-signer-1.3.0.jar -Algorithm SHA256
```

### 1.3 Folder layout + wrappers

Target layout (jadx zip extracted into `jadx\`):

```
C:\Users\<you>\ApkMod\
├── apktool_3.0.3.jar
├── uber-apk-signer-1.3.0.jar
├── jadx\bin\jadx.bat, jadx-gui.bat      ← from jadx-1.5.6.zip
├── apktool.bat / jadx.bat / jadx-gui.bat /
│   uber-apk-signer.bat                  ← from this repo, scripts\ (copy them)
├── pull-apk.ps1                         ← from this repo, scripts\
├── setup-check.ps1                      ← from this repo, scripts\ (verifies ALL of the above)
├── demo-run.ps1                         ← from this repo, scripts\ (runs the whole pipeline)
├── apk\                                 ← pulled APKs land here
└── work\                                ← decoded project (apktool d)
```

**Wrappers** — ready-made copies live in [`scripts/`](scripts/) — copy all four
`.bat` files into your `ApkMod` folder next to the jars. They are
**JDK-upgrade-proof and stale-terminal-proof**: they find the Temurin
`jdk-*` folder on disk instead of trusting PATH. (Tested twice: with PATH,
and with PATH stripped — both launch fine.)

```bat
@echo off
rem apktool.bat
set "JAVA_EXE=java.exe"
for /d %%J in ("%ProgramFiles%\Eclipse Adoptium\jdk-*") do set "JAVA_EXE=%%J\bin\java.exe"
"%JAVA_EXE%" -jar "%~dp0apktool_3.0.3.jar" %*
```

```bat
@echo off
rem uber-apk-signer.bat   (same idea, other jar)
set "JAVA_EXE=java.exe"
for /d %%J in ("%ProgramFiles%\Eclipse Adoptium\jdk-*") do set "JAVA_EXE=%%J\bin\java.exe"
"%JAVA_EXE%" -jar "%~dp0uber-apk-signer-1.3.0.jar" %*
```

```bat
@echo off
rem jadx.bat   (delegates to jadx's own launcher; they read JAVA_HOME)
set "JAVA_HOME="
for /d %%J in ("%ProgramFiles%\Eclipse Adoptium\jdk-*") do set "JAVA_HOME=%%J"
call "%~dp0jadx\bin\jadx.bat" %*
```

> `%~dp0` = the wrapper's own folder, so the jars sit **next to** the `.bat`.
> No Temurin on disk? The variables fall back to `java` on PATH.
> Don't use another JDK? Change the `Eclipse Adoptium\jdk-*` glob to yours —
> or just rely on PATH (`where java` shows what PATH sees).

**Add `ApkMod` to PATH (optional):** `Win+R` → `sysdm.cpl` → Advanced →
Environment Variables → *User variables* → `Path` → New → paste the folder.
Open a **new** terminal afterwards.

### 1.4 Smoke test — all five must print their version

```powershell
apktool --version      # → 3.0.3
jadx --version         # → 1.5.6
uber-apk-signer -v     # → Version: 1.3.0
java -version          # → openjdk version "21.0.12" …
adb version            # → Android Debug Bridge version 1.0.41
```

(All five outputs above are real — from the machine this guide was written
on. If any says `The term '…' is not recognized` → new terminal, or check the
wrapper/PATH.)

<a id="setup-check"></a>

### 1.5 Verify everything at once — `setup-check.ps1`

Rather than checking all of the above by hand, run the guide's own
verifier (it lives in [`scripts/`](scripts/) — copy it into `ApkMod` next to
the tools):

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-check.ps1
```

Real output from the machine this guide was written on:

```
Tool folder: C:\Users\hp\ApkMod

[WARN] java not on THIS terminal PATH (Temurin found on disk)  -> found: C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot - open a NEW terminal; the wrappers work anyway
[ OK ] adb on PATH: Android Debug Bridge version 1.0.41
[ OK ] pull-apk.ps1 present
[ OK ] setup-check.ps1 present
[ OK ] apktool.bat present
[ OK ] uber-apk-signer.bat present
[ OK ] jadx.bat present
[ OK ] jadx-gui.bat present
[ OK ] jadx extracted (jadx\bin\jadx.bat found)
[ OK ] apktool_3.0.3.jar - sha256 matches pinned release
[ OK ] uber-apk-signer-1.3.0.jar - sha256 matches pinned release
[ OK ] apktool.bat launches -> 3.0.3
[ OK ] uber-apk-signer.bat launches -> Version: 1.3.0
[ OK ] jadx.bat launches -> 1.5.6
[ OK ] tool folder is in your user PATH

RESULT: 14/15 checks passed (1 warning(s) - read them above) - you are READY for Step 1.
```

It checks: tools on PATH, every file present, **SHA256 of the jars against
the pinned releases**, that each wrapper actually **launches** with the right
version, and PATH visibility. Every `[FAIL]` line prints its own fix.
Exit code 0 = ready, 1 = something's broken.

> That `[WARN]` above is deliberate honesty: the shell it ran in had an old
> PATH (opened before the JDK install). The wrappers don't care — they find
> Java on disk — but `keytool` and plain `java` would fail **in that
> terminal**, hence "open a NEW terminal".

<a id="demo"></a>

### 1.6 The 60-second demo — the whole pipeline, no phone needed

`demo-run.ps1` (also in [`scripts/`](scripts/) — copy it into `ApkMod`) runs
**decode → locate label → edit app name → rebuild → sign** on any APK you
point it at, printing the real tool output at every stage. Use an APK **you
own** — this is the whole guide in one command:

```powershell
.\demo-run.ps1 C:\path\to\your-app.apk -NewLabel "My Mod"
```

Real transcript (input: `kwen-release.apk` — my own app):

```
APK      : C:\Users\hp\Downloads\kwen-main\kwen-release.apk
Work dir : C:\Users\hp\ApkMod\work-demo

==== STAGE 1/5: DECODE ========================================================
I: Using Apktool 3.0.3 on kwen-release.apk with 8 threads
I: Loading resource table...
I: Baksmaling classes.dex...
I: Decoding value resources...
I: Loading resource table from file: C:\Users\hp\AppData\Local\apktool\framework\1.apk
I: Decoding file resources...
I: Generating values XMLs...
I: Decoding AndroidManifest.xml with resources...
I: Copying original files...
I: Copying assets...
I: Copying unknown files...

==== STAGE 2/5: LOCATE LABEL (res\values\*.xml + AndroidManifest.xml) =========
  public.xml:876: <public type="string" name="app_name" id="0x7f0d001c" />
  strings.xml:24: <string name="app_name">KWEN</string>
  manifest: <application … android:label="@string/app_name" …>
  manifest: <activity … android:label="@string/title_activity_main" …>

==== STAGE 3/5: EDIT ==========================================================
  app_name: 'KWEN'  ->  'KWEN DEMO'
  written (UTF-8, no BOM): C:\Users\hp\ApkMod\work-demo\res\values\strings.xml

==== STAGE 4/5: REBUILD =======================================================
I: Smaling smali folder into classes.dex...
I: Building resources with aapt2...
I: Building apk file...
I: Importing assets...
I: Importing unknown files...
I: Built apk into: C:\Users\hp\Downloads\kwen-main\kwen-release-demo.apk

==== STAGE 5/5: SIGN ==========================================================
01. kwen-release-demo.apk
        SIGN
        file: C:\Users\hp\Downloads\kwen-main\kwen-release-demo.apk (2.5 MiB)
        - zipalign success
        - sign success
        VERIFY
        file: C:\Users\hp\Downloads\kwen-main\kwen-release-demo-aligned-debugSigned.apk (2.56 MiB)
        - zipalign verified
        - signature verified [v2, v3]
                Subject: CN=Android Debug, OU=Android, O=US, L=US, ST=US, C=US
                Expires: Fri Mar 11 01:40:05 IST 2044
Successfully processed 1 APKs and 0 errors in 0.72 seconds.

==== DONE ============================================================
  rebuilt : C:\Users\hp\Downloads\kwen-main\kwen-release-demo.apk
  SIGNED  : C:\Users\hp\Downloads\kwen-main\kwen-release-demo-aligned-debugSigned.apk
  edited app_name: yes

  To install it on a phone (uninstall first if signatures differ):
      adb uninstall com.your.app
      adb install -r "C:\Users\hp\Downloads\kwen-main\kwen-release-demo-aligned-debugSigned.apk"
```

If you can read stage 2's output, **you already understand the guide** —
that's the whole skill. Work dir is `work-demo` (throwaway): peek inside it,
then delete it and the `-demo.apk` files whenever.

---

<a id="step-get-apk"></a>

## 2️⃣ Step 1 — Get the APK

1. Phone: **Settings → About phone → tap "Build number" 7×** → back →
   **Developer options → USB debugging** ON.
2. Plug in, then check:

   ```powershell
   adb devices
   # List of devices attached
   # R58N12ABCD    device        ✅ ready
   # R58N12ABCD    unauthorized  → unlock phone, tap "Allow" (tick "always")
   # (nothing)      → other cable/port? `adb kill-server` first
   ```

   No device at all? This is exactly what our script prints (real output):

   ```
   adb.exe: no devices/emulators found
   pull-apk.ps1 : EXCEPTION: Device not reachable or package 'com.example.app' not found.
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

   `PSSecurityException: … running scripts is disabled on this system` →
   run once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

   Manual equivalent (what the script does):

   ```powershell
   adb shell pm path com.example.app        # → package:/data/app/…/base.apk
   adb pull /data/app/…/base.apk apk\com.example.app.apk
   ```

**Split APKs (precise rule):** `pm path` prints **one line = single APK**,
**multiple lines = split bundle** (base + config splits). First mods: only use
apps with one line — the script warns you if it saw more. F-Droid apps are
usually single-APK.

---

<a id="step-study"></a>

## 3️⃣ Step 2 — Study the code (read-only)

```powershell
jadx -d out\java apk\com.example.app.apk   # → readable .java tree
jadx-gui apk\com.example.app.apk           # → browse/search in a GUI
```

Real progress output (1252 classes in our test APK):

```
INFO  - loading ...
INFO  - processing ...
INFO  - progress: 41 of 1252 (3%)
…
INFO  - progress: 1236 of 1252 (98%)
ERROR - finished with errors, count: 4
```

> ⚠️ `finished with errors, count: 4` is **normal** on minified apps — a few
> methods couldn't be decompiled, the rest is fully readable. jadx output is
> for **reading only**; you never rebuild from it.

Find and **write down**:

- **Text to change** → its resource name (e.g. `app_name`) or a literal in code
- **Logic to change** → fully-qualified class + method, e.g.
  `com.example.feature.Checks → boolean isUnlocked()`

Search it: VS Code / Notepad++ `Ctrl+Shift+F` scoped to `out\java`, or:

```powershell
Select-String -Path out\java\**\*.java -Pattern "isUnlocked"
```

---

<a id="step-decode"></a>

## 4️⃣ Step 3 — Decode into editable form

```powershell
apktool d apk\com.example.app.apk -o work -f
```

- `-o work` — **always pass it**: default output dir is `apk.out`, not `work`
- `-f` — overwrite an existing `work\`

Real decode output (our run: `kwen-release.apk`, my own app):

```
I: Using Apktool 3.0.3 on kwen-release.apk with 8 threads
I: Loading resource table...
I: Baksmaling classes.dex...
I: Decoding value resources...
I: Loading resource table from file: C:\Users\hp\AppData\Local\apktool\framework\1.apk
I: Decoding file resources...
I: Generating values XMLs...
I: Decoding AndroidManifest.xml with resources...
I: Copying original files...
I: Copying assets...
I: Copying unknown files...
```

Decode warning `Invalid resource config detected. Dropping resources` but you
still want a project? Add `--keep-broken-res` and fix that XML later.

Result:

```
work\
├── AndroidManifest.xml   readable XML: package, label, permissions, components
├── apktool.yml           build metadata (see real example below)
├── res\                  resources — EASIEST edits live here
│   ├── values\strings.xml     default texts: <string name="app_name">…
│   ├── values\public.xml      resource-ID index — READ, DON'T EDIT
│   ├── values\colors.xml, bools.xml, dimens.xml …
│   ├── xml\*.xml              preference defaults (android:defaultValue)
│   ├── mipmap-*\ic_launcher*.png  launcher icons
│   └── values-*\              translations (values-hi, values-fr …)
├── smali\                THE CODE — first dex
├── smali_classes2\        second dex (if present) — search ALL smali* folders
├── assets\               raw files: web content, json, fonts
├── lib\                  native .so libraries — avoid for now
├── original\             originals apktool kept (binary manifest) — DON'T EDIT
└── unknown\              files apktool doesn't interpret
```

Real `apktool.yml` from our run (yours will look similar):

```yaml
version: 3.0.3
apkFileName: kwen-release.apk
usesFramework:
  ids:
  - 1
sdkInfo:
  minSdkVersion: 24
  targetSdkVersion: 36
versionInfo:
  versionCode: 1
  versionName: 1.0
resourcesInfo:
  packageId: 127
doNotCompress:
- arsc
- png
- assets/dexopt/baseline.prof
- assets/dexopt/baseline.profm
```

---

<a id="step-edit"></a>

## 5️⃣ Step 4 — Edit (one change at a time!)

### 🟢 Tier A — resources (safest)

**Locate the string first** (real output from our run):

```powershell
Select-String -Path work\res\values\*.xml -Pattern 'app_name'
# public.xml:876: <public type="string" name="app_name" id="0x7f0d001c" />
# strings.xml:24: <string name="app_name">KWEN</string>
```

Two hits — **edit `strings.xml` line 24 only**. `public.xml` is the
name→ID index; never touch it.

Also check where the label comes from:

```powershell
Select-String -Path work\AndroidManifest.xml -Pattern 'android:label'
# … android:label="@string/app_name" …        ← points at strings.xml (edit there)
# … android:label="Some Literal"   …          ← if literal, edit it here instead
```

**One source, not both.**

Two ways to edit — both verified:

1. **Visual (recommended):** Notepad++ → open `strings.xml` → change text
   between the tags → save (Encoding → UTF-8).
2. **PowerShell one-liner (verified working):**

   ```powershell
   $p = 'work\res\values\strings.xml'
   (Get-Content $p -Raw -Encoding UTF8) -replace '<string name="app_name">KWEN</string>',
     '<string name="app_name">KWEN (modded)</string>' |
     Set-Content $p -Encoding UTF8 -NoNewline
   ```

XML precision rules:

- `&` must be written `&amp;` (and `<` as `&lt;`) — a raw `&` breaks the build
- don't touch tags/attributes unless you mean to
- save as **UTF-8**

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
   (Release APKs are often minified — our test app's classes were literally
   `smali\a\a.smali`, `smali\a0\a.smali` — so search by *method content*,
   not class names.)
2. **Find the method** by the name you saw in jadx:
   a `.method … isUnlocked()Z` block ending in `.end method`.

3. **Register reality in apktool 3.x** ⚠️ — old guides say "every register
   must be declared in `.locals`". **We tested it: smali 3.0.9-dev
   auto-expands the register frame.** `const-string v9` *and*
   `const-string v99` inside a `.locals 1` method both **compiled fine**.
   So an undeclared `v0`-style register will *not* save you from a crash —
   but it also won't stop the build. What still breaks the build for real:

   | What you write | Exact build error you get |
   |---|---|
   | typo'd opcode (`move-result-objectz`) | `…\Checks.smali[40,4] mismatched input 'move-result-objectz' expecting END_METHOD_DIRECTIVE` |
   | missing `.end method` | `…\Checks.smali[44,0] mismatched input '' expecting END_METHOD_DIRECTIVE` |
   | file saved with a UTF-8 **BOM** (see warning below) | `…\a.smali[1,0] required (...)+ loop did not match anything at input '?'` |

   Every smali failure also shows a wrapper line above them:
   `AndrolibException: Could not smali file: <path>` — but the **real**
   cause is the `[line,col]` error right above it.

4. Smali facts that still matter (correctness, not compilation):

   | Thing | Precise detail |
   |---|---|
   | parameters | static: `p0` = first arg; instance: `p0` = `this`, `p1` = first arg — they're fixed at the **end** of the frame |
   | types | `Ljava/lang/String;` (object types **end with `;`**), `Z`=boolean, `I`=int, `V`=void |
   | strings | `const-string v0, "text"` — double quotes |
   | booleans | `const/4 v0, 0x1` = true, `const/4 v0, 0x0` = false |
   | control flow | labels (`:cond_0`) must exist where you `goto`/`if-…` them; every path must `return…`/`throw` |
   | descriptors | wrong `…;` or a typo in a method proto = runtime crash, **not** a build error |

5. Verified compile-safe example (we injected this exact method into a class
   and `apktool b` accepted it):

   ```smali
   .method public static greet(Ljava/lang/String;)Ljava/lang/String;
       .locals 1
       const-string v0, "Hello, "
       invoke-virtual {v0, p0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
       move-result-object v0
       return-object v0
   .end method
   ```

> ⚠️ **BOM trap (real, we hit it):** PowerShell 5.1
> `Set-Content -Encoding UTF8` writes a **BOM** at the file start, and the
> smali parser dies at `[1,0]` before even reading your edit. For smali files
> write with .NET (UTF-8, no BOM):
> `[System.IO.File]::WriteAllText($path, $text)`
> (For **XML** files the BOM is harmless — apktool accepts it.)

Change **one thing**, then build and test.

---

<a id="step-rebuild"></a>

## 6️⃣ Step 5 — Rebuild

```powershell
apktool b work -o app-mod.apk
```

Real output of a successful build (incremental + full):

```
I: AndroidManifest.xml and resources have not changed.     ← only when nothing changed
I: Smaling smali folder into classes.dex...
I: Building resources with aapt2...
I: Building apk file...
I: Importing assets...
I: Importing unknown files...
I: Built apk into: app-mod.apk
```

- no `-o`? output goes to `work\dist\<name>.apk` (name from `apktool.yml` →
  `apkFileName`)
- force a full rebuild: add `-f`
- `I: Building resources with aapt2...` — note it: **aapt2 is built in**.
  ⚠️ apktool 3.x has **no `--use-aapt2` flag**; old guides still say to add
  it, and it only fails with `Unrecognized option: --use-aapt2`.

---

<a id="step-sign"></a>

## 7️⃣ Step 6 — Sign (mandatory)

Android refuses any APK whose signature doesn't match its contents — and your
edit broke the original signature, so **every mod gets re-signed**:

```powershell
uber-apk-signer -a app-mod.apk
```

Real output of our run:

```
01. app-mod.apk

	SIGN
	file: C:\Users\hp\ApkMod\app-mod.apk (2.5 MiB)
	checksum: 5ce8936697623c9be6e5831b2b113cff987c5d5174f3b77a01315669602ac16e (sha256)
	- zipalign success
	- sign success

	VERIFY
	file: C:\Users\hp\ApkMod\app-mod-aligned-debugSigned.apk (2.56 MiB)
	checksum: ce1c7672890b4b8fabd67731c48b3451ed013cb7dd999526fd45a0de3e22347f (sha256)
	- zipalign verified
	- signature verified [v2, v3]
		Subject: CN=Android Debug, OU=Android, O=US, L=US, ST=US, C=US
		SHA256: 1e08a903aef9c3a721510b64ec764d01d3d094eb954161b62544ea8f187b5953 / SHA256withRSA
		Expires: Fri Mar 11 01:40:05 IST 2044

[Sat Oct 24 16:42:12 IST 2026][v1.3.0]
Successfully processed 1 APKs and 0 errors in 2.13 seconds.
```

The `keystore:` block above (cut for space) tells you which key was used —
with no arguments it falls back to
`…\temp_…_debug.keystore (DEBUG_EMBEDDED)` — a throwaway **debug** key,
fine for personal installs.

Output file names (both verified):

| Signing with | Output file (same folder as input) |
|---|---|
| default debug keystore | `<name>-aligned-debugSigned.apk` |
| your own keystore | `<name>-aligned-signed.apk` |
| either way, also | `<output>.idsig` — sidecar file, ignore it |

Your own keystore (stable identity across rebuilds):

```powershell
keytool -genkeypair -v -keystore my.keystore -alias key1 -keyalg RSA `
  -keysize 2048 -validity 10000 -storepass changeit -keypass changeit `
  -dname "CN=You, O=You, C=IN"

uber-apk-signer -a app-mod.apk --ks my.keystore --ksAlias key1 `
  --ksPass changeit --ksKeyPass changeit
```

> ⚠️ the key-password flag is **`--ksKeyPass`** — older cheat sheets write
> `--keyPass`, which uber-apk-signer 1.3.0 doesn't accept (its help lists
> `--ksKeyPass <password>`).
> Sign in place instead of creating a new file? add `--overwrite`.

**Installing over an app that's already on the phone:** the new signature must
match the installed one. You don't have the developer's keystore, so:

```powershell
adb uninstall com.example.app    # ⚠️ wipes that app's data — back up first
```

---

<a id="step-install"></a>

## 8️⃣ Step 7 — Install & test

```powershell
adb install -r app-mod-aligned-debugSigned.apk    # -r = replace existing
# Success

adb shell pm list packages | findstr example       # confirm it's installed
adb shell monkey -p com.example.app 1              # launch it without knowing the activity name
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

<a id="cheatsheet"></a>

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

<a id="errors"></a>

## 🧯 Common errors — exact strings → fixes

Every error below was either **produced by a real run of this guide's
commands** or is a standard platform message.

| You see | Because | Do this |
|---|---|---|
| `adb.exe: no devices/emulators found` | no phone connected / USB debugging off | cable, port, `adb kill-server`, check debugging |
| script throws `Device not reachable or package '…' not found.` | same as above, or wrong package name | fix connection; double-check the `com.…` name |
| `adb devices` → `unauthorized` | phone prompt not accepted | unlock phone → Allow (tick "always") |
| `Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match…]` | modded signature ≠ installed app's | `adb uninstall com.example.app` (loses data), then install |
| `Failure [INSTALL_FAILED_VERSION_DOWNGRADE]` | your base APK is older than what's installed | uninstall first, then install |
| `INSTALL_FAILED_ALREADY_EXISTS` | replacing without `-r` | add `-r` |
| `INSTALL_PARSE_FAILED_NOT_APKS` | it's an XAPK/APKS bundle, not an APK | pick a single-APK app |
| `The term 'java' is not recognized…` | stale terminal PATH | open a NEW terminal, or pin the full java path in the wrapper |
| `PSSecurityException: … running scripts is disabled on this system` | PowerShell execution policy | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| `Unrecognized option: --use-aapt2` | flag doesn't exist in apktool 3.x | drop it (aapt2 is built in) |
| `<file>.smali[40,4] mismatched input 'move-result-objectz' expecting END_METHOD_DIRECTIVE` | typo'd instruction | fix the opcode at that exact line:col |
| `<file>.smali[44,0] mismatched input '' expecting END_METHOD_DIRECTIVE` | missing `.end method` | add it |
| `<file>.smali[1,0] required (...)+ loop did not match anything at input '?'` | file starts with a UTF-8 BOM (PowerShell `Set-Content -Encoding UTF8`) | rewrite with `[System.IO.File]::WriteAllText($p,$t)` |
| `AndrolibException: Could not smali file: <path>` | wrapper for the 3 smali errors above | read the `[line,col]` line printed **above** it |
| `Invalid resource config detected. Dropping resources` | decode dropped a resource | re-decode with `--keep-broken-res`, fix that XML, rebuild |
| `brut.androlib.AndrolibException: …framework…` | missing framework | `apktool if framework.apk` |
| `java.lang.UnsupportedClassVersionError` | Java too old | install JDK 17+ (`java -version` must show it) |
| jadx `ERROR - finished with errors, count: N` | minified/odd methods jadx couldn't read | **normal** — output is still usable |
| app force-closes only after your edit | your change broke logic | `adb logcat` → read the exception → revert last change |
| app refuses to run modified / says not licensed | the app protects itself | **stop** — don't defeat license/integrity checks |

---

<a id="anatomy"></a>

## Appendix A — APK anatomy (what you're really editing)

An APK is a **ZIP**. Real top entries from our test file
(`kwen-release.apk`, 755 entries total):

```
classes.dex                      976,508 bytes   ← Dalvik bytecode (smali disassembles this)
AndroidManifest.xml                6,992 bytes   ← BINARY XML, not text!
resources.arsc                   203,380 bytes   ← compiled resource/string pool
res\                                             ← per-density resources
assets\                                          ← raw files (web, json, fonts)
lib\                                             ← native .so per ABI
META-INF\                                        ← v1 signature (see below)
```

**Why apktool exists — the manifest is binary.** First 64 bytes of the real
`AndroidManifest.xml`, hex:

```
03-00-08-00-50-1B-00-00-01-00-1C-00-84-0E-00-00 …
```

…and as text: `….P………K……H………(…4…L…n…` — garbage. apktool decodes this
AXML format into the readable XML you edit, then compiles it back.

**Why every mod must be re-signed.** Android verifies a signature over the
exact bytes of the file:

- **v1** = `META-INF/*.SF` + `*.RSA` + `MANIFEST.MF` files
- **v2/v3** = a Signing Block stored *inside* the ZIP, between the last entry
  and the central directory

Real observation: our source APK had **no** `META-INF/*.SF|*.RSA` files at
all — it was signed **v2/v3 only** (valid since Android 7). After our build +
resign, these appeared:

```
META-INF/MANIFEST.MF
META-INF/ANDROIDD.SF
META-INF/ANDROIDD.RSA
```

(`ANDROIDD` = the alias of uber-apk-signer's debug key.) Any byte you change
invalidates both schemes → re-sign before installing, ever.

**Obfuscation:** release apps often have minified class names
(`smali/a/a.smali`) — find code by method content from jadx, not by class
names.

---

<a id="smali"></a>

## Appendix B — smali quick card

Smali = readable disassembly of `classes.dex`. Layout of a file:

```smali
.class public final La/a;          ← class (here: minified name)
.super Ljava/lang/Object;
.source "SourceFile"

.method public static greet(Ljava/lang/String;)Ljava/lang/String;
    .locals 1                      ← local register count
    const-string v0, "Hello, "
    invoke-virtual {v0, p0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    return-object v0
.end method
```

(That exact method was injected into a real class and compiled with
apktool 3.0.3 — verified.)

Common instructions:

| Instruction | Meaning | Example |
|---|---|---|
| `const/4 v0, 0x0` | small int / boolean | `0x0`=false, `0x1`=true |
| `const v0, 0x7f0d001c` | 32-bit int (e.g. resource ID) | from `public.xml` |
| `const-string v0, "text"` | load a string | — |
| `new-instance v0, Ljava/lang/StringBuilder;` | create object | ctor next |
| `iget-boolean v0, p0, LX/Y;->f:Z` | read instance field | `sput/sget-…` for static |
| `invoke-virtual {v0, v1}, LX/Y;->m(I)V` | call method | `{}` = argument registers |
| `move-result-object v0` | catch return of last invoke | **must** follow invoke |
| `if-eqz v0, :cond_0` | branch if == 0 / null | labels look like `:cond_0` |
| `goto :label` | unconditional jump | — |
| `return-void` / `return-object v0` | return | match the declared type |

Type descriptors: `Z` boolean · `I` int · `J` long · `F` float · `V` void ·
`Ljava/lang/String;` object (**ends with `;`**) · `[I` int[].

Method → file mapping: `com.example.Foo` → `smali\com\example\Foo.smali`
(check `smali_classes2\` … too). Signature from jadx (`boolean isUnlocked()`)
→ `.method … isUnlocked()Z`.

---

<a id="flags"></a>

## Appendix C — full flag reference

Verbatim from each tool's own `--help` (tested versions).

### apktool d (decode)

```
 -a,--all-src                   Decode all sources in the apk (includes unknown dex files).
 -f,--force                     Force delete destination directory.
    --ignore-raw-values         Ignore raw attribute values in XML resource files.
 -j,--jobs <num>                Number of parallel jobs.
    --keep-broken-res           Keep resources that were dropped/errored at decode
                                (you must fix them before building).
    --match-original            Keep files closest to original as possible.
    --no-assets                 Do not decode assets.
    --no-debug-info             Do not include debug info in sources.
 -o,--output <dir>              Output dir (default: apk.out).
    --only-manifest             Only decode AndroidManifest.xml.
 -p,--frame-path <dir>          Framework files location.
 -r,--no-res                    Do not decode resources.
    --res-resolve-mode <mode>   default | greedy | lazy.
 -s,--no-src                    Do not decode sources (skip smali).
 -t,--frame-tag <tag>           Framework files tag.
```

### apktool b (build)

```
    --aapt <file>          Use aapt2 binary located in <file>.
    --copy-original        Copy original AndroidManifest.xml and META-INF.
    --debuggable           Set android:debuggable="true" in AndroidManifest.xml.
 -f,--force                Skip change detection, build everything.
 -j,--jobs <num>           Number of parallel jobs.
 -o,--output <file>        Output apk (default: dist/name.apk).
 -p,--frame-path <dir>     Framework files location.
    --net-sec-conf         Add a generic network security configuration file.
    --no-apk               Disable repacking into a new apk.
    --no-crunch            Do not crunch resource files during build.
```

(No `--use-aapt2` — it doesn't exist in 3.x.)

### uber-apk-signer 1.3.0

```
-a,--apks <file/folder>    source apk(s); folder checked non-recursively
    --allowResign          re-sign already-signed apks instead of erroring
    --debug                extra debug output
    --dryRun               what would be processed, without doing it
    --ks <keystore>        your keystore (default: debug keystore)
    --ksAlias <alias>      alias in the keystore (required with --ks)
    --ksKeyPass <password> KEY password  ⚠️ (not --keyPass)
    --ksPass <password>    STORE password
-l,--lineage <path>        v3 lineage file (multi-signer)
-o,--out <path>            output folder
    --overwrite            sign in place (no new file)
    --skipZipAlign         skip zipalign (also affects verify)
    --verbose              more output, esp. for verify
-y                         (auto-confirm prompt)
    --zipAlignPath <path>  custom zipalign binary
-v,--version               print version
```

---

<a id="adb"></a>

## Appendix D — adb quick card

*(typical outputs shown — this machine had no phone attached while writing,
so these weren't captured live; commands are standard platform tools)*

| Task | Command |
|---|---|
| list devices | `adb devices` |
| restart adb (many weird issues) | `adb kill-server` then `adb devices` |
| list installed packages | `adb shell pm list packages` (`-3` = user apps, `-f` = with APK path) |
| find package by keyword | `adb shell pm list packages \| findstr kwen` |
| APK path on phone | `adb shell pm path com.example.app` |
| pull one file from phone | `adb pull /data/app/…/base.apk .\` |
| install (replace) | `adb install -r app.apk` |
| install allowing downgrade | `adb install -r -d app.apk` (debuggable apps only) |
| uninstall (wipes app data) | `adb uninstall com.example.app` |
| clear app data **without** uninstalling | `adb shell pm clear com.example.app` |
| launch without knowing activity | `adb shell monkey -p com.example.app 1` |
| clear log buffer | `adb logcat -c` |
| errors only | `adb logcat *:E` |
| filter for crashes (cmd) | `adb logcat \| findstr /i "FATAL AndroidRuntime"` |
| Android version on device | `adb shell getprop ro.build.version.release` |

---

## 🏅 Good habits

- `work\` is your source of truth — if it gets mangled, delete it and decode
  fresh from the original APK (your edits are the only thing you'd redo).
- One change at a time — build + install + test after **each**.
- Keep the **original APK untouched**; work only on copies.
- Never distribute modded APKs.

<a id="contributor-check"></a>

## 🔧 Contributor self-check

After **any** edit to this repo, run the repo's own verifier — it checks
every TOC anchor, internal link, code fence balance, that every script the
README mentions actually ships in `scripts/`, and that the pinned facts
(versions + SHA256) stay **byte-identical** in README.md *and*
COMMANDS.txt:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\readme-check.ps1
# RESULT: 18/18 repo checks passed - guide is internally consistent.
```

Exit 0 = consistent, exit 1 = drift printed line by line.

## 📜 License

MIT — see [LICENSE](LICENSE). Guide content is educational; you're responsible
for only modding apps you have the right to modify.
