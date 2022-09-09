#
# Import and Start Virtual Machine
#
$ErrorStart = 1
$ErrorRemove = 3
$ErrorImport = 5
$ErrorGetVHD = 6
$ErrorIcacls = 7

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
Import-VM -Path $env:VMCX2 -Confirm:$False
$bRet = $?
if ($bRet -eq $False)
{
        Write-Output "Import-VM failed."

        Write-Output "=== robocopy ==="
        Write-Output "SourcePaht: $env:DestPath"
        Write-Output "DestPaht  : $env:SourcePath"
        robocopy $env:DestPath $env:SourcePath /MIR
        $bRet = $LASTEXITCODE
        if ($bRet -ge 8)
        {
                Write-Output "robocopy failed (ret: $bRet)."
                exit $ErrorCopy
        }
        else
        {
                Write-Output "robocopy succeeded."     
        }

        while ($True) {
            # On WS2019, nothing happened just by copying the DestPath to the SourcePath,
            # and so, retrying importing operation.
            Write-Output "=== Import-VM ==="
            Write-Output "Retry import $env:VMCX2"
            Import-VM -Path $env:VMCX2 -Confirm:$False

            Write-Output "=== Get-VM ==="
            Get-VM -Name $env:VM
            if ($? -eq $True)
            {
                break
            }

            # Slow down output for scrpl*.log
            sleep 10
        }
        Write-Output "${env:VM} became available."

        Write-Output "=== Get-VHD ==="
        $vhdlist = Get-VHD -VMId $env:ID
        if ($vhdlist -eq $null)
        {
            Write-Output "Get-VHD failed. Please check the VMID in the configuration file or if there is virtual hard disks."
            exit $ErrorGetVHD
        }

        Write-Output "=== Grant the permission to VHDs ==="
        foreach ($vhd in $vhdlist)
        {
            $tmp = "NT VIRTUAL MACHINE\" + $env:ID
            icacls $vhd.Path /grant ${tmp}:`(r,w`)
            if ($? -eq $False)
            {
                Write-Output "icacls failed. Please check the VMID in the configuration file or if there is virtual hard disks."
                exit $ErrorIcacls
            }
        }
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