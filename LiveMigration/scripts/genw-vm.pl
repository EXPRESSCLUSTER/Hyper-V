#!/usr/bin/perl -w
#
# Script to monitor the Virtual Machine
#
use strict;
#--------------------------------------------------------------
# Configuration
#--------------------------------------------------------------
# The VM name displayed in Hyper-V Manager Virtual Machines list.
my @vm_names = (
	'Cent8.2-1'
);

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
my $vm_status = "";
my $vm_config_state = "";
my $ownhost_ip = "";
my $opphost_ip = "";

my $tmp = `ip address | grep $ec1/`;
if ($? == 0) {
	$ownhost_ip = $host1_ip;
	$opphost_ip = $host2_ip;
} else {
	$tmp = `ip address | grep $ec2/`;
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
	if (&VmMonitor()) {
		$r = 1;
	}
}
exit $r;
#--------------------------------------------------------------
# Functions
#--------------------------------------------------------------
sub VmMonitor {
	if (&execution("$ssh_prefix $ownhost_ip Powershell \"(Get-VM -Name '$vm_name').Status\"")) {
		&Log("[E][VmMonitor] [$vm_name] was not found.\n");
		return 1;
	}
	foreach (@lines) {
		if (/((\S+)\s+(\S+))/) {
			$vm_status = $1;
		}
	}
	if ($vm_status ne "Operating normally") {
		&Log("[E][VmMonitor] Hyper-V could not get a heartbeat from [$vm_name].\n");
		return 1;
	}

	if (&execution("$ssh_prefix $ownhost_ip Powershell \"(Get-VM -Name '$vm_name').State\"")) {
		&Log("[E][VmMonitor] [$vm_name] was not found.\n");
		return 1;
	}
	foreach (@lines) {
		if (/(\S+)\s+.*/) {
			$vm_state = $1;
		}
	}
	if ($vm_state ne "Running") {
		&Log("[E][VmMonitor] [$vm_name] is not running.\n");
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
