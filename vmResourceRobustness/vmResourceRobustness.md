# How to improve robustness of Hyper-V Host cluster vm resource
## Overview
If vm resource failover occurs for Host server unecpected shutdown, sometimes the vm resource failed to start on failover target server.
In such a case, it may be resolved by this solution.

## Symptoms
A vm resource is activated on a Hyper-V host server which is clustered by EXPRESSCLUSTER.
The server gets down unexpectedly and the vm resource failover occurs.
However the vm resource failed to start on the failover target Hyper-V host server.

- EXRESSCLUSTER logs show as the followings
	- userlog.log  
	```bat
	INFO  [rc   ] Starting vm resource
	ERROR [rc   ] Failed to start vm resourcce (99 : Internal Error)
	```
	- vm.log  
	```bat  
	INFO [P:00000b4c][T:000016d0]vmcommon.c:1693   WaitForJobCompleted       -In progress... 0% completed.
	INFO [P:00000b4c][T:000016d0]vmcommon.c:1693   WaitForJobCompleted       -In progress... 0% completed.
	ERROR[P:00000b4c][T:000016d0]vmcommon.c:1725   WaitForJobCompleted       -Job failed.(解決できない構成ファイルのエラーのため、'<Virtual Machine name>' は認識できませんでした。(Virtual Machine ID C520D71E-AE84-40D6-A2B5-B1F697821703))(ErrorCode:32768)
	ERROR[P:00000b4c][T:000016d0]vmcommon.c:3554   RealizePlannedSystem      -WaitForJobCompleted failed.
	INFO [P:00000b4c][T:000016d0]vmcommon.c:2151   GetPathVal                -vtPathVal:\\CLG-16NET-209\root\virtualization\v2:Msvm_VirtualSystemManagementService.CreationClassName="Msvm_VirtualSystemManagementService",Name="vmms",SystemCreationClassName="Msvm_ComputerSystem",SystemName="CLG-16NET-209"
	INFO [P:00000b4c][T:000016d0]vmcommon.c:2151   GetPathVal                -vtPathVal:\\CLG-16NET-209\root\virtualization\v2:Msvm_PlannedComputerSystem.CreationClassName="Msvm_PlannedComputerSystem",Name="C520D71E-AE84-40D6-A2B5-B1F697821703"
	INFO [P:00000b4c][T:000016d0]vmcommon.c:1693   WaitForJobCompleted       -In progress... 100% completed.
	INFO [P:00000b4c][T:000016d0]vmcommon.c:3709   DestroyPlanSystem         -DestroyPlanSystem success.
	ERROR[P:00000b4c][T:000016d0]vmcommon.c:3560   RealizePlannedSystem      -DestroyPlanSystem success.
	ERROR[P:00000b4c][T:000016d0]    vm.cpp:319    ActivateRsc               -activate vm failed!(99)
	ERROR[P:00000b4c][T:000016d0]    vm.cpp:320    ActivateRsc               -msg:Internal Error
	```
- Compare-VM command shows Error ID 40004  
	```bat
	PS C:\Users\administrator.> Compare-VM -Path M:\Hyper-V\W2012R2-gene2-16net-214\Virtual Machines\C520D71E-AE84-40D6-A2B5-B1F697821703.XML

	VM                 : Microsoft.HyperV.PowerShell.VirtualMachine
	OperationType      : ImportVirtualMachine
	Destination        : CLG-16NET-208
	Path               : M:\Hyper-V\W2012R2-gene2-16net-214\Virtual Machines\C520D71E-AE84-40D6-A2B5-B1F697821703.XML
	SnapshotPath       : M:\Hyper-V\W2012R2-gene2-16net-214\Snapshots
	VhdDestinationPath : M:\Hyper-V\W2012R2-gene2-16net-214\Virtual Hard Disks
	VhdSourcePath      : M:\Hyper-V\W2012R2-gene2-16net-214\Virtual Hard Disks
	Incompatibilities  : {40004, 40006}
	```  
		* 40004: Could not find state file.  
		* 40006: Could not find memory file.

## Cause
For unexpected host server shutdown, saves state file or virtual memory file are removed.
However, their info is not removed and remains in VM configuration file as the following.
```bat
  <savedstate>
    <in_progress type="bool">False</in_progress>
    <memlocation type="string">M:\Hyper-V\W2012R2-gene2-16net-214\Virtual Machines\C520D71E-AE84-40D6-A2B5-B1F697821703\C520D71E-AE84-40D6-A2B5-B1F697821703.bin</memlocation>
    <type type="string">Normal</type>
    <vsvlocation type="string">M:\Hyper-V\W2012R2-gene2-16net-214\Virtual Machines\C520D71E-AE84-40D6-A2B5-B1F697821703\C520D71E-AE84-40D6-A2B5-B1F697821703.vsv</vsvlocation>
  </savedstate>
```
For this mismatch, the error occurs.

## Resolution
To resolve it, you need to import the vm with Hyper-V Manager (GUI) or remove saved state info as the following.
```bat
PS C:\Users\administrator.JDPX> $report = Compare-VM -Path $path
PS C:\Users\administrator.JDPX> $report.Incompatibilities[0].Source | Remove-VMSavedState
PS C:\Users\administrator.JDPX> Import-VM -CompatibilityReport $report

Name                    State CPUUsage(%) MemoryAssigned(M) Uptime   Status
----                    ----- ----------- ----------------- ------   ------
W2012R2-gene2-16net-214 Off   0           0                 00:00:00 Running
```

## Solution
By applying this solution for your cluster, the resolution is executed automatically.

1. Add resource.
	- Type: script resource
	- FailoverThreshold -> Set Number: 0
	- Final Action: No operation (activate next resource)
1. Apply the configuration.
1. Store [Remove-VMSavedState.ps1](https://github.com/EXPRESSCLUSTER/Hyper-V/blob/master/vmResourceRobustness/scripts/Remove_VMSavesState.ps1) under scripts folder:  
   "C:\Program Files\EXPRESSCLUSTER\scripts\\\<failover-group name>\\\<script resource name>\Remove-VMSavedState.ps1"
1. Edit the script resource which is added in step 1.
	- Details tab -> Add button -> Browse button -> Select  
	  "C:\Program Files\EXPRESSCLUSTER\scripts\\\<failover-group name\>\\\<script resource name>\Remove-VMSavedState.ps1"
	- Details tab -> Select start.bat -> Edit button -> Edit the bat file to call:
	  ```bat
	  rem ***************************************
	  rem *              start.bat              *
	  rem ***************************************
	  
	  cd %CLP_SCRIPT_PATH%
	  PowerShell .\Remove-VMSavedState.ps1
	  exit 0
	  ```
1. Edit existing vm resource:
	- Dependency tab -> Uncheck "Follow the default dependency"
	- Dependency tab -> Select script resource which is added in step1 -> Add button
1. Apply the configuration.
