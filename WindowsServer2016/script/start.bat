rem ***************************************
rem * start.bat                           *
rem ***************************************

rem ***************************************
rem Check startup attributes
rem ***************************************
IF "%CLP_EVENT%" == "RECOVER" GOTO RECOVER

cd "%CLP_SCRIPT_PATH%"
call SetEnvironment.bat
PowerShell -File .\start.ps1
set ret=%ERRORLEVEL%
exit %ret%

rem ***************************************
rem Recovery process
rem ***************************************
:RECOVER

rem *************
rem Recovery process after return to the cluster
rem *************


exit 0
