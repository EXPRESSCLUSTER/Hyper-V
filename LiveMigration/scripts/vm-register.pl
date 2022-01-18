#!/usr/bin/perl -w
#
# Script for start the Virtual Machine Configuration resource
# and Cluster Shared Volume
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
# Global values
my $vm_name = "";
my $cmd = "";
my @lines = ();
my $ssh_prefix = "ssh -i ~/.ssh/id_rsa -l $wsfc_account\@$wsfc_domain";
my $vm_state = "";
my $vm_owner = "";
my $csv_state = "";
my $csv_owner = "";
my $ownhost_ip = "";
my $opphost_ip = "";
my $ownhost = "";
my $opphost = "";
my $ownhost_state = "";
my $opphost_state = "";

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
sub CsvMove {
	# No error if the csv is already online on the destination server.
	if (&execution("$ssh_prefix $ownhost_ip Powershell \"Move-ClusterSharedVolume -Name '$csv_name' -Node $ownhost\"")) {
		&Log("[E][CsvMove] CSV failed to move.\n");
		return 1;
	}
	return 0;
}
#--------------------------------------------------------------
sub CsvStart {
	# No error if the csv is already online on the destination server.
	if (&execution("$ssh_prefix $ownhost_ip Powershell \"Start-ClusterResource -Name '$csv_name'\"")) {
		&Log("[E][CsvStart] CSV failed to start.\n");
		return 1;
	}
	return 0;
}
#--------------------------------------------------------------
sub VmConfigStart {
	# No error if the resource is already online on the destination server.
	if (&execution("$ssh_prefix $ownhost_ip Powershell \"Start-ClusterResource 'Virtual Machine Configuration $vm_name'\"")) {
		&Log("[E][VmConfigStart] [$vm_name] failed to start.\n");
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