#
# Stop and Remove Virtual Machine
#
$ErrorStop   = 2
$ErrorRemove = 3
$ErrorCopy   = 4

Write-Output "=== Stop-VM ==="
Stop-VM -Name $env:VM -Force
$bRet = $?
if ($bRet -eq $False)
{
        Write-Output "Stop-VM failed."
        exit $ErrorStop
}
else
{
        Write-Output "Stop-VM succeeded."
}

Write-Output "=== Test-Path ==="
$bRet = Test-Path $env:DestPath
if ($bRet -eq $False)
{
        New-Item -Path $env:DestPath -ItemType Directory
        $bRet = $?
        if ($bRet -eq $False)
        {
                Write-Output "New-Item failed but ignore."
        }
}

Write-Output "=== robocopy ==="
Write-Output "SourcePaht: $env:SourcePath"
Write-Output "DestPaht  : $env:DestPath"
robocopy $env:SourcePath $env:DestPath /MIR
$ret = $LASTEXITCODE
if ($ret -ge 8)
{
        Write-Output "robocopy failed (ret: $ret)."
        exit $ErrorCopy
}
else
{
        Write-Output "robocopy succeeded."        
}

Write-Output "=== Remove-VM ===" 
Remove-VM -Name $env:VM -Force
$bRet = $?
if ($bRet -eq $False)
{
        Write-Output "Remove-VM failed."
        exit $ErrorRemove
}
else
{
        Write-Output "Remove-VM succeeded."        
}

exit 0