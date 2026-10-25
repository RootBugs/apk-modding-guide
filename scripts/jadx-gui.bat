@echo off
rem jadx-gui.bat - delegates to jadx's own GUI launcher (same Java logic
rem as jadx.bat: Temurin jdk-* if present, else PATH).
set "JAVA_HOME="
for /d %%J in ("%ProgramFiles%\Eclipse Adoptium\jdk-*") do set "JAVA_HOME=%%J"
call "%~dp0jadx\bin\jadx-gui.bat" %*
