# Hyper-V Live Migration **(Note: This content is incomplete and under investigation.)**

There are two ideas to utilize Live Migration in Hyper-V host cluster. 

- Using Windows Server Failover Clustering (WSFC)
	- [Live Migration solution with WSFC](LiveMigrationSLwithWSFC.md)
- Using Server Message Block (SMB)
	- [Live Migration solution with SMB](LiveMigrationSLwithSMB.md)

## Background

Hyper-V Live Migration can work without WSFC in DR cluster, but VM files in the source machine are deleted after migration.
For high-availability system, VM files should being synchronized at any time between cluster nodes.
We can use mirror disk to synchronize VM files.

However Hyper-V Live Migartion requires that source and destination disk are accessible, while ECX standby server cannot access the mirror disk.

Therefore, we need to make mirror disk data accessible from both destination and source hosts in some way.