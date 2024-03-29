# Live Migration solution with WSFC **(Note: This content is incomplete and under investigation.)**

Configuring VM Live Migration in Hyper-V host cluster with WSFC.

## Architecture

- ECX is installed on VMs where iSCSI target service is running. ECX replicates the disk configured as an iSCSI target.
	- Hyper-V VMs are created on the iSCSI target disk.
	- ECX data mirroring provides a virtual shared disk for WSFC.
	- WSFC uses the virtual shared disk as a Cluster Shared Volume (CSV).
- ECX protects VMs on Hyper-V (start / stop / monitor) and performs failover of VMs across Hyper-V boxes.

	![Architecture](Hyper-V-cluster-architecture-WSFC.PNG)

## Network

- Separate network for VM / management of VM and cluster / mirroring / iSCSI / Live Migration.
- One server is needed outside a WSFC cluster for ECX witness and WSFC quorum disk. Ideally this server should also be clustered, but currently this document describes a configuration with two WSFC servers and one quorum disk.

	![Network](Network-WSFC.PNG)

## Host servers' spec

- Windows Server 2019 Datacenter (Desktop Experience)
- 4 CPU
- 9GB RAM
- 4 NICs
- 2 HDDs, 40GB for OS and 60GB for EC-VM

## Setup procedure
### Installing Hyper-V

Open **Server Manager** and click **Add roles and features** from the dashboard.
- Check **Hyper-V** under **Server Roles**.
- Create one virtual switch for external access.
- Check **Allow this server to send and receive live migrations of virtual machines**.
	- Select **Use Credential Security Support Provider (CredSSP)**.
- VM's default location can be configured anywhere on the host machine, but it is better to save VMs to another disk for easy maintenance.

After completing Hyper-V installation, configure Hyper-V settings in Hyper-V Manager.
- Create Virtual Switches in Virtual Switch Manager.
	- Management_switch was created during Hyper-V installation.
	- Mirror_switch (External) should be newly created.
	- iSCSI_switch (External) should be newly created.
	- VM_switch (External) should be newly created.
- Edit Live Migrations Settings (under Hyper-V Settings)
	- Check **Enable incoming and outgoing migrations**.

----

### Host server settings

- Open network adapter settings and set an IP address for each vEthernet adapter.
- Join servers to a domain and configure the firewall of the domain.
- Login to the domain account.

Subsequent procedures should be performed using the domain account.

----

### Installing WSFC

Open **Server Manager** and click **Add roles and features**.
- Check **Failover Clustering** under **Features** and follow the wizard to install it.

----

### Configuring WSFC

Open **Failover Cluster Manager** and create a WSFC cluster between the host servers. Do not add all eligible storage while running the Create Cluster Wizard. A CSV disk will be added to the cluster later.
- https://docs.microsoft.com/en-us/windows-server/failover-clustering/create-failover-cluster

Once a cluster is created, in **Networks** setting, disable networks other than Management_network and Mirror_network.
- Right-click network name and open properties.
	- Select **Do not allow cluster network communication on this network**.

----

### Set up an ECX Witness Server

The host servers and EC VMs cannot be used for this purpose. Use a separate server, as the diagram indicates.
- [Set up Windows based Witness Server](https://docs.nec.co.jp/sites/default/files/minisite/static/8040160a-cffb-4492-ad83-db0cc52fec86/ecx_x43_windows_en/W43_RG_EN/W_RG_07.html#witness-server-service)
- [Set up Linux based Witness Server](https://docs.nec.co.jp/sites/default/files/minisite/static/3eccef94-8a6c-4a5d-b42a-51d243d264de/ecx_x43_linux_en/L43_RG_EN/L_RG_07.html#witness-server-service)

----

### Setting up iSCSI target VM (EC-VM1 and EC-VM2 in the diagram)

Open **Hyper-V Manager** on each host machine and create a new VM.

#### EC-VM's spec
- CentOS Linux release 8.2.2004 (Core)
- EXPRESSCLUSTER X 4.3.0-1
- 1 CPU
- 4GB RAM
- 3 NICs
- 2 HDDs, 30GB for OS and 25GB for mirror disk

After creating EC-VMs, change the VM settings as follows (stop them first!):
- **Automatic Start Action**
	- **Always start this virtual machine automatically**
	- **Startup delay**: 5 seconds
- **Automatic Stop Action**
	- **Shut down the guest operating system**

Once OS installation is finished, do the following on each EC VM:
1. Disable firewalld
	```
	# systemctl disable firewalld
	```
1. Disable dnf-cache.timer
	```
	# systemctl disable dnf-makecache.timer
	```
1. Disable SELinux
	```
	# sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
	```
1. Network settings
	- Configure IP addresses, gateway, DNS, proxy
1. Install iSCSI **targetcli**, **unzip**, **tar** and **perl** with yum command

	```
	# yum -y install targetcli unzip tar
	```
1. Disable and stop iSCSI target

	```
	# systemctl disable target
	# systemctl stop target
	```
1. Configure a disk for ECX mirroring
	1. Create an ECX cluster partition and ECX data partition.
		
		e.g. In the case /dev/sdb is used for the ECX mirror disk.
		```
		# parted -s /dev/sdb mklabel msdos mkpart primary 0% 1025MiB mkpart primary 1025MiB 100%
		```
1. Configure a symbolic link for the disk device

	On a Linux machine, names of disk devices may change sometimes because the Linux OS determines device names in the order in which they are recognized after startup.

	By creating a symbolic link for the disk device, you can use a static unique name to reference the disk, even if the device name is changed.

	1. Check disk IDs

		e.g. In the case /dev/sdb is used for the ECX mirror disk (with sample output).
		```
		# /lib/udev/scsi_id --whitelisted --device=/dev/sdb
		3600224804fb4d824c64c0f4156f86fc9
		```
	1. Create a rule file for a symbolic link

		e.g.
		```
		# vi /etc/udev/rules.d/99-clusterpro-devices.rules
		KERNEL=="sd*[^0-9]",ENV{ID_SERIAL}=="",IMPORT{program}="/lib/udev/scsi_id --whitelisted --device=/dev/%k"
		KERNEL=="sd*[^0-9]",ENV{ID_SERIAL}=="",IMPORT{parent}=="ID_*"
		ENV{ID_SERIAL}=="3600224804fb4d824c64c0f4156f86fc9",SYMLINK+="cp-diska%n"
		```
		You only need to edit *3600224804fb4d824c64c0f4156f86fc9* depending on your environment.

1. Install ECX
    rpm -ivh expresscls*.rpm
1. Register ECX license files
    clplcnsc -i ECX*.key
1. Reboot OS
1. Confirm that the symbolic link is enabled.
	```
	# ls -l /dev/cp-*
	lrwxrwxrwx 1 root root 3 Feb 16 15:42 /dev/cp-diska -> sdc
	lrwxrwxrwx 1 root root 4 Feb 16 17:24 /dev/cp-diska1 -> sdc1
	lrwxrwxrwx 1 root root 4 Feb 16 17:04 /dev/cp-diska2 -> sdc2
	```
1. Once you complete the above steps on both EC VMs, create an ECX cluster    
If you are not familiar with ECX cluster configuration, you can follow this [guide](EC%20Config.md) to set up the cluster with the required ECX resources. The key ECX resources required, along with the settings which need to be modified are included below for reference.
- LAN heartbeat
- Witness heartbeat
    - Be sure the [Witness Server](#Set-up-an-ECX-Witness-Server) is already set up.
- HTTP NP
- Floating IP address
	- Should belong to the network connecting to iSCSI_switch.
- Mirror disk
	- File System: none
	- Data Partition Device Name: /dev/cp-diska2
	- Cluster Partition Device Name: /dev/cp-diska1
- EXEC
	- e.g. Resource name is *exec-iscsi*
	- Should depend on the Floating IP resource and Mirror disk resource.
		- Add Floating IP and Mirror disk resources in the **Dependency** tab.
	- Replace scripts with new scripts below:

		*start.sh*
		```
		#!/bin/sh -eu
		echo "Starting iSCSI Target"
		systemctl start target
		echo "Started  iSCSI Target ($?)"
		exit 0
		```
		*stop.sh*
		```
		#!/bin/sh -eu
		echo "Stopping iSCSI Target"
		systemctl stop target
		echo "Stopped  iSCSI Target ($?)"
		exit 0
		```

----

### Configuring iSCSI target

1. Confirm that the failover group is running on EC-VM1.
1. Configure NMP1 as a target disk.

	```
	systemctl start target
	targetcli /backstores/block create name=idisk1 dev=/dev/NMP1

	# Creating IQN
	targetcli /iscsi create iqn.1996-10.com.ecx

	# Assigning LUN to IQN
	targetcli /iscsi/iqn.1996-10.com.ecx/tpg1/luns create /backstores/block/idisk1

	# Allow Host 1 and 2 (*IQN of iSCSI Initiator*) to scan the iSCSI target

	targetcli /iscsi/iqn.1996-10.com.ecx/tpg1/acls create $Host1IQN
	targetcli /iscsi/iqn.1996-10.com.ecx/tpg1/acls create $Host2IQN

	# Save the configuration
	targetcli saveconfig
	```

	\*You can get the IQN from the **iSCSI Initiator**'s Configuration tab on each host server.
1. Move the failover group to EC-VM2 and configure the same as EC-VM1.
1. Move the failover group back to EC-VM1.

----

### Connecting to iSCSI target from host servers

1. Open the **iSCSI Initiator** on each host server.
1. In the **Targets** tab, type the floating IP address and click **Quick Connect**.
1. Select the target and click **Connect**.

This disk will be configured as a WSFC cluster shared volume in the next steps.

----

### Configuring CSV

1. Open **Disk Management** on either host server.
1. Bring the new disk online, initialize it, and format it as NTFS.
1. Open **Disk Management** on the other host server, and bring the new disk online.
1. Open **Failover Cluster Manager**.
1. In **Storage > Disks** page, Add the disk and then *Add to Cluster Shared Volumes*.

----

### Configuring quorum disk

A shared disk that is accessible from both hosts is needed outside host servers.

A quorum disk size should be larger than 512MB.
- https://docs.microsoft.com/en-us/windows-server/failover-clustering/manage-cluster-quorum

You can co-locate the disk on the ECX witness server and configure it as an iSCSI target.

1. Open **Disk Management** on either host server.
1. Bring the new disk online, initiialize it, and format it as NTFS.
1. Open **Disk Management** on the other host server, and bring the new disk online.
1. Open **Failover Cluster Manager**.
1. In **Storage > Disks** page, Add the disk.
1. Switch to the cluster summary page and select **Configure Cluster Quorum Settings** in **More Actions**.
1. **Select the quorum witness**.
1. **Configure a disk witness**.
1. Check the disk.

The disk should now be assigned to *Disk Witness in Quorum*.

----

### Creating a protected VM in CSV

In the case you created a new VM
- In Failover Cluster Manager's **Roles** page, select **New Virtual Machine** in **Virtual Machines**.    
    \*Be sure to set the VM and VHDX locations to the cluster storage volume.

In the case that you import an existing VM into Failover Cluster Manager
- Import a VM into **Hyper-V Manager** (or use an existing VM).
- In Failover Cluster Manager's **Roles** page, select **Configure Role**, and then select **Virtual Machine**.

After creating or importing a protected VM, configure VM settings as follows on **Hyper-V Manager**:
- **Automatic Start Action**
	- **Nothing**
- **Automatic Stop Action**
	- **Shut down the guest operating system**

----

### Configuring WSFC Live Migration

- In Failover Cluster Manager's **Networks** page, select **Live Migration Settings**.
- Uncheck networks other than VM_network.

----

### Configuring WSFC settings to restrain WSFC recovery action

To prevent conflicts between recovery actions, WSFC recovery action needs to be disabled.

Check the current quarantine configuration:
```
> get-cluster | Select Name,Resiliency*,Quarantine*

Name                    : ws2019-lm-cluster
ResiliencyDefaultPeriod : 240
ResiliencyLevel         : AlwaysIsolate
QuarantineDuration      : 7200
QuarantineThreshold     : 3
```

Change the quarantine configuration:
```
> (Get-Cluster).ResiliencyDefaultPeriod = 9999
> (Get-Cluster).QuarantineThreshold = 9999
```

WSFC behavior after executing the above commands:
- After WSFC detects the other cluster node is isolated, WSFC waits 9999 seconds until it starts recovery action.
- WSFC quarantines a cluster node that has been turned off unintentionally 9999 times in an hour.

Disabe the VM failover function:
1. Open VM property in **Failover Cluster Manager**.
1. In **Failover** tab, change settings as follows:
	- **Maximum failures in the specified period**: 0
	- **Period (hours)**: 0
	- **Prevent failback**

----

### Configuring ssh settings

SSH is required to allow each EC-VM to send commands to host servers.

On host servers:
1. Download OpenSSH-Win64.zip
	- https://github.com/PowerShell/Win32-OpenSSH/releases
1. Unzip the file and move the OpenSSH-Win64 folder under *Program Files* folder.
1. Execute **install-sshd.ps1**.
1. Open **Service Manager**, start the **OpenSSH SSH Server** service, and change its startup type to **Automatic**.

On EC-VMs:
1. Create a ssh key pair.

	```
	# yes no | ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
	```
1. Copy the public key to host servers.    
    \*TCP port 22 needs to be opened through the host server’s firewall.

	```
	# scp /root/.ssh/id_rsa.pub Administrator@<IP of host 1>:C:\\ProgramData/ssh/<EC-VM hostname>
	# scp /root/.ssh/id_rsa.pub Administrator@<IP of host 2>:C:\\ProgramData/ssh/<EC-VM hostname>
	```

On host servers:
1. Merge EC-VM's key files into **administrators_authorized_keys**.
	```
	> type C:\ProgramData\ssh\ec-vm1 C:\ProgramData\ssh\ec-vm2 > administrators_authorized_keys
	(e.g. if EC-VM hostnames are ec-vm1 and ec-vm2 respectively)
	```
1. Add the following lines to **sshd_config** in *C:\ProgramData\ssh*.
	```
	PubkeyAuthentication yes
	PasswordAuthentication no
	PermitEmptyPasswords yes
	```
1. Edit file permissions of **administrators_authorized_keys**.
	- Open the properties dialog of the file.
	- Click **Advanced** in **Security** tab.
	- Click **Disable inheritance**.
	- Select **Convert inherited permissions into explicit permissions on this object**.
	- Delete **Authenticated Users** from Permission entries.
1. Restart the **OpenSSH SSH Server** service.

After completing all of the above steps, confirm that EC-VM1 and 2 can connect to both host servers using the ssh command without typing a password.    

e.g.  \# ssh -i .ssh/id_rsa -l \<Administrator account\> \<host IP\>

----

### Adding EXEC resources to control a VM and live migration

1. Download [scripts](scripts) from GitHub repository.
1. Add an EXEC resource to control a VM in Cluster WebUI.
	- e.g. Resource name is *exec-VMNAME*
	- Depends on *exec-iscsi*.
	- Replace *start.sh* with *vm-start.pl*.
	- Edit the **Configuration** section in the start script to match your environment.
	- Replace *stop.sh* with *vm-stop.pl*.
	- Edit the **Configuration** section in the stop script to match your environment.
	- Set **Log Output Path** in **Tuning** page, **Maintenance** tab, to */opt/nec/clusterpro/log/exec-VMNAME.log*.
	- Check *Rotate Log* on **Maintenance** tab.
1. **Apply the Configuration File**.

----

### Adding custom monitor resource for a VM

One custom monitor resource is needed per VM, and one is needed per cluster.

1. Add a custom monitor resource to monitor a VM in Cluster WebUI
	- e.g. Monitor name is *genw-VMNAME*
	- **Retry Count** is 1.
	- Monitor timing is when *exec-VMNAME* is active.
	- Replace *genw.sh* with *genw-vm.pl*.
	- Edit the **Configuration** section in the monitor script to match your environment.
	- **Log Output Path** is */opt/nec/clusterpro/log/genw-VMNAME.log*.
	- Check **Rotate Log**.
	- **Normal Return Value** is 0.
	- **Recovery Action** is **Executing failover to the recovery target**.
	- **Recovery Target** is the failover group that includes the VM.
1. Add a custom monitor resource to monitor the standby EC-VM
	- e.g. Monitor name is *genw-remote-node*
	- Monitor timing is when the md resource is active.
	- Replace *genw.sh* with *genw-remote-node.pl*.
	- Edit the **Configuration** section in the monitor script to match your environment.
	- **Log Output Path** is */opt/nec/clusterpro/log/genw-remote-node.log*.
	- Check **Rotate Log**.
	- **Normal Return Value** is 0.
	- **Recovery Action** is **Custom settings**.
	- **Recovery Target** is **LocalServer**.
	- **Final Action** is **No operation**.
1. **Apply the Configuration File**.

----

## Script details

*exec-VMNAME*
- When it starts, the VM is registered on Hyper-V Manager and powered on.
- When it stops, the VM is unregistered on Hyper-V Manager and powered off.

*genw-VMNAME*
- Executes the recovery action if the VM is not running on its host server.

*genw-remote-node*
- Starts the ECX cluster if it is not running on the standby EC-VM.
- Powers on the standby EC-VM if it is not running.

## How to operate a cluster

How to execute Live Migration:
- In the case that a user moves a failover group manually and a VM is running on the source server, Live Migration is executed without stopping the VM.

How to stop the VM to change its property:
- Suspend *genw-VMNAME*.
- Please note that the VM should be powered on after changing its property and before resuming *genw-VMNAME*.

## Testing

Please refer to [Test items of Live Migration SL](Testing.md).
