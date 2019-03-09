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
  | - EXPRESSCLUSTER X 4.0 (12.00) | - Windows Server 2016 | |
  |                                +-----------------------+ |
  |                                   |                      |
  +-----------------------------------|----------------------+ 
                                      |
                                      | Mirroring
                                      |
  +-----------------------------------|----------------------+
  | ws2016-02                         |                      |
  | - Windows Server 2016          +.......................+ |
  |   Hyper-V                      : ws2016-03             : |
  | - EXPRESSCLUSTER X 4.0 (12.00) : - Windows Server 2016 : |
  |                                +.......................+ |
  |                                                          |
  +----------------------------------------------------------+ 
```
## Install Hyper-V
## Install EXPRESSCLUSTER
## Create a Base Cluster
## Create a Virtual Machine on the Mirror Disk
## Add Script Resource to Control the Virtual Machine

start.ps1

    Import-VM -Path $env:VMCX2 -Confirm:$False
    Start-VM -Name $env:VM -Confirm:$False

stop.ps1

    Stop-VM -Name $env:VM -Force
    robocopy $env:SourcePath $env:DestPath /MIR
    Remove-VM -Name $env:VM -Force
