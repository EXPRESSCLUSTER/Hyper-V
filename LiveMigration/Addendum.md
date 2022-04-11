# Addendum

This section's purpose is to address some situations that might be experienced while using this solution.

## Phenomenon
### Unexpected Live Migration
Scenario: You obvserve unexpected live migration of the guest VM performed by Windows Failover Cluster Manager. The owner node changes to the standby host server and then ExpressCluster reacts by failing the group over to the standby ExpressCluster server.

The reason may be insufficient CPU or memory on the host machine. The guest VM may not have enough memory to run, leading to a failover.
Troubleshooting    
If you are lucky, the error messages will be obvious:    
e.g. Hyper-V Manager will display something like the following by the guest VM:    
An error occurred while attempting to start the selected virtual machine(s).

'<guest vm>' failed to start.

Not enough memory in the system to start the virtual machine <guest vm>.

Could not initialize memory: Ran out of memory (0x8007000E).   

e.g. Guest VM connection window may have the following error:    
The application encountered an error while attempting to change the state of 'TESTVM'.

'<guest vm>' failed to start.

Not enough memory in the system to start the virtual machine TESTVM.

Could not initialize memory: Ran out of memory (0x80070000E).

'<guest vm>' failed to start. (Virtual machine ID 20830CED-0629-4CC2-9AD9-21F6E87E3BE1)

Not enough memory in the system to start the virtual machine TESTVM with ram size 2048 megabytes. (Virtual machine ID 20830CED-0629-4CC2-9AD9-21F6E87E3BE1)

'TeSTVM' could not initialize memory: Ran out of memory (0x80070000E). (Virtual machine ID 20830CED-0629-4CC2-9AD9-21F6E87E3BE1)
e.g. Get-ClusterResource may have the following output    
Get-ClusterResource

Name				                  State					                    OwnerGroup	    ResourceType
----				                  -----					                    ----------	    ------------
Virtual Machine <guest vm>		Failed (Insufficient Resources)		<group name>		Virtual Machine

If you need to dig deeper, examine the WSFC and ExpressCluster log files for the following:
  
WSFC log: [Operational] 000010c0.0000179c::2022/03/30-15:27:15.681 INFO  The cluster load balancer has identified the current node is exceeding the CPU or memory usage threshold.  Virtual Machines will be moved to a new node to balance the cluster. 
  