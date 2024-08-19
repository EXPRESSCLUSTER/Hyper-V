# ExpressCluster: Hyper-V Host Clustering Solution on Windows server 2022

This document provides a step-by-step guide for setting up a high-availability cluster of Hyper-V hosts.
This method also allows for the replication of **virtual machines (VMs)** across **cluster nodes** (physical machines).   
The minimum requirement is to have two nodes configured with EXPRESSCLUSTER, and there is no need for shared storage.

## System Diagram
```
  +----------------------------------------------------------+
  | Primary Server (Server1)                                 |
  | - Windows Server 2022          +-----------------------+ |
  |   Hyper-V                      | VM1                   | |
  | - EXPRESSCLUSTER X 5.2         | - Windows Server 2022 | |
  |   - Mirror Disk Resource       +-----------------------+ |
  |     - Data Partition       (X:\)                         |
  |     - Cluster Partition    (Y:\)                         |
  +-----------------------------------|----------------------+ 
                                      |
                                      | Mirroring
                                      |
  +-----------------------------------|----------------------+
  | Secondary Server (Server2)        |                      |
  | - Windows Server 2022          +.......................+ |
  |   Hyper-V                      : VM1                   : |
  | - EXPRESSCLUSTER X 5.2         : - Windows Server 2022 : |
  |   - Mirror Disk Resource       +.......................+ |
  |     - Data Partition       (X:\)                         |
  |     - Cluster Partition    (Y:\)                         |
  +----------------------------------------------------------+ 
```

### Cluster Configuration
- For Windows Server 2022 Hyper-V Host OS Cluster, following resources are required:
	- One or more Mirror Disk
    - The drive letter for data partition of MD resource is *X: drive*
	- One script resource per one VM
  - The failover group is online on Server1 to allow access to MD resource.
  - The *Hyper-V Integration Services* is installed on to VM to be controlled.  

### Folder Configuration
- On Data Partition, create a folder to store Hyper-V VM.
	- e.g.)
		```bat
		X:
		  - VM
		```
## Setup
### Install Hyper-V on Both Servers (Primary and Secondary)
1. Launch **Server Manager**.
1. Click **Manage** and click **Add Roles and Features**.
1. Click **Server Selection** on left pane.
1. Click **Server Roles** on left pane.
1. Check **Hyper-V** and click **Add Features**.
1. Click **Confirmation** on left pane.
1. Click **Install**.
1. After installation is completed, restart OS.

### Create Virtual Switch on Both Servers (Primary and Secondary)
The virtual switch name must be the same between on primary and on secondary server.
1. Launch **Hyper-V Manager**.
1. Click **Virtual Switch Manager** on right pane.
1. Select virtual switch type (e.g. External) and click **Create Virtual Switch**.
1. Enter **Name** (e.g. vswitch) and select actual network interface card (e.g. Broadcom NetXtreme Gigabit Ethernet). Click **OK**.

### Install EXPRESSCLUSTER on Both Servers (Primary and Secondary)
Please refer to [EXPRESSCLUSTER manual](https://www.nec.com/en/global/prod/expresscluster/en/doc/manuals/W52_IG_EN_02.pdf)

### Create a Base Cluster
- Create a failover group that includes a mirror disk resource.
- Apply the cluster configuration and start the cluster.

### Create a Virtual Machine on the Mirror Disk on Server1 (Primary Server)
1. Launch **Hyper-V Manager** on the primary server.
1. Click **New** and click **Virtual Machine** on right pane.
1. Click **Specify Name and Location** on left pane.
1. Enter the virtual machine name. Check **Store the virtual machine in a different location** and specify a directory on the mirror disk *(e.g. X:\VM)*. Click **Next**.
1. Choose the generation of the virtual machine and click **Next**.
1. Specify the amount of memory and click **Next**.
1. Select the virtual switch and click **Next**.
1. Select [Create a virtual hard disk]> specify **X:\VM** as [Location] > specify [Name] and [Size] on requisit > **Next**
1. Specify Installation Options on requisit > **Next**
1. Check the parameters and click **Finish**.
1. Choose installation method and click **Next**.
1. Check the parameters and click **Finish**.
1. Open EC WebUI > move the failover group to Server2 (Secondary Server)

### On Server2 (Secondary Server)
1. Launch **Hyper-V Manager** on the Secondary server.
1. Right click Hyper-V host Server2 > [Import Virtual Machine]
1. specify **X:\VM\VM1** as [Folder] > **Next**
1. select **Register the virtual machine in-place (use the existing unique ID)** > and click **Next**
1. **Finish**.

**Open EC WebUI**
  1. stop the failover group
  2. change to [Config mode]

  **NOTE** : The following assumes the name of the VM as *vm1*

  ### Add the Script Resource to Control the Virtual Machine

  3. add [Script resource] to the failover group >  

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

  4. add [Custom Monitor resource]

        edit [genw.bat]

        ```
        rem **********
        rem Parameter : the name of the VM to be controlled in the Hyper-V manager
        set VMNAME=vm1
        rem **********

        powershell -Command "if ((Get-VMIntegrationService -VMName %VMNAME% -Name Heartbeat).PrimaryOperationalStatus -ne \"OK\") {exit 1}"
        exit %ERRORLEVEL%
       ```

  5. Apply the configuration in ECX WebUI.

## Restriction
VMs stored in the same MD resource need to move/failover together. It's good to control such VMs in the same failover group.

## Test and confirmation

|No.| Test item                       | Confirmation |
|---|---                              |---           |
| 1 | start the failover group on Server1 | Server1 started VM1 |
| 2 | move the failover group to Server2  | Server1 stopped VM1, then Server2 started VM1 |
| 3 | power off Server2                   | Server1 noticed heart beat timeout, then startd VM1 |
