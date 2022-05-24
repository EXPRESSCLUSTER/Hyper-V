#!/usr/bin/perl -w
#
# Script to start the Virtual Machine
#
use strict;
#--------------------------------------------------------------
# Configuration
#--------------------------------------------------------------
# The VM name displayed in Hyper-V Manager Virtual Machines list.
my @vm_names = (
	'Cent8.2-1'
);

# The Cluster Shared Disk name displayed in Failover Cluster Manager.
my $csv_name = 'Cluster Disk 1';

# The IP address of Hyper-V host servers
my $host1_ip = "192.168.137.196";
my $host2_ip = "192.168.137.197";

# The IP address of EC VMs
my $ec1 = "192.168.137.199";
my $ec2 = "192.168.137.200";

# The IP address of iSCSI target
my $target_ip = "192.168.139.201";

# The account and domain name used to control WSFC.
my $wsfc_account = "Administrator";
my $wsfc_domain = "2016dom.local";
#--------------------------------------------------------------
# The check interval for VM, VM Configuration, CSV status. (second)
my $interval = 6;
# The maximum count to check the status.
my $max_cnt = 50;
#--------------------------------------------------------------
# Global values
my $vm_name = "";
my $cmd = "";
my @lines = ();
my $ssh_prefix = "ssh -i ~/.ssh/id_rsa -l $wsfc_account\@$wsfc_domain";
my $target_exist = 0;
my $vm_state = "";
my $vm_owner = "";
my $vm_config_state = "";
my $csv_state = "";
my $csv_owner = "";
my $ownhost_ip = "";
my $opphost_ip = "";
my $ownhost = "";
my $opphost = "";
my $ownhost_state = "";
my $opphost_state = "";
my $clp_event = $ENV{CLP_EVENT};

my $tmp = `ip address | grep $ec1`;
if ($? == 0) {
	$ownhost_ip = $host1_ip;
	$opphost_ip = $host2_ip;
} else {
	$tmp = `ip address | grep $ec2`;
	if ($? == 0) {
		$ownhost_ip = $host2_ip;
		$opphost_ip = $host1_ip;
	} else {
		&Log("[E] Invalid configuration (Management host IP could not be found).\n");
		exit 1;
	}
}

#--------------------------------------------------------------
# Main
#--------------------------------------------------------------
my $r = 0;
foreach (@vm_names){
	$vm_name = $_;
	&Log("[I] [$vm_name]\n");

	if (&PreChk()) {
		$r = 1;
		next;
	}

	if (&WaitIscsiConnect()) {
		$r = 1;
		next;
	}

	if (&CsvMove()) {
		$r = 1;
		next;
	}

	if (&CsvStart()) {
		$r = 1;
		next;
	}

	if (&VmConfigStart()) {
		$r = 1;
		next;
	}

	if ($vm_owner eq $opphost) {
		if (&VmMigration()) {
			$r = 1;
			next;
		}
	}

	# Vm_owner is definitely ownhost because if it was running on opphost,
	# vm was migrated to ownhost or this program already exited due to migration failure.
	# Start-VM shows no error if the VM is already running.
	if (&VmPowerOn()) {
		$r = 1;
		next;
	}
}
exit $r;
#--------------------------------------------------------------
# Functions
#--------------------------------------------------------------
sub PreChk {
	if (&execution("$ssh_prefix $ownhost_ip hostname")) {
		&Log("[E][PreChk] could not get my own hostname.\n");
		return 1;
	}
	foreach (@lines) {
		if (/(\S+)/) {
			$ownhost = $1;
		}
	}

	&execution("$ssh_prefix $ownhost_ip Powershell Get-ClusterNode");
	foreach (@lines) {
		if (/(\S+)\s+(\S+)\s.*/) {
			if ($1 ne $ownhost) {
				$opphost = $1;
				$opphost_state = $2;
			} else {
				$ownhost_state = $2;
			}
		}
	}
	&Log("[I][PreChk] ownhost is [$ownhost], status [$ownhost_state].\n");
	&Log("[I][PreChk] opphost is [$opphost], status [$opphost_state].\n");

	&execution("$ssh_prefix $ownhost_ip Powershell Get-ClusterGroup");
	foreach (@lines) {
		if (/$vm_name\s+(\S+)\s+(\S+)/) {
			$vm_owner = $1;
			$vm_state = $2;
		}
	}
	&Log("[I][PreChk] [$vm_name] is hosted by [$vm_owner], status [$vm_state].\n");

	&execution("$ssh_prefix $ownhost_ip Powershell \"(Get-ClusterSharedVolume -Name '$csv_name').State\"");
	foreach (@lines) {
		if (/(\S+)/) {
			$csv_state = $1;
		}
	}
	&execution("$ssh_prefix $ownhost_ip Powershell \"(Get-ClusterSharedVolume -Name '$csv_name').OwnerNode\"");
	foreach (@lines) {
		if (/(\S+)\s+.*/) {
			$csv_owner = $1;
		}
	}
	&Log("[I][PreChk] [$csv_name] state is hosted by [$csv_owner], status [$csv_state].\n");
	return 0;
}
#--------------------------------------------------------------
sub WaitIscsiConnect {
	$target_exist = 0;
	for (my $i = 0; $i < $max_cnt; $i++){
		&execution("$ssh_prefix $ownhost_ip Powershell Get-IscsiConnection");
		foreach (@lines) {
			if (/TargetAddress\s+:\s+$target_ip/) {
				$vm_config_state = $1;
				return 0;
			}
		}

		&Log("[I][WaitIscsiConnection] Waiting for $target_ip to be connected. (cnt=$i)\n");
		sleep $interval;
	}

	&Log("[E][WaitIscsiConnection] $target_ip connection failed. (cnt=$max_cnt)\n");
	return 1;
}
#--------------------------------------------------------------
sub CsvMove {
	# No error if the csv is already online on the destination server.
	# After ECX down, the first CSV move command will fail.
	for (my $i = 0; $i < $max_cnt; $i++){
		if (&execution("$ssh_prefix $ownhost_ip Powershell \"Move-ClusterSharedVolume -Name '$csv_name' -Node $ownhost\"")) {
			&Log("[W][CsvMove] CSV failed to move. (cnt=$i)\n");
		} else {
			return 0
		}
		sleep $interval;
	}

	&Log("[E][CsvMove] CSV failed to move.\n");
	return 1;
}
#--------------------------------------------------------------
sub CsvStart {
	# No error if the csv is already online on the destination server.
	# After host down, the first CSV start command will fail.
	for (my $i = 0; $i < $max_cnt; $i++){
		if (&execution("$ssh_prefix $ownhost_ip Powershell \"Start-ClusterResource -Name '$csv_name'\"")) {
			&Log("[W][CsvStart] CSV failed to start. (cnt=$i)\n");
		} else {
			return 0
		}
		sleep $interval;
	}

	&Log("[E][CsvStart] CSV failed to start.\n");
	return 1;
}
#--------------------------------------------------------------
sub VmConfigStart {
	for (my $i = 0; $i < $max_cnt; $i++){
		# No error if the resource is already online on the destination server.
		if (&execution("$ssh_prefix $ownhost_ip Powershell \"Start-ClusterResource 'Virtual Machine Configuration $vm_name'\"")) {
			&Log("[E][VmConfigStart] Configuration [$vm_name] failed to start.\n");
			return 1;
		}

		&execution("$ssh_prefix $ownhost_ip Powershell Get-ClusterResource");
		foreach (@lines) {
			if (/Virtual Machine Configuration $vm_name\s+(\S+)\s.*/) {
				$vm_config_state = $1;
			}
		}

		if ($vm_config_state eq "Online") {
			return 0;
		}

		&Log("[I][VmConfigStart] Configuration [$vm_name] waiting to start. (cnt=$i)\n");
		sleep $interval;
	}

	&Log("[E][VmConfigStart] Configuration [$vm_name] failed to start. (cnt=$max_cnt)\n");
	return 1;
}
#--------------------------------------------------------------
sub VmMigration {
	my $type = "";
	if ($clp_event eq "START" && $vm_state eq "Online") {
		$type = "Live";
	} else {
		$type = "Quick";

		&execution("$ssh_prefix $ownhost_ip Powershell Get-ClusterGroup");
		foreach (@lines) {
			if (/$vm_name\s+(\S+)\s+(\S+)/) {
				$vm_owner = $1;
				$vm_state = $2;
			}
		}
		if ($vm_state eq "Failed") {
			if (&execution("$ssh_prefix $ownhost_ip Powershell \"Stop-ClusterResource -Name 'Virtual Machine $vm_name'\"")) {
				&Log("[E][VmMigration] [$vm_name] failed to stop.\n");
				return 1;
			}
		}
	}

	if (&execution("$ssh_prefix $ownhost_ip Powershell \"Set-Variable ProgressPreference SilentlyContinue; Move-ClusterVirtualMachineRole -Name $vm_name -Node $ownhost -MigrationType $type\"")) {
		&Log("[E][VmMigration] [$vm_name] $type migration failed.\n");
		
		# Sometimes it takes long time to stop the target VM when an opposite host shutdown.
		# In such situation, the target VM's state is "Online".
		# Retry a migration with type "Live".
		if ($type eq "Quick") {
			$type = "Live";
			if (&execution("$ssh_prefix $ownhost_ip Powershell \"Set-Variable ProgressPreference SilentlyContinue; Move-ClusterVirtualMachineRole -Name $vm_name -Node $ownhost -MigrationType $type\"")) {
				&Log("[E][VmMigration] [$vm_name] $type migration failed.\n");
				return 1;
			}
			return 0;
		}

		return 1;
	}
	return 0;
}
#--------------------------------------------------------------
sub VmPowerOn {
	# Assuming the situation where the VM is failed state and its owner is this machine.
	# This situation occurs sometimes under Host OS shutdown test.
	&execution("$ssh_prefix $ownhost_ip Powershell Get-ClusterGroup");
	foreach (@lines) {
		if (/$vm_name\s+(\S+)\s+(\S+)/) {
			$vm_state = $2;
		}
	}
	if ($vm_state eq "Failed") {
		if (&execution("$ssh_prefix $ownhost_ip Powershell \"Stop-ClusterResource -Name 'Virtual Machine $vm_name'\"")) {
			&Log("[E][VmPowerOn] [$vm_name] failed to stop.\n");
			return 1;
		}
	}

	# Start VM
	if (&execution("$ssh_prefix $ownhost_ip Powershell \"Set-Variable ProgressPreference SilentlyContinue; Start-VM $vm_name\"")) {
		# Countermeasure for the case "shutting down active node".
		# In the case, the target VM migrate to the standby node,
		# --> the VM get to the PausedCritical state due to inactivation and activation of the MD
		# --> the VM get to the Running state after the VHD is repaired.
		&execution("clplogcmd -l WARN -m \"Start-VM failed to start [$vm_name]. Wait for the Running state.\"");
		while ( 1 ) {
			if (&execution("$ssh_prefix $ownhost_ip Powershell \"(Get-VM $vm_name).state\"")) {
				&Log("[E][VmPowerOn] Get-VM failed\n"); 
				return 1;
			}
			chop $lines[0];
			$vm_state = $lines[0];
			&Log("[D][VmPowerOn] VM state = [$vm_state]\n"); 
			if ($vm_state eq "Running") { last; }
			elsif ($vm_state eq "Off") {
				if (($vm_state_last eq "OffCritical") or (3 == ++$cntOff)) {
					if (&execution("$ssh_prefix $ownhost_ip Powershell \"Set-Variable ProgressPreference SilentlyContinue; Start-VM $vm_name\"")) {
						&Log("[E][VmPowerOn] Get-VM failed.\n"); 
						return 1;
					}
				}
			}
			$vm_state_last = $vm_state;
			sleep $interval;
		}
		&execution("clplogcmd -l INFO -m \"[$vm_name] became the Running state.\"");
	}
	return 0;
}
#--------------------------------------------------------------
sub execution {
	my $cmd = shift;
	&Log("[I][execution] $cmd\n");
	open(my $h, "$cmd 2>&1 |") or die "[E] execution [$cmd] failed [$!]";
	@lines = <$h>;
	foreach (@lines) {
		chomp;
		&Log("[D] | $_\n");
	}
	close($h);
	&Log(sprintf("[D] \tresult ![%d] ?[%d] >> 8 = [%d]\n", $!, $?, $? >> 8));
	return $?;
}
#--------------------------------------------------------------
sub Log {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
	print "$date $_[0]";
	return 0;
}
