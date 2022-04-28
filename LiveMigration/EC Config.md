# Cluster Setup
1. Open a web browser on EC1 or a host machine
2. Start **Cluster WebUI**
    - Enter http://\<ec1 IP address\>:29003    
      e.g. http://172.31.255.11:29003
3. Change to **Config mode**
4. Click on **Cluster generation wizard**    

**Cluster Configuration**
- Cluster
	- Cluster Name: your preference
	- Language: your preference
- Basic Settings
	- Add EC2 by adding its IP address (e.g. 172.31.255.12)
- Interconnects    
  *\*Add/remove rows as needed*    

    |Priority |Type |MDC |EC1 |EC2 |
    |:---------|:-------|:---|:---|:---|
    | 1 | Kernel Mode | Do Not Use | 172.31.255.11 | 172.31.255.12 |
    | 2 | Mirror Communication Only | mdc1 | 172.31.253.11 | 172.31.253.12 |
    | 3 | Witness |	Do Not Use | Use | Use |

	- Select the Witness line and click on Properties in the upper left
	    - Target Host: IP address of witness server		
- NP Resolution
	- An HTTP entry should exist in the **NP Resolution List** for the witness server
- **Group**
	- Add
		- Basic Settings
			- Type: failover
			- Name: your preference
		- Startup Servers
			- Default
		- Group Attributes
			- Default
		- **Group Resource**
			- Add (*Floating IP resource*)
				- Info
					- Type: **Floating IP resource**
					- Name: As you like
				- Dependency
					- Default
				- Recovery Operation
					- Default
				- Details
					- IP Address: 172.31.254.10
			- Add (*Mirror disk resource*)
				- Info
					- Type: **Mirror disk resource**
					- Name: your preference
				- Dependency
					- Default
				- Recovery Operation
					- Default
				- Details
					- Mirror Partition Device Name: /dev/NMP1
					- Mount Point: N/A
					- Data Partition Device Name: /dev/cp-diska2
					- Cluster Partition Device Name: /dev/cp-diska1
					- File System: none
			- Add  (*EXEC resource for iSCSI*)
				- Info
					- Type: **EXEC resource**
					- Name: e.g. exec-iscsi
				- Dependency
					- Uncheck **Follow the default dependency**
					- Add the Floating IP resource
					- Add the Mirror disk resource
				- Recovery Operation
					- Default
				- Details
					- Select and Edit start.sh
					- Delete all contents and replace with the following:    
                                          *#!/bin/sh -eu   
                                          echo "Starting iSCSI Target"   
                                          systemctl start target   
                                          echo "Started  iSCSI Target ($?)"   
                                          exit 0*     
					- Select and Edit stop.sh
					- Delete all contents and replace with the following:    
					  *#!/bin/sh -eu    
					  echo "Stopping iSCSI Target"    
					  systemctl stop target    
					  echo "Stopped  iSCSI Target ($?)"    
					  exit 0*    
- Monitor
	- Default
5. **Apply the Configuration File**
6. Change to **Operation mode**, **Status** tab, and **Start** the failover group on EC1
