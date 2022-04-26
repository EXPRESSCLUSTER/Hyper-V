#
# Import and Start Virtual Machine
#
$ErrorStart = 1
$ErrorRemove = 3

Write-Output "=== Get-VM ===" 
Get-VM -Name $env:VM
$bRet = $?
if ($bRet -eq $True)
{
        Write-Output "There is VM before start it." 
        Write-Output "=== Remove-VM ===" 
        Remove-VM -Name $env:VM -Force
        $bRet = $?
        if ($bRet -eq $False)
        {
                Write-Output "Remove-VM failed."
        }
        else
        {
                Write-Output "Remove-VM succeeded."        
        }
}
else
{
        Write-Output "There is NO VM before start it." 
}

Write-Output "=== Test-Path ==="
$bRet = Test-Path -Path $env:VMCX1
if ($bRet -eq $True)
{
        Write-Output "Remove $env:VMCX1"
        Remove-Item $env:VMCX1
}
else
{
        Write-Output "$env:VMCX1 does not exit"
}
$bRet = Test-Path -Path $env:VMRS1
if ($bRet -eq $True)
{
        Write-Output "Remove $env:VMRS1"
        Remove-Item $env:VMRS1
}
else
{
        Write-Output "$env:VMRS1 does not exit"
}

Write-Output "=== Import-VM ==="
Write-Output "Import $env:VMCX2"
Import-VM -Path $env:VMCX2 -Confirm:$False -Copy -VirtualMachinePath $env:RestorePath -VhdDestinationPath $env:VhdPath
$bRet = $?
if ($bRet -eq $False)
{
        Write-Output "Import-VM failed."
}
else
{
        Write-Output "Import-VM succeeded."
}

Write-Output "=== Start-VM ==="
Start-VM -Name $env:VM -Confirm:$False
$bRet = $?
if ($bRet -eq $False)
{
        Write-Output "Start-VM failed."
        exit $ErrorStart
}
else
{
        Write-Output "Start-VM succeeded."
        Get-VM -Name $env:VM
}

exit 0
