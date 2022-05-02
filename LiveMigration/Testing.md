# Test items of Live Migration SL

## Notes for WSFC quarantine

WSFC has a quarantine function to isolate a cluster node that has crashed a certain number of times for a certain period. If you followed the setup document, the quarantine threshold would have been extended to 9999 times.

Even with this setting, your server might still be quarantined. If that happens, you can release the quarantined server with the following command:

```
> Start-ClusterNode -ClearQuarantine
```

## Normal operation

Move a failover group.
1. From ec1 to ec2.
    - Live migration is executed without stopping the VM.
1. From ec2 to ec1.
    - Live migration is executed without stopping the VM.
       
Start/Stop a failover group
1. The failover group is running on ec1.
1. Stop the failover group.
    - VM is stopped.
1. Start the failover group on ec1.
    - VM is started.
1. Stop the failover group.
    - VM is stopped.
1. Start the failover group on ec2.
	- Quick migration is executed and then VM is started.

## Power off

Host server shutdown
- Power off host 1 > Wait for completion of the failover.
- Power on host 1 > Wait for completion of the mirror-recovery.
- Power off host 2 > Wait for completion of the failover.
- Power on host 2 > Wait for completion of the mirror-recovery.
- Power off host 1 and 2 > Power on host 1 and 2 > (If the md is in an inconsistent state, you need to execute data copy in WebUI Mirror disks tab.) > Wait for the target VM to complete startup.

EC VM shutdown
- Same result as Power off test.

## NP situation


## Appendix

### Powershell commands to check a cluster component's status

WSFC node status
```
PS C:\Users\Administrator.2016DOM> Get-ClusterNode

Name          State Type
----          ----- ----
ws2019-host-1 Up    Node
ws2019-host-2 Up    Node
```
---
CSV status
```
PS C:\Users\Administrator.2016DOM> Get-ClusterSharedVolume

Name           State  Node
----           -----  ----
Cluster Disk 1 Online ws2019-host-2
```
---
Cluster resource status
```
Name                                    State  OwnerGroup    ResourceType
----                                    -----  ----------    ------------
Cluster Disk 2                          Online Cluster Group Physical Disk
Cluster IP Address                      Online Cluster Group IP Address
Cluster Name                            Online Cluster Group Network Name
Storage Qos Resource                    Online Cluster Group Storage QoS Policy Manager
Virtual Machine Cent8.2-1               Online Cent8.2-1     Virtual Machine
Virtual Machine Cluster WMI             Online Cluster Group Virtual Machine Cluster WMI
Virtual Machine Configuration Cent8.2-1 Online Cent8.2-1     Virtual Machine Configuration
```
*exec-VMNAME* starts or stops *Virtual Machine Configuration VMNAME*.

When *Virtual Machine Configuration VMNAME* is online, the VM is listed in Hyper-V Manager.

When it is offline, the VM is not visible in Hyper-V Manager.

---
Cluster group status
```
PS C:\Users\Administrator.2016DOM> Get-ClusterGroup

Name              OwnerNode     State
----              ---------     -----
Available Storage ws2019-host-2 Offline
Cent8.2-1         ws2019-host-2 Online
Cluster Group     ws2019-host-2 Online
```
A cluster group *VMNAME* is created automatically when a VM is added to the WSFC cluster.

*VMNAME* group is composed of multiple resources, but its state shows whether the VM is running or not.

---
Powershell command help
```
PS C:\Users\Administrator.2016DOM> Get-Help -Name Get-ClusterNode

NAME
    Get-ClusterNode

SYNTAX
    Get-ClusterNode [[-Name] <StringCollection>] [-InputObject <psobject>] [-Cluster <string>]  [<CommonParameters>]
.
.
```
---
Powershell command list
```
PS C:\Users\Administrator.2016DOM> Get-Command -Module FailoverClusters | Out-GridView
PS C:\Users\Administrator.2016DOM> Get-Command -Module Hyper-V | Out-GridView
```

---
Collect WSFC logs
```
PS C:\Users\Administrator.2016DOM\Downloads> get-clusterlog -destination . -Timespan 10080

Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        3/23/2022   6:26 PM       22763610 ws2019-host-1_cluster.log
-a----        3/23/2022   6:26 PM      130351286 ws2019-host-2_cluster.log


PS C:\Users\Administrator.2016DOM\Downloads>
```
*Destination* option specifies the location where log files are saved.

*Timespan* option specifies a time period covered by the logs. The above sample command covers the last 10080 minutes (equivalent to 1 week).

---
## Troubleshooting

See [Addendum](Addendum.md)