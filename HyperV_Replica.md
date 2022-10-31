# Hyper-V Replica with ECX Configuration Steps

----

This document describes how to maintain Hyper-V Replica after the failover.

---- 

1.	Prepare 3 servers with Windows Server 2019 (2 x for ECX, 1 for replication server)

2.	ECX Servers Prep (Server 1 & Server 2)

	1.	Prepare a disk for mirroring on each server with disk space sufficient to hold a virtual machine and related files. Create two partitions on the disk:
		- One partition with 1 GB or larger, left as a RAW cluster partition with no formatting. 
		- Another partition for data
	2.	Obtain licenses for ExpressCluster operation and replication
	3.	Get updated scripts to move VM

3.	Replication Server Prep (Server 3)

	1. Install the Hyper-V Role
	2. Open Hyper-V Manager and then select Hyper-V settings for the server. In Replication Configuration select Enable this computer as a replica Server.
	3. Select Use Kerberos (HTTP) for authentication.
	4. Choose to Allow replication from any authenticated server and specify a location for Replica files.
	5. Open the firewall and enable the rules Hyper-V Replica HTTP Listener (TCP-In) and Hyper-V Replica HTTPS Listener (TCP-In)

4.	Follow directions from the [Quick Start Guide for Windows Server 2016 Hyper-V](https://www.nec.com/en/global/prod/expresscluster/en/support/Setup.html#Virtualization) to set up Hyper-V, install and configure ExpressCluster X, and create a VM on the mirror disk on Server 1 and Server 2.

	**Note**: Assuming nested virtulization, if the Primary and Standby ECX servers are VMs, run the following commands on the host machine for each ECX VM to allow the installation of Hyper-V. The ECX VMs must be turned off in order to run these commands:

		Set-VMProcessor -VMName "*Name_of_VM*" -ExposeVirtualizationExtensions $True
		Set-VMNetworkAdapter -VMName *Name_of_VM* -MacAddressSpoofing On

5.	Run [Openports.bat](https://github.com/EXPRESSCLUSTER/Tools/archive/master.zip) on both servers to allow ExpressCluster to communicate through the firewall

6.	Test failover by moving the VM from the Primary server to the Secondary server and then back again.

7.	While on the Primary server, set up Hyper-V replication of the VM to the replica server from Hyper-V manager.

	1.	Right-click on the VM in Hyper-V Manager and click Enable Replication.
	2.	Select the options you want up to the Choose Initial Replication page. Choose the default option to Send initial copy over the network.
	3.	Review the information on Completing the Enable Replication page and click Finish.
	4.	Wait until this process completes.
	5.	Confirm that files have been copied to the Hyper-V Replica server and that the VM is listed in Hyper-V manager in an Off state.

8.	Failover the VM to the Secondary server.
	* Note: Once the VM is moved, it takes under a minute for the VM to start up on the Secondary server. Once it is running, it is ready to be accessed.  However, when the VM was moved from the Primary server (Server 1) to the Secondary server (Server 2), the VM replication connection to the Replica server (Server 3) was lost. This replication connection needs to now be restored from the Secondary server to the Replica server. The Replica server still thinks that the Primary server is the source for replication. This link needs to be removed on the Replica server before replication can be restored. It is important to be sure that the VM is running before continuing to the next step.

9.	On the Hyper-V Replica server, open Hyper-V Manager, right click on the VM, and Remove Replication.
	* Note: Do NOT remove the VM from Hyper-V manager or make any other modifications to the VM files on this server. The VM copy will be used as the source for initializing replication from the Secondary server and it will not be necessary to recopy the large virtual hard disk files.

	Or the same operation can be run on the failover destination server (Server 2 in this example) as PowerShell command below.

		PS C:\> Remove-VMReplication -ComputerName <Replica Server> -VMName <VM Name>

	Here, "Replica Server" is Server 3. "VM Name" is VM to be replicated.

10.	Re-enable replication on the Secondary server

	1.	Right-click on the VM in Hyper-V Manager and click Enable Replication.
	2.	Select the options you want up to the Choose Initial Replication page. This time select Use an existing virtual machine on the Replica server as the initial copy.
	3.	Review the information on Completing the Enable Replication page and click Finish.
	4.	The synchronization progress can be monitored from Hyper-V Manager.

	* Note: The VM will continue to run normally. There is a synchronization process that runs in the background between the VM files on the Secondary server and the Replica server VM files, merging any changes. This process can take a number of minutes. Steps 8 - 10 can be run again to move the VM back to the Primary server.

	Or the same operation can be run on the failover destination server (Server 2 in this example) as PowerShell command below.

		PS C:\> Enable-VMReplication -ComputerName <Replica Server> -VMName <VM Name> -AsReplica
		PS C:\> Enable-VMReplication -ComputerName <VM Host Server> -VMName <VM Name> -ReplicaServerName <Replica Server> -ReplicaServerPort 80 -AuthenticationType Kerberos
		PS C:\> Start-VMInitialReplication -ComputerName <VM Host Server> -VMName <VM Name> -UseBackup	

	Here, "Replica Server" is Server 3. "VM Host Server " is Server 2. "VM Name" is VM to be replicated.

---
	2019.03.27	Gary Pope		1st issue  
	2019.03.29	Miyamoto Kazuyuki
