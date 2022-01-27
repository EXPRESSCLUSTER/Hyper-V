#!/usr/bin/perl -w
#
# Script to stop the Virtual Machine
#
use strict;
#--------------------------------------------------------------
# Configuration
#--------------------------------------------------------------
# The VM name displayed in Hyper-V Manager Virtual Machines list.
my @vm_names = (
'Cent8.2-1'
);

my $csv_name = 'Cluster Disk 1';

# The IP address of Hyper-V host servers
my $host1_ip = "192.168.137.196";
my $host2_ip = "192.168.137.197";

# The IP address of EC VMs
my $ec1 = "192.168.137.199";
my $ec2 = "192.168.137.200";

# The account and domain name used to control WSFC.
my $wsfc_account = "Administrator";
my $wsfc_domain = "2016dom.local";
#--------------------------------------------------------------
# The check interval for VM, VM Configuration, CSV status. (second)
my $interval = 6;
# The maximum count to check a status.
my $max_cnt = 50;
#--------------------------------------------------------------
# Global values
my $vm_name = "";
my $cmd = "";
my @lines = ();
my $ssh_prefix = "ssh -i ~/.ssh/id_rsa -l $wsfc_account\@$wsfc_domain";
my $csv_state = "";
my $csv_owner = "";
my $vm_state = "";
my $ownhost_ip = "";
my $opphost_ip = "";
my $clp_factor = $ENV{CLP_FACTOR};

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

	if ($clp_factor eq "GROUPMOVE") {
		&Log("[I] Nothing to do. Live migration will be executed in vm-start.pl.\n");
		exit 0;
	}

	if (&VmPowerOff()) {
		$r = 1;
		next;
	}

	if (&WaitVmPowerOff) {
		$r = 1;
		next;
	}

	if (&VmConfigStop) {
		$r = 1;
		next;
	}

	if (&CsvStop()) {
		$r = 1;
		next;
	}
}
exit $r;
#--------------------------------------------------------------
# Functions
#--------------------------------------------------------------
sub VmPowerOff {
	if (&execution("$ssh_prefix $ownhost_ip Powershell \"Set-Variable ProgressPreference SilentlyContinue; Stop-VM $vm_name -Force\"")) {
		&Log("[E][VmPowerOff] [$vm_name] failed to stop.\n");
		return 1;
	}
	return 0;
}
#--------------------------------------------------------------
sub WaitVmPowerOff {
	for (my $i = 0; $i < $max_cnt; $i++){
		&execution("$ssh_prefix $ownhost_ip Powershell Get-ClusterGroup");
		foreach (@lines) {
			if (/$vm_name\s+(\S+)\s+(\S+)/) {
				$vm_state = $2;
			}
		}

		if ($vm_state eq "Offline") {
			return 0;
		}

		&Log("[I][WaitVmPowerOff] [$vm_name] waiting power off. (cnt=$i)\n");
		sleep $interval;
	}

	&Log("[E][WaitVmPowerOff] [$vm_name] powered off not completed. (cnt=$max_cnt)\n");
	return 1;
}
#--------------------------------------------------------------
sub VmConfigStop {
	# No error if the resource is already offline on the destination server.
	if (&execution("$ssh_prefix $ownhost_ip Powershell \"Stop-ClusterResource 'Virtual Machine Configuration $vm_name'\"")) {
		&Log("[E][VmConfigStop] Configuration [$vm_name] failed to stop.\n");
		return 1;
	}
	return 0;
}
#--------------------------------------------------------------
sub CsvStop {
	# No error if the csv is already offline on the destination server.
	if (&execution("$ssh_prefix $ownhost_ip Powershell \"Stop-ClusterResource -Name '$csv_name'\"")) {
		&Log("[E][CsvStop] CSV failed to stop.\n");
		return 1;
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