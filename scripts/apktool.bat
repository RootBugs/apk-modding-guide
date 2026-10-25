@echo off
rem apktool.bat - runs apktool_3.0.3.jar without caring about PATH.
rem Finds Java itself: prefers Temurin jdk-* on disk (survives JDK updates
rem and stale terminals), falls back to "java" on PATH.
set "JAVA_EXE=java.exe"
for /d %%J in ("%ProgramFiles%\Eclipse Adoptium\jdk-*") do set "JAVA_EXE=%%J\bin\java.exe"
"%JAVA_EXE%" -jar "%~dp0apktool_3.0.3.jar" %*
