# Windows Server 2025 Hyper-V Remote Management and EXPRESSCLUSTER High Availability Deployment Guide

# 1. Overview

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

# 2. Environment Details

| Component | Hostname | IP Address | Operating System |
|------------|------------|------------|------------|
| Hyper-V Host | HYPERV1 | 192.168.1.1 | Windows Server 2025 Core |
| Hyper-V Host | HYPERV2 | 192.168.1.2 | Windows Server 2025 Core |
| Guest VM | TestVM | 192.168.1.3 | Windows Server 2025 |
| Management Server | MGMT-SERVER | Management 192.168.1.5 | Windows Server 2025 |

---

# 3. Architecture

```text
                                 Management Server
                          Windows Server 2025 (192.168.1.5)
                                  Hyper-V Manager
                                     |
                                     |
                       Hyper-V Manager / VMConnect
                                     |
                    +----------------+----------------+
                    |                                 |
                    |                                 |
                    v                                 v

          HYPERV1 (192.168.1.1)          HYPERV2 (192.168.1.2)
        Windows Server 2025 Core       Windows Server 2025 Core
                Hyper-V                       Hyper-V
           EXPRESSCLUSTER X                EXPRESSCLUSTER X
        - Mirror Disk Resource             - Mirror Disk Resource   
          - Data Partition (X:\)            - Data Partition (X:\)                   
          - Cluster Partition (Y:\)         - Cluster Partition (Y:\)

                     <==== Mirror Disk Replication ====>

                    TestVM (192.168.1.3_hyper-V host VM)
                               Windows Server 2025
```
---

# 4. Prerequisites

## Hardware

### Hyper-V Hosts

- Minimum 2 CPUs
- Minimum 8 GB RAM
- Additional storage for VM workloads
- Two network adapters recommended

### Management Server

- Windows Server 2025
- Hyper-V Manager
- VMConnect

---

## Software

- Windows Server 2025 Core
- Hyper-V Role
- EXPRESSCLUSTER X
- Administrative Credentials

---

# 5. Configure Windows Server Core

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

# 6. Install Hyper-V Role

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

# 7. Configure Storage

## Cluster Disk

```powershell
diskpart

list disk

select disk 1

online disk

attributes disk clear readonly

create partition primary

assign letter=F:
```

---

## Mirror Disk

```powershell
select disk 2

online disk

attributes disk clear readonly

create partition primary

format fs=ntfs quick label=MirrorDisk

assign letter=E:
```

---

# 8. Create Hyper-V Virtual Switch

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

# 9. Create Virtual Machine

Create Folder:

```powershell
New-Item -ItemType Directory `
-Path E:\VM\TestVM `
-Force
```

Create VM:

```powershell
New-VM -Name "TestVM" -MemoryStartupBytes 4GB -Generation 2 -NewVHDPath "E:\VM\TestVM\TestVM.vhdx" -NewVHDSizeBytes 40GB -SwitchName "ExternalSwitch"
```

Verify:

```powershell
Get-VM
```

---

# 10. Mount ISO

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

# 11. Attach ISO to VM

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

# 12. Configure Boot Order

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

# 13. Start VM

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

# 14. Configure WinRM

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

# 15. Configure Trusted Hosts

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

# 16. Test Connectivity

## Ping Test

```powershell
ping 192.168.1.1

ping 192.168.1.2
```

---

## DNS Validation

```powershell
Resolve-DnsName HYPERV1

Resolve-DnsName HYPERV2
```

---

## WinRM Validation

```powershell
Test-WSMan HYPERV1

Test-WSMan HYPERV2

Test-WSMan 192.168.1.1

Test-WSMan 192.168.1.2
```

---

# 17. PowerShell Remoting

## HYPERV1

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

# 18. Hyper-V Manager Connection

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

# 19. VMConnect

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

# 20. EXPRESSCLUSTER Installation

### Install EXPRESSCLUSTER on Both Servers (Primary and Secondary)
Please refer to the [EXPRESSCLUSTER manual](https://www.nec.com/en/global/prod/expresscluster/en/doc/manuals/W60_IG_EN_03.pdf).

### Create a Base Cluster
- Create a failover group that includes a mirror disk resource.
- Apply the cluster configuration and start the cluster.

Ensure:

- Same version installed
- Same patch level
- Node communication successful

---

# 21. Create a Virtual Machine on the Mirror Disk of Server1 (Primary Server) using the Management Server through Hyper-V Manager (Point No. 18).

1. Launch **Hyper-V Manager** on the Management server.
Open **Hyper-V Manager** > **Connect To Server** >
**Select Another Computer** > Enter **hyperv1** server > OK.

1. Click **New** and click **Virtual Machine** on right pane.
1. Click **Specify Name and Location** on left pane.
1. Enter the virtual machine name. Check **Store the virtual machine in a different location** and specify a directory on the mirror disk *(e.g. X:\VM)*. Click **Next**.
1. Choose the generation of the virtual machine and click **Next**.
1. Specify the amount of memory and click **Next**.
1. Select the virtual switch and click **Next**.
1. Select [Create a virtual hard disk]> specify **X:\VM** as [Location] > specify [Name] and [Size] on requisite > **Next**.
1. Specify Installation Options on requisite. click **Next**.
1. Check the parameters and click **Finish**.
1. Choose installation method and click **Next**.
1. Check the parameters and click **Finish**.
1. Open EC WebUI > move the failover group to Server2 (Secondary Server).

### On Server2 (Secondary Server)
1. Launch **Hyper-V Manager** on the Secondary server.
1. Right click Hyper-V host Server2 > [Import Virtual Machine].
1. Specify **X:\VM\Testvm** as [Folder] > **Next**.
1. Select **Register the virtual machine in-place (use the existing unique ID)** > and click **Next**
1. **Finish**.

**Open EC WebUI**
  1. Stop the failover group.
  2. Change to [Config mode].

  **NOTE** : The following assumes the name of the VM as *TestVm*

# 25. **Add the Script Resource to Control the Virtual Machine**
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

# 26. Create Stop Script

edit [stop.bat]

```bat
rem **********
rem Parameter : the name of the VM to be controlled in the Hyper-V manager
set VMNAME=TestVM
rem **********
powershell -Command "Stop-VM -Name %VMNAME% -Force"
```

---

# 27. **Add the Custom Monitor Resource** — add [Custom Monitor resource]

edit [genw.bat]



Content:

```bat
rem **********
rem Parameter : the name of the VM to be controlled in the Hyper-V manager
set VMNAME=vm1
rem **********

powershell -Command "if ((Get-VMIntegrationService -VMName %VMNAME% -Name Heartbeat).PrimaryOperationalStatus -ne \"OK\") {exit 1}"
exit %ERRORLEVEL%
```
Apply the configuration in ECX WebUI.
---
# 29. Start Cluster

Start Cluster Service:

```text
Start Cluster
```

Confirm:

```text
Cluster Status : Running
```
## Restriction

VMs stored in the same MD resource need to move/failover together. It's good to control such VMs in the same failover group.

---

# 30. Failover Validation and Testing Scenarios

|No.| Test item                       | Confirmation |
|---|---                              |---           |
| 1 | start the failover group on Server1 | Server1 started VM1 |
| 2 | move the failover group to Server2  | Server1 stopped VM1, then Server2 started VM1 |
| 3 | power off Server2                   | Server1 noticed heartbeat timeout, then started VM1 |


# 31. Validation Checklist

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

# 32. Troubleshooting

## WinRM Error

```text
The WinRM client cannot process the request.
```

Fix:

```powershell
Enable-PSRemoting -Force

winrm quickconfig
```

---

## Hyper-V Service

```powershell
Get-Service vmms
```

Start Service:

```powershell
Start-Service vmms
```

---

## Firewall

```powershell
Get-NetFirewallRule `
-DisplayGroup "Windows Remote Management"
```

---

## Cluster Communication

Verify:

```text
Node Status = Online

Mirror Status = Synchronized
```

---

# 33. Final Deployment Status

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