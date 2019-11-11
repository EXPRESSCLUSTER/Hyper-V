Write-Output "----- Start VM import check -----"
$time = Get-Date -Format "yyyy/MM/dd HH:mm:ss" | Out-String
Write-Output "Time: "$time

# Get VM configuration (.xml) path from clp.conf.
# If you install EXPRESSCLUSTER in a folder which is NOT default, please edit $path.
$confPath = "C:\Program Files\CLUSTERPRO\etc\clp.conf"
$confXml = [xml](Get-Content $confPath)
$path = $confXml.root.resource.vm.parameters.vmconfigpath
$confXml.Save($confPath)
$pathlist = $path.Split("\\")
$vmname = $pathlist[$pathlist.Length-3]

Write-Output "VM Config path: "$path
Write-Output "VM Name:        "$vmname

# Check VM already exists.
#  -> Yes: exit 0
#     No:  Go to next step
Write-Output "Execute Get-VM."
Get-VM -Name $vmname | Out-Null
if($? -eq $true){
  Write-Output "Get-VM: Success"
  $time = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
  Write-Output "Time: "$time
  Write-Output "exit 0"
  Write-Output "----- Finish VM import check -----"
  clplogcmd -m "VM already exists." --alert -l INFO
  exit 0
}
Write-Output "Get-VM: Failure!"
Write-Output $error[0]

# Try Import-VM to check target VM can be importted.
#  ->Yes: exit 0
#    No:  Go to next
Write-Output "Execute Import-VM"
Import-VM -Path $path | Out-Null
if($? -eq $true){
  Write-Output "Import-VM: Success"
  $time = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
  Write-Output "Time: "$time
  Write-Output "exit 0"
  Write-Output "----- Finish VM import check -----"
  clplogcmd -m "Import target VM is succeeded." --alert -l INFO
  exit 0
}
Write-Output "Import-VM: Failure!"
Write-Output $error[0]
clplogcmd -m "Import target VM is failed. Try Compare-VM and Remove-VMSavedState." --alert -l WARN

# Execute Compare-VM to check the cause of import failure.
# If Execute-VM command fails, exit 1.
Write-Output "Execute Compare-VM"
$report = Compare-VM -Path $path
if($? -eq $failse){
  Write-Output "Compare-VM: Failure!"
  Write-Output $error[0]
  $time = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
  Write-Output "Time: "$time
  Write-Output "exit 1"
  Write-Output "----- Finish VM import check -----"
  clplogcmd -m "Compare target VM is failed." --alert -l ERR
  exit 1
}
Write-Output $report

# Check the import failure cause (Incompatibiity MessageID) is 40004.
#  -> Yes: Go to next step
#     No: exit 1
$i = 0
for($i=0; $i -lt $report.Incompatibilities.MessageId.Length; $i++){
  if($report.Incompatibilities.MessageId[$i] -eq 40004){
    break
  }
}
if($i -eq $report.Incompatibilities.MessageId.Length){
  Write-Output "Compare-VM: Incompatibilities MessageId does not include 40004!"
  Write-Output "Compare-VM: Please check what error occurs and resolve it."
  $time = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
  Write-Output "Time: "$time
  Write-Output "exit 1"
  Write-Output "----- Finish VM import check -----"
  clplogcmd -m "Incompatibilities MessageId does not include 40004." --alert -l ERR
  clplogcmd -m "Please check what error occurs and resolve it." --alert -l WARN
  exit 1
}  
Write-Output "Compare-VM: Incompatibilities MessageId includes 40004."

# Try Remove-VMSavedState.
# If Remove-VMSavedState command fails, exit 1.
Write-Output "Execute Remove-VMSavedState."
$report.Incompatibilities[$i].Source | Remove-VMSavedState
if($? -eq $false){
  Write-Output "Remove-VMSavedState: Failure!"
  Write-Output $error[0]
  Write-Output "exit 1"
  Write-Output "----- Finish VM import check -----"
  clplogcmd -m "Remove-VMSavedState is failed." --alert -l ERR
  exit 1
}
Write-Output "Remove-VMSavedState: Success!"

# Try import-VM again to check the cause is resolved by Remove-VMSavedState
#  -> Yes: Go to next step
#     No:  exit 1
Write-Output "Execute Import-VM again."
Import-VM -CompatibilityReport $report | Out-Null
if($? -eq $false){
  Write-Output "Import-VM again: Failure!"
  Write-Output $error[0]
  $time = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
  Write-Output "Time: "$time
  Write-Output "exit 1"
  Write-Output "----- Finish VM import check -----"
  clplogcmd -m "Import target VM after Remove-VMSavedState is dailed." --alert -l ERR
  exit 1
}
Write-Output "Import-VM again: Success"

# Check target VM is actually imported.
# -> Yes: exit 0
#    No:  exit 1
Write-Output "Execute Get-VM."
Get-VM -Name $vmname | Out-Null
if($? -eq $false){
  Write-Output "Get-VM: Failure!"
  Write-Output $error[0]
  $time = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
  Write-Output "Time: "$time
  Write-Output "exit 1"
  Write-Output "----- Finish VM import check -----"
  exit 1
}
Write-Output "Get-VM: Success"
$time = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
Write-Output "Time: "$time
Write-Output "exit 0"
Write-Output "----- Finish VM import check -----"
clplogcmd -m "Import target VM after Remove-VMSavedState is succeeded." --alert -l INFO
exit 0
