@echo off
rem jadx.bat - delegates to jadx's own launcher.
rem Sets JAVA_HOME from the Temurin jdk-* folder if present (JDK-upgrade
rem proof); if none found, jadx's script uses "java" from PATH.
set "JAVA_HOME="
for /d %%J in ("%ProgramFiles%\Eclipse Adoptium\jdk-*") do set "JAVA_HOME=%%J"
call "%~dp0jadx\bin\jadx.bat" %*
