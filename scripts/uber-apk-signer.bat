@echo off
rem uber-apk-signer.bat - runs uber-apk-signer-1.3.0.jar without caring about PATH.
rem Finds Java itself: prefers Temurin jdk-* on disk (survives JDK updates
rem and stale terminals), falls back to "java" on PATH.
set "JAVA_EXE=java.exe"
for /d %%J in ("%ProgramFiles%\Eclipse Adoptium\jdk-*") do set "JAVA_EXE=%%J\bin\java.exe"
"%JAVA_EXE%" -jar "%~dp0uber-apk-signer-1.3.0.jar" %*
