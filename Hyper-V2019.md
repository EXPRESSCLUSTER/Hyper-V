# Host OS Cluster with Windows Server 2016 Hyper-V and EXPRESSCLUSTER
## Overview
- Create a Mirror Disk Resource of EXPRESSCLUSTER.
- Create a virtual machine on the mirror disk to replicate the virtual machine image between the cluster nodes.
- Add script files to control the virtual machine.
## Evaluation Environment
```
  +----------------------------------------------------------+
  | ws2019-01                                                |
  | - Windows Server 2019          +-----------------------+ |
  |   Hyper-V                      | ws2019-03             | |
  | - EXPRESSCLUSTER X 4.0 (12.01) | - Windows Server 2019 | |
  |                                +-----------------------+ |
  |                                   |                      |
  +-----------------------------------|----------------------+ 
                                      |
                                      | Mirroring
                                      |
  +-----------------------------------|----------------------+
  | ws2019-02                         |                      |
  | - Windows Server 2019          +.......................+ |
  |   Hyper-V                      : ws2016-03             : |
  | - EXPRESSCLUSTER X 4.0 (12.01) : - Windows Server 2019 : |
  |                                +.......................+ |
  |                                                          |
  +----------------------------------------------------------+ 
```
## Install Hyper-V
## Install EXPRESSCLUSTER
## Create a Base Cluster
## Create a Virtual Machine on the Mirror Disk
## Add Script Resource to Control the Virtual Machine
