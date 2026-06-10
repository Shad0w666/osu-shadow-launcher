@echo off
setlocal enabledelayedexpansion
title Osu! Shadow Launcher Installer
color 0C

echo ========================================
echo     Osu! Shadow Launcher Setup
echo ========================================
echo.
echo Please select the launcher language:
echo [1] English
echo [2] Czech
echo.
set /p langChoice="> "

if "!langChoice!"=="1" (
    set "SCRIPT_NAME=launcher_EN.ps1"
    echo [~] Selected English.
    set "MSG_BUILD=[~] Building OsuShadowLauncher.exe..."
    set "MSG_SUCCESS=[+] Success!"
    set "MSG_CREATED=[+] OsuShadowLauncher.exe has been created successfully."
    set "MSG_DELETE=[+] Setup.bat can now be safely deleted."
    set "MSG_OVERWRITE_PROMPT=[?] OsuShadowLauncher.exe already exists. Overwrite? (Y/N): "
    set "MSG_ABORTED=[~] Build aborted."
    set "MSG_ICON_PROMPT=Please select an icon for the launcher:"
    set "MSG_ICON_DEFAULT=[!] Invalid choice. Defaulting to the first icon."
    set "MSG_NO_ICONS=[!] No .ico files found in resources\icons\. Building without icon."
    set "MSG_ICON_SELECTED=[~] Selected icon:"
) else if "!langChoice!"=="2" (
    set "SCRIPT_NAME=launcher_CS.ps1"
    echo [~] Vybrana Cestina.
    set "MSG_BUILD=[~] Vytvarim OsuShadowLauncher.exe..."
    set "MSG_SUCCESS=[+] Hotovo!"
    set "MSG_CREATED=[+] OsuShadowLauncher.exe byl uspesne vytvoren."
    set "MSG_DELETE=[+] Setup.bat lze nyni bezpecne smazat."
    set "MSG_OVERWRITE_PROMPT=[?] OsuShadowLauncher.exe jiz existuje. Prepsat? (A/N): "
    set "MSG_ABORTED=[~] Vytvareni zruseno."
    set "MSG_ICON_PROMPT=Vyber ikonu pro spoustec:"
    set "MSG_ICON_DEFAULT=[!] Neplatna volba. Pouzivam prvni dostupnou ikonu."
    set "MSG_NO_ICONS=[!] Ve slozce resources\icons\ nebyly nalezene zadne .ico soubory. Kompiluji bez ikony."
    set "MSG_ICON_SELECTED=[~] Vybrana ikona:"
) else (
    echo [!] Invalid choice. Defaulting to English.
    set "SCRIPT_NAME=launcher_EN.ps1"
    set "MSG_BUILD=[~] Building OsuShadowLauncher.exe..."
    set "MSG_SUCCESS=[+] Success!"
    set "MSG_CREATED=[+] OsuShadowLauncher.exe has been created successfully."
    set "MSG_DELETE=[+] Setup.bat can now be safely deleted."
    set "MSG_OVERWRITE_PROMPT=[?] OsuShadowLauncher.exe already exists. Overwrite? (Y/N): "
    set "MSG_ABORTED=[~] Build aborted."
    set "MSG_ICON_PROMPT=Please select an icon for the launcher:"
    set "MSG_ICON_DEFAULT=[!] Invalid choice. Defaulting to the first icon."
    set "MSG_NO_ICONS=[!] No .ico files found in resources\icons\. Building without icon."
    set "MSG_ICON_SELECTED=[~] Selected icon:"
)

echo.
echo !MSG_ICON_PROMPT!
set /a idx=0
for %%I in ("resources\icons\*.ico") do (
    set /a idx+=1
    set "icon_!idx!=%%~nxI"
    echo [!idx!] %%~nxI
)

if !idx!==0 (
    echo !MSG_NO_ICONS!
    set "ICON_COMPILER_FLAG="
) else (
    echo.
    set /p iconChoice="> "
    
    set "SELECTED_ICON="
    for /L %%i in (1,1,!idx!) do (
        if "!iconChoice!"=="%%i" set "SELECTED_ICON=!icon_%%i!"
    )
    
    if "!SELECTED_ICON!"=="" (
        echo !MSG_ICON_DEFAULT!
        set "SELECTED_ICON=!icon_1!"
    ) else (
        echo !MSG_ICON_SELECTED! !SELECTED_ICON!
    )
    
    set ICON_COMPILER_FLAG=/win32icon:"resources\icons\!SELECTED_ICON!"
)
if exist "OsuShadowLauncher.exe" (
    echo.
    set /p overwriteChoice="!MSG_OVERWRITE_PROMPT!"
)

if exist "OsuShadowLauncher.exe" (
    if /i "!overwriteChoice!"=="N" goto :abort
    if /i "!overwriteChoice!"=="NO" goto :abort
    if /i "!overwriteChoice!"=="NE" goto :abort
)
goto :doBuild

:abort
echo.
echo !MSG_ABORTED!
echo.
pause
exit /b

:doBuild
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$path='resources\local\scripts\!SCRIPT_NAME!'; $text=[System.IO.File]::ReadAllText($path); [System.IO.File]::WriteAllText($path, $text, [System.Text.Encoding]::UTF8)"
echo !MSG_BUILD!

echo using System.Diagnostics; > wrapper.cs
echo using System.IO; >> wrapper.cs
echo using System; >> wrapper.cs
echo class Program { >> wrapper.cs
echo     static void Main() { >> wrapper.cs
echo         string ps1Path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "resources", "local", "scripts", "!SCRIPT_NAME!"); >> wrapper.cs
echo         ProcessStartInfo psi = new ProcessStartInfo(); >> wrapper.cs
echo         psi.FileName = "powershell.exe"; >> wrapper.cs
echo         psi.Arguments = string.Format("-NoLogo -NoProfile -ExecutionPolicy Bypass -File \"{0}\"", ps1Path); >> wrapper.cs
echo         psi.UseShellExecute = false; >> wrapper.cs
echo         Process.Start(psi); >> wrapper.cs
echo     } >> wrapper.cs
echo } >> wrapper.cs

set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

"%CSC%" /nologo /target:winexe !ICON_COMPILER_FLAG! /out:"OsuShadowLauncher.exe" wrapper.cs

del wrapper.cs

echo.
echo !MSG_SUCCESS!
echo !MSG_CREATED!
echo !MSG_DELETE!
echo.
pause