rem ***************************************
rem *               genw.bat              *
rem ***************************************
echo START
cd "C:\Program Files\EXPRESSCLUSTER\scripts\failover-vm\script-vm"
rem cd "C:\Program Files\EXPRESSCLUSTER\scripts\failover1\script-vm"
call SetEnvironment.bat
PowerShell -File .\vmstate.ps1
set ret=%ERRORLEVEL%
exit %ret%
