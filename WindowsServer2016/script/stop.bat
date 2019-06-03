rem ***************************************
rem * stop.bat (script-mysql)             *
rem ***************************************

cd "%CLP_SCRIPT_PATH%"
call SetEnvironment.bat
PowerShell -File .\stop.ps1
set ret=%ERRORLEVEL%
echo %0 ret: %ret%
exit %ret%
