@echo off
setlocal EnableExtensions

title Free space check for %~d0
set "SCRIPT_DIR=%~dp0"
set "DRIVE=%~d0"
set "DRIVE_LETTER=%DRIVE:~0,1%"
set "REQUIRED_BYTES=5368709120"
set "REQUIRED_GB=5"

echo Checking free space for: %SCRIPT_DIR%
echo.
call :find_space

if not defined FREE_BYTES (
	echo Could not determine free space for the drive that contains this script.
	exit /b 1
)

if %FREE_BYTES% GEQ %REQUIRED_BYTES% (
	goto success
)

echo Not enough free space. This folder's drive needs at least %REQUIRED_GB% GB free.
echo Free space: %FREE_GB% GB
echo.
echo This cleanup only removes temporary files and the recycle bin on %DRIVE%.
choice /c YN /n /m "Run cleanup now? [Y/N] "
if errorlevel 2 (
	cls
	echo Exiting. Please make sure %DRIVE% has at least %REQUIRED_GB% GB free.
	timeout /t 3 >nul
	exit /b 1
)

goto del

:del
echo.
echo Cleaning temporary files on %DRIVE%...
call :cleanup_path "%TEMP%" "User temp"
call :check_space
if not errorlevel 1 goto success

call :cleanup_path "%LOCALAPPDATA%\Temp" "Local AppData temp"
call :check_space
if not errorlevel 1 goto success

call :cleanup_path "%SystemRoot%\Temp" "Windows temp"
call :check_space
if not errorlevel 1 goto success

call :clear_recycle_bin
call :check_space
if not errorlevel 1 goto success

echo.
echo Cleanup finished, but %DRIVE% is still below %REQUIRED_GB% GB free.
echo Free space: %FREE_GB% GB
exit /b 1

:cleanup_path
set "TARGET_PATH=%~1"
set "TARGET_NAME=%~2"

if not defined TARGET_PATH exit /b 0
if /I not "%~d1"=="%DRIVE%" exit /b 0
if not exist "%TARGET_PATH%" exit /b 0

echo Cleaning %TARGET_NAME%: %TARGET_PATH%
del /f /s /q "%TARGET_PATH%\*" >nul 2>&1
for /d %%D in ("%TARGET_PATH%\*") do rd /s /q "%%~fD" >nul 2>&1
exit /b 0

:clear_recycle_bin
echo Clearing recycle bin on %DRIVE%...
powershell -NoProfile -Command "Clear-RecycleBin -DriveLetter '%DRIVE_LETTER%' -Force -ErrorAction SilentlyContinue" >nul 2>&1
exit /b 0

:check_space
call :find_space
if not defined FREE_BYTES exit /b 1
if %FREE_BYTES% GEQ %REQUIRED_BYTES% exit /b 0
exit /b 1


:find_space
for /f "tokens=1,2 delims=|" %%A in ('powershell -NoProfile -Command "$freeBytes = (Get-PSDrive -Name ''%DRIVE_LETTER%'').Free; $freeGb = [math]::Round($freeBytes / 1GB, 2); Write-Output ($freeBytes.ToString() + ''|'' + $freeGb.ToString())"') do (
	set "FREE_BYTES=%%A"
	set "FREE_GB=%%B"
)
exit /b

:success
echo done!
timeout 3 >nul
cls
