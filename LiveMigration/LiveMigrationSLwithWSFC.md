# Live Migration solution with WSFC **(Note: This content is incomplete and under investigation.)**

Configuring VM Live Migration in Hyper-V host cluster with WSFC.

## Architecture

- ECX is installed on VMs where iSCSI target service is running, and ECX replicates the disk configured as iSCSI target.
	- Hyper-V VMs are created on the iSCSI target disk.
	- ECX data mirroring provides a virtual shared disk for WSFC.
	- WSFC uses the virtual shared disk as Cluster Shared Volume (CSV).
- ECX protects VMs on Hyper-V, means start / stop / monitor and realizing failover of VMs across Hyper-V boxes.

	![Architecture](Hyper-V-cluster-architecture-WSFC.png)

## Network

- Separating network for VM / management of VM and cluster / mirroring / iSCSI / Live Migration.

	![Network](Network-WSFC.png)

## Setting up 2-node WSFC clutser

## Setting up Hyper-V network

## Setting up iSCSI target VM (EC-VM1 and EC-VM2 in the diagram)

## Connecting to iSCSI target from host servers by iSCSI initiator

## Configuring CSV

## Creating a protected VM in CSV

## Adding script resources to control VMs and live migration
