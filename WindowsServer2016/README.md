# Host OS Cluster with Windows Server 2016 Hyper-V and EXPRESSCLUSTER
## Overview
- Create a Mirror Disk Resource of EXPRESSCLUSTER.
- Create a virtual machine on the mirror disk to replicate the virtual machine image between the cluster nodes.
- Add script files to control the virtual machine.

## Evaluation Environment
```
  +----------------------------------------------------------+
  | ws2016-01                                                |
  | - Windows Server 2016          +-----------------------+ |
  |   Hyper-V                      | ws2016-03             | |
  | - EXPRESSCLUSTER X 4.2 (12.22) | - Windows Server 2016 | |
  |   - Mirror Disk Resource       +-----------------------+ |
  |     - Cluster Partition (W:\)     |                      |
  |     - Data Partition    (X:\)     |                      |
  +-----------------------------------|----------------------+ 
                                      |
                                      | Mirroring
                                      |
  +-----------------------------------|----------------------+
  | ws2016-02                         |                      |
  | - Windows Server 2016          +.......................+ |
  |   Hyper-V                      : ws2016-03             : |
  | - EXPRESSCLUSTER X 4.2 (12.22) : - Windows Server 2016 : |
  |   - Mirror Disk Resource       +.......................+ |
  |     - Cluster Partition (W:\)                            |
  |     - Data Partition    (X:\)                            |
  +----------------------------------------------------------+ 
```
## Install Hyper-V on Both Servers
1. Launch **Server Manager**.
1. Click **Manage** and click **Add Roles and Features**.
1. Click **Server Selection** on left pane.
1. Click **Server Roles** on left pane.
1. Check **Hyper-V** and click **Add Features**.
1. Click **Confirmation** on left pane.
1. Click **Install**.
1. After installation is completed, restart OS.

## Create Virtual Switch on Both Servers
The virtual switch name must be the same between on primary and on secondary server.
1. Launch **Hyper-V Manager**.
1. Click **Virtual Switch Manager** on right pane.
1. Select virtual switch type (e.g. External) and click **Create Virtual Switch**.
1. Enter **Name** (e.g. vswitch) and select actual network interface card (e.g. Broadcom NetXtreme Gigabit Ethernet). Click **OK**.

## Install EXPRESSCLUSTER on Both Servers
Please refer to [EXPRESSCLUSTER manual](https://www.nec.com/en/global/prod/expresscluster/en/support/manuals.html)

## Create a Base Cluster
- Create a failover group that includes a mirror disk resource.
- Upload the cluster configuration and start the cluster.

## Create a Virtual Machine on the Mirror Disk
1. Move the failover group to the primary server.
1. Launch **Hyper-V Manager** on the primary server.
1. Click **New** and click **Virtual Machine** on right pane.
1. Click **Specify Name and Location** on left pane.
1. Enter the virtual machine name. Check **Store the virtual machine in a different location** and specify a directory on the mirror disk *(e.g. X:\vm)*. Click **Next**.
1. Choose the generation of the virtual machine and click **Next**.
1. Specify the amount of memory and click **Next**.
1. Select the virtual switch and click **Next**.
1. Enter the VHDX file name and click **Next**.
1. Choose installation method and click **Next**.
1. Check the parameters and click **Finish**.
1. On Hyper-V Manager, select the virtual machine and click **Start**. And click **Connect**.
1. Install OS on the virtual machine.
1. After the installation is complete, shutdown the virtual machine.
1. Create a directory *(e.g. X:\vm\ws2016-03\bak)* to take a backup of the virtual machine files.
1. Copy the all directories and files from the source to the destination.
    ```
    Source     : X:\vm\ws2016-03\Virtual Machines
    Destination: X:\vm\ws2016-03\bak
    ```
1. On Hyper-V Manager, select the virtual machine and click **Delete**.

## Add the Script Resource to Control the Virtual Machine
1. Download the script files for Windows Server 2016 Hyper-V.
    - https://github.com/EXPRESSCLUSTER/Hyper-V/tree/master/WindowsServer2016/script
1. Add the script resource to the failover group.
    - Replace **start.bat** with the script you downloaded.
    - Replace **stop.bat** with the script you downloaded.
    - Add **SetEnvironment.bat**.
      - After the addition of script, Edit the script.
      
        As an example, if the VM path is *X:\vm\ws2016-03\Virtual Machines\12345678-ABCD-1234-ABCD-123456789ABC*
        ```
        set VM=ws2016-03
        set ID=12345678-ABCD-1234-ABCD-123456789ABC
        set SourcePath=X:\vm\ws2016-03\Virtual Machines
        set DestPath=X:\vm\ws2016-03\bak
        ```
    - Add **start.ps1**.
    - Add **stop.ps1**.
    - Add **vmstate.ps1**.
    - Click the **Tuning** button.
    - Enter 0 for **Normal Return Value** for the **start** and **stop** sections.
1. Add Custom Monitor Resource
    - Select **Active** as **Monitor Timing**, and select the script resource for VM as **Target Resource**. 
    - Replace **genw.bat** with the script you downloaded.
      - After the addition of script, Edit the script.

        ```
        cd "C:\Program Files\EXPRESSCLUSTER\scripts\<failover group name>\<script resource name>"
        ```
    - Select the script resource for VM as **Recovery Target**.

## Upload the Cluster Configuration and test the cluster
1. Apply the configuration file on WebUI Configuration mode.
1. Start the failover group on the primary server.
1. After the failover group has started, confim that the virtual machine is running on PowerShell.
    ```
    PS> Get-VM -VMName <virtual machine name>

    Name        State   CPUUsage(%) ...
    ----        -----   ----------- ...
    ws2016-03   Running 10          ...
    ```

## Restriction
Following features are not supported.
- Hyper-V Checkpoints
- Hyper-V Live Migration/Quick Migration