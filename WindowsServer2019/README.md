# Hyper-V host clustering by EXPRESSCLUSTER

This document describes a step-by-step procedure for setting up a HA cluster of Hyper-V hosts.  
The method also enables replication of a **VM** (virtual machine) between **PM**s (physical machines).  
The minimum requirement is two PMs only and no shared storage is required.

## System diagram
```
     +----------------------------------------------------------+
     | PM1                                                      |
     | - Windows Server 2019          +-----------------------+ |
     |   Hyper-V                      | VM1                   | |
     | - EXPRESSCLUSTER X 4.1 (12.11) | - Windows Server 2019 | |
 +---+                                +-----------------------+ |
 |   |                                   |                      |
 |   +-----------------------------------|----------------------+ 
 |                                       |
 | Heartbeat                             | Mirroring
 |                                       |
 |   +-----------------------------------|----------------------+
 |   | PM2                               |                      |
 |   | - Windows Server 2019          +.......................+ |
 |   |   Hyper-V                      : VM1                   : |
 |   | - EXPRESSCLUSTER X 4.1 (12.11) : - Windows Server 2019 : |
 +---+                                +.......................+ |
     |                                                          |
     +----------------------------------------------------------+ 
```

## Overall steps
1. Prepare 2 PMs with Windows, Hyper-V, and EXPRESSCLUSTER installed.
2. Configure a Cluster, Failover group and **MD** (Mirror Disk) resource.
3. Create a VM on the MD.
4. Configure a Script Resource to control the VM.
5. Configure a Monitor Resource to monitor the VM.

The following describes step 3 and later.

## Steps

Assumption:
- The drive letter for data partition of MD resource is *X: drive*.
- The failover group is online on PM1 to allow access to the MD resource.
- The *Hyper-V Integration Services* is installed onto the VM to be controlled. 

On PM1
  1. Open Hyper-V Manager.
  2. Right click Hyper-V host PM1 > [New] > [Virtual Machine].
  3. Enter e.g. [VM1] as [Name] > specify the location under MD resource [X:\\Hyper-V\\VM Configs] > [Next].
  4. Specify whichever generation > [Next].
  5. Assign Memory > [Next].
  6. Configure networking > [Next].
  7. Select [Create a virtual hard disk]> specify [X:\\Hyper-V\\VM Configs] as [Location] > specify [Name] and [Size] as needed > [Next].
  8. Specify Installation Options as needed > [Next].
  9. Click [Finish].
  10. Open EC WebUI > move the failover group to PM2.

On PM2
  1. Open Hyper-V Manager.
  2. Right click Hyper-V host PM2 > [Import Virtual Machine].
  3. Specify [X:\\Hyper-V\\VM Configs\\VM1] as [Folder] > [Next].
  4. Select [**Register the virtual machine in-place (use the existing unique ID)**] > [Next].
  5. Click [Finish].

Open EC WebUI
  1. Stop the failover group.
  2. Change to [Config mode].

  **NOTE** : The following assumes the name of the VM as *vm1*

  3. **Add the Script Resource to Control the Virtual Machine** — add [Script resource] to the failover group >  

     edit [start.bat]

        ```
        rem **********
        rem Parameter : the name of the VM to be controlled in the Hyper-V manager
        set VMNAME=vm1
        rem **********
        IF "%CLP_EVENT%" == "RECOVER" GOTO EXIT

        powershell -Command "Start-VM -Name %VMNAME% -Confirm:$false"

        :EXIT
       ```

     edit [stop.bat]

        ```
        rem **********
        rem Parameter : the name of the VM to be controlled in the Hyper-V manager
        set VMNAME=vm1
        rem **********

        powershell -Command "Stop-VM -Name %VMNAME% -Force"
       ```

  4. **Add the Custom Monitor Resource** — add [Custom Monitor resource]

        edit [genw.bat]

        ```
        rem **********
        rem Parameter : the name of the VM to be controlled in the Hyper-V manager
        set VMNAME=vm1
        rem **********

        powershell -Command "if ((Get-VMIntegrationService -VMName %VMNAME% -Name Heartbeat).PrimaryOperationalStatus -ne \"OK\") {exit 1}"
        exit %ERRORLEVEL%
       ```

  5. Apply the configuration

## Restriction
VMs stored in the same MD resource need to move/failover together. It's good to control such VMs in the same failover group.

## Test and confirmation

|No.| Test item                       | Confirmation |
|---|---                              |---           |
| 1 | start the failover group on PM1 | PM1 started VM1 |
| 2 | move the failover group to PM2  | PM1 stopped VM1, then PM2 started VM1 |
| 3 | power off PM2                   | PM1 noticed heartbeat timeout, then started VM1 |
