## ExpressCluster: Hyper-V Host Clustering Solution on Windows Server 2022 Core Deployment Guide

## 1. Overview

This document provides a complete step-by-step implementation guide for:

- Windows Server 2025 Core Hyper-V deployment
- Remote Hyper-V management
- WinRM configuration
- PowerShell remoting
- Hyper-V Manager connectivity
- EXPRESSCLUSTER deployment
- Hyper-V VM High Availability using Mirror Disk

This guide is designed for lab, PoC and production reference environments.

---

## 2. Environment Details

| Component | Hostname | IP Address | Operating System |
|------------|------------|------------|------------|
| Hyper-V Host | HYPERV1 | 192.168.1.1 | Windows Server 2025 Core |
| Hyper-V Host | HYPERV2 | 192.168.1.2 | Windows Server 2025 Core |
| Guest VM | TestVM | 192.168.1.3 | Windows Server 2025 |
| Management Server | MGMT-SERVER | Management 192.168.1.5 | Windows Server 2025 |

---

## 3. Architecture

```text
                           +--------------------------------------------+
                           | Management Server (MGMT-SERVER)            |
                           | Windows Server 2025 (192.168.1.5)          |
                           | Hyper-V Manager / VMConnect / PowerShell   |
                           +--------------------------------------------+
                                                  |  WinRM (remote management)
                   +------------------------------+------------------------------+
                   v                                                             v
+------------------------------------+                        +------------------------------------+
| HYPERV1 (192.168.1.1)              |  <--- Heartbeat --->   | HYPERV2 (192.168.1.2)              |
| Primary Server                     |                        | Secondary Server                   |
| Windows Server 2025 Core           |                        | Windows Server 2025 Core           |
| Hyper-V                            |                        | Hyper-V                            |
| EXPRESSCLUSTER X                   |                        | EXPRESSCLUSTER X                   |
|                                    |        Failover        |                                    |
| Failover group: Online             |    --------------->    | Failover group: Offline            |
|                                    |                        |                                    |
| +- Mirror Disk Resource ---------+ |                        | +- Mirror Disk Resource ---------+ |
| | +- Data Partition (X:\) -----+ | |                        | | +- Data Partition (X:\) -----+ | |
| | |  +----------------------+  | | |Mirror Disk Replication | | |  +- - - - - - - - - - - +  | | |
| | |  | TestVM (192.168.1.3) |  | | |<=====================> | | |  : TestVM               :  | | |
| | |  | Running              |  | | |                        | | |  : Starts on failover   :  | | |
| | |  +----------------------+  | | |                        | | |  +- - - - - - - - - - - +  | | |
| | +----------------------------+ | |                        | | +----------------------------+ | |
| | +- Cluster Partition (Y:\) --+ | |                        | | +- Cluster Partition (Y:\) --+ | |
| | |                            | | |                        | | |                            | | |
| | +----------------------------+ | |                        | | +----------------------------+ | |
| +--------------------------------+ |                        | +--------------------------------+ |
+------------------------------------+                        +------------------------------------+
                   |                                                             |
===================+================== Network 192.168.1.0/24 ===================+==================
---
## 4. Prerequisites

## Hardware

### Hyper-V Hosts

- Minimum 2 CPUs
- Minimum 8 GB RAM
- Mirror Disks (As per the requirement with same byte level size)
- Cluster Disk (Minimum 1 GB)

### Management Server

- Windows Server 2025
- Hyper-V Manager
  
---

### Software

- Windows Server 2025 Core
- Hyper-V Role
- EXPRESSCLUSTER X
- Administrative Credentials

---

## 5. Configure Windows Server Core

Launch Server Configuration Tool:

```powershell
sconfig
```

Configure:

- Computer Name
- IP Address
- DNS Server
- Remote Management
- Windows Updates

Rename Hosts:

### HYPERV1

```powershell
Rename-Computer HYPERV1 -Restart
```

### HYPERV2

```powershell
Rename-Computer HYPERV2 -Restart
```

---

## 6. Install Hyper-V Role

Run on both nodes:

```powershell
Install-WindowsFeature Hyper-V -IncludeManagementTools -Restart
```

Verify:

```powershell
Get-WindowsFeature Hyper-V
```

Expected:

```text
[X] Hyper-V
```

---

## 7. Configure Storage

### Cluster Disk

```powershell
diskpart

list disk

select disk 1

online disk

attributes disk clear readonly

create partition primary

assign letter=Y:
```

---

### Mirror Disk

```powershell
select disk 2

online disk

attributes disk clear readonly

create partition primary

format fs=ntfs quick label=MirrorDisk

assign letter=X:
```

---

## 8. Create Hyper-V Virtual Switch

List Adapters:

```powershell
Get-NetAdapter
```

Create External Switch:

```powershell
New-VMSwitch `
-Name "ExternalSwitch" `
-NetAdapterName "Ethernet" `
-AllowManagementOS $true
```

Verify:

```powershell
Get-VMSwitch

Name           SwitchType NetAdapterInterfaceDescription
----           ---------- ------------------------------
ExternalSwitch External   Intel(R) 82574L Gigabit Network Connection
InternalSwitch Internal
```

## 9. Create Virtual Machine

Create the VM on the mirror disk (X:\) of HYPERV1 (Primary Server). This is the only VM creation procedure in this guide; no separate creation is required in Section 21.

**NOTE**: X:\ must be accessible on HYPERV1, i.e. the base cluster (Section 20) is created and the failover group (including the mirror disk resource) is active on HYPERV1.

Create Folder:

```powershell
New-Item -ItemType Directory `
-Path X:\VM\TestVM `
-Force
```

Create VM:

```powershell
New-VM -Name "TestVM" -MemoryStartupBytes 4GB -Generation 2 -Path "X:\VM" -NewVHDPath "X:\VM\TestVM\TestVM.vhdx" -NewVHDSizeBytes 40GB -SwitchName "ExternalSwitch"
```

Verify:

```powershell
Get-VM
```

---

## 10. Mount ISO

Create ISO Folder:

```powershell
New-Item `
-ItemType Directory `
-Path C:\ISO `
-Force
```

Copy ISO:

```text
C:\ISO\win2k25.iso
```

Verify:

```powershell
Get-Item C:\ISO\win2k25.iso
```

---

## 11. Attach ISO to VM

```powershell
Add-VMDvdDrive `
-VMName TestVM `
-Path C:\ISO\win2k25.iso
```

Verify:

```powershell
Get-VMDvdDrive -VMName TestVM
```

---

## 12. Configure Boot Order

```powershell
$dvd = Get-VMDvdDrive -VMName TestVM

Set-VMFirmware `
-VMName TestVM `
-FirstBootDevice $dvd
```

Verify:

```powershell
(Get-VMFirmware TestVM).BootOrder
```

---

## 13. Start VM

```powershell
Start-VM TestVM
```

Verify:

```powershell
Get-VM TestVM
```

Expected:

```text
Running
```

---

## 14. Configure WinRM

Run on Both Hyper-V Hosts:

```powershell
Enable-PSRemoting -Force
```

Verify:

```powershell
Get-Service WinRM
```

Expected:

```text
Running
```

---

## 15. Configure Trusted Hosts

Run on Management Server (e.g. 192.168.1.5):

```powershell
Set-Item `
WSMan:\localhost\Client\TrustedHosts `
-Value "192.168.1.1,HYPERV1,192.168.1.2,HYPERV2" `
-Force
```

Verify:

```powershell
Get-Item WSMan:\localhost\Client\TrustedHosts
```

---

## 16. Test Connectivity

### Ping Test

```powershell
ping 192.168.1.1

ping 192.168.1.2
```

---

### DNS Validation

```powershell
Resolve-DnsName HYPERV1

Resolve-DnsName HYPERV2
```

---

### WinRM Validation

```powershell
Test-WSMan HYPERV1

Test-WSMan HYPERV2

Test-WSMan 192.168.1.1

Test-WSMan 192.168.1.2
```

---

## 17. PowerShell Remoting

### HYPERV1

```powershell
$Password = Read-Host "Enter Password" -AsSecureString

$Cred = New-Object `
System.Management.Automation.PSCredential(
"192.168.1.1\Administrator",
$Password
)

Enter-PSSession `
-ComputerName 192.168.1.1 `
-Credential $Cred
```

Verify:

```powershell
hostname

Get-VM

Get-Service vmms
```

Exit:

```powershell
Exit-PSSession
```

---

## 18. Hyper-V Manager Connection

From Management Server:

1. Open Hyper-V Manager
2. Connect To Server
3. Select Another Computer
4. Enter:

```text
HYPERV1
```

Repeat for:

```text
HYPERV2
```

Verify all VMs are visible.

---

## 19. VM Connect

Open VM Console:

```powershell
vmconnect.exe HYPERV1 TestVM
```

or

```powershell
vmconnect.exe HYPERV2 TestVM
```

IP Based:

```powershell
vmconnect.exe 192.168.1.1 TestVM
```

---

## 20. EXPRESSCLUSTER Installation

### Install EXPRESSCLUSTER on Both Servers (HYPERV1 and HYPERV2)
Please refer to the [EXPRESSCLUSTER manual](https://www.nec.com/en/global/prod/expresscluster/en/doc/manuals/W60_IG_EN_03.pdf).

For installation on Server Core, please refer to [Installation on Server Core](https://docs.nec.co.jp/software/clustering/expresscluster_x/x60/ecx_x60_windows_en/W60_SG_EN/W_SG.html#installation-on-server-core) in the EXPRESSCLUSTER manual.

### Create a Base Cluster
- Create a failover group that includes a mirror disk resource.
- Apply the cluster configuration and start the cluster.

Ensure:

- Same version installed
- Same patch level
- Node communication successful

---

## 21. Register TestVM on HYPERV2 (Mirror Disk)

TestVM was created on the mirror disk of HYPERV1 (Primary Server) in Sections 9 to 13. Register it on HYPERV2 (Secondary Server) as follows.

1. Connect to HYPERV1 from the Management Server as described in Section 18 and confirm that TestVM is stored on the mirror disk (**X:\VM\TestVM**).
1. Open EC WebUI > move the failover group to HYPERV2 (Secondary Server).

### Launch **Hyper-V Manager** on the Management server (HYPERV2)
Connect to HYPERV2 as described in Section 18.
1. Right click Hyper-V host HYPERV2 > [Import Virtual Machine].
1. Specify **X:\VM\TestVM** as [Folder] > **Next**.
1. Select **Register the virtual machine in-place (use the existing unique ID)** > and click **Next**
1. **Finish**.

**Open EC WebUI**
  1. Stop the failover group.
  2. Change to [Config mode].

  **NOTE** : The following assumes the name of the VM as **TestVM**

## 22. **Add the Script Resource to Control the Virtual Machine**
 — add [Script resource] to the failover group >  

edit [start.bat]

Content:

```bat
rem **********
rem Parameter : the name of the VM to be controlled in the Hyper-V manager
set VMNAME=TestVM
rem **********
IF "%CLP_EVENT%" == "RECOVER" GOTO EXIT
powershell -Command "Start-VM -Name %VMNAME% -Confirm:$false"

:EXIT
```

---

## 23. Create Stop Script

edit [stop.bat]

```bat
rem **********
rem Parameter : the name of the VM to be controlled in the Hyper-V manager
set VMNAME=TestVM
rem **********
powershell -Command "Stop-VM -Name %VMNAME% -Force"
```

---

## 24. **Add the Custom Monitor Resource** 
— add in Monitor Resource > [Custom Monitor resource]

edit [genw.bat]

**NOTE** : `TestVM` is the VM name used in this guide. Replace it with your own VM name.

Content:

```bat
rem **********
rem Parameter : the name of the VM to be controlled in the Hyper-V manager
set VMNAME=TestVM
rem **********

powershell -Command "if ((Get-VMIntegrationService -VMName %VMNAME% -Name Heartbeat).PrimaryOperationalStatus -ne \"OK\") {exit 1}"
exit %ERRORLEVEL%
```
Apply the configuration in ECX WebUI.
---
## 25. Start Cluster

Start Cluster Service:

```text
Start Cluster
```

Confirm:

```text
Cluster Status : Running
```
### Restriction

VMs stored in the same MD resource need to move/failover together. It's good to control such VMs in the same failover group.

---

## 26. Failover Validation and Testing Scenarios

|No.| Test item                       | Confirmation |
|---|---                              |---           |
| 1 | start the failover group on HYPERV1 | HYPERV1 started TestVM |
| 2 | move the failover group to HYPERV2  | HYPERV1 stopped TestVM, then HYPERV2 started TestVM |
| 3 | power off HYPERV2                   | HYPERV1 noticed heartbeat timeout, then started TestVM |


## 27. Validation Checklist

- [ ] Hyper-V Installed
- [ ] External Switch Created
- [ ] VM Created
- [ ] ISO Attached
- [ ] WinRM Running
- [ ] Trusted Hosts Configured
- [ ] Hyper-V Manager Connected
- [ ] VMConnect Working
- [ ] EXPRESSCLUSTER Installed
- [ ] Mirror Disk Healthy
- [ ] Failover Group Created
- [ ] Start Script Working
- [ ] Stop Script Working
- [ ] Monitor Script Working
- [ ] VM Failover Successful

---

## 28. Troubleshooting

### WinRM Error

```text
The WinRM client cannot process the request.
```

Fix:

```powershell
Enable-PSRemoting -Force

winrm quickconfig
```

---

### Hyper-V Service

```powershell
Get-Service vmms
```

Start Service:

```powershell
Start-Service vmms
```

---

### Firewall

```powershell
Get-NetFirewallRule `
-DisplayGroup "Windows Remote Management"
```

---

### Cluster Communication

Verify:

```text
Node Status = Online

Mirror Status = Synchronized
```

---

## 29. Final Deployment Status

| Component | Status |
|------------|------------|
| HYPERV1 | Online |
| HYPERV2 | Online |
| Mirror Disk | Healthy |
| EXPRESSCLUSTER | Running |
| Hyper-V Manager | Connected |
| VMConnect | Working |
| TestVM | Protected |
| Automatic Failover | Enabled |

---

# Conclusion

The Hyper-V environment is now centrally managed and protected using EXPRESSCLUSTER high availability. Virtual machines can be remotely administered through Hyper-V Manager, PowerShell Remoting and VMConnect while maintaining operational continuity through automated failover between HYPERV1 and HYPERV2.
