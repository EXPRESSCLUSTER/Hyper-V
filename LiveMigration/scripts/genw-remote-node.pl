#!/usr/bin/perl -w
#
# Script to monitor the opposite EC-VM
#
# If CLP is offline and EC-VM is online, then starting CLP.
# If EC-VM is offline and ESXi is online, then starting EC-VM.
#
use strict;
#--------------------------------------------------------------
# Configuration
#--------------------------------------------------------------
# The IP address of Hyper-V host servers
my $host1_ip = "192.168.137.196";
my $host2_ip = "192.168.137.197";

# The EC-VM name displayed in Hyper-V Manager Virtual Machines list.
my $ec1_name = "EC-VM1";
my $ec2_name = "EC-VM2";

# The IP address of EC VMs
my $ec1 = "192.168.137.199";
my $ec2 = "192.168.137.200";

# The account and domain name used to control WSFC.
my $wsfc_account = "Administrator";
my $wsfc_domain = "2016dom.local";
#--------------------------------------------------------------
# Global values
my $LOOPCNT	= 2;	# times
my $SLEEP	= 10;	# seconds
my $cmd = "";
my @lines = ();
my $ssh_prefix = "ssh -i ~/.ssh/id_rsa -l $wsfc_account\@$wsfc_domain";
my $vm_state = "";
my $ownhost_ip = "";
my $opphost_ip = "";
my $ownec_name = "";
my $oppec_name = "";
my $oppec_name_on_hyperv = "";
my $oppec_ip;

my $tmp = `ip address | grep $ec1`;
if ($? == 0) {
	$ownhost_ip = $host1_ip;
	$opphost_ip = $host2_ip;
	$oppec_name_on_hyperv = $ec2_name;
	$oppec_ip = $ec2;
} else {
	$tmp = `ip address | grep $ec2`;
	if ($? == 0) {
		$ownhost_ip = $host2_ip;
		$opphost_ip = $host1_ip;
		$oppec_name_on_hyperv = $ec1_name;
		$oppec_ip = $ec1;
	} else {
		&Log("[E] Invalid configuration (Management host IP could not be found).\n");
		exit 1;
	}
}

#--------------------------------------------------------------
# Main
#--------------------------------------------------------------
my $r = 0;
for (my $i = 0; $i < $LOOPCNT; $i++){
	if (!&IsRemoteClpOffline()){
		# Remote ECX is online
		#&Log("[D] remote CLP [$oppec_ip] is online\n");
		exit 0;
	}
	sleep $SLEEP;
}

&Log("[D] remote CLP [$oppec_ip] is offline\n");
if (&execution("ping $oppec_ip -c1")) {
	&Log("[D] remote VM [$oppec_ip] is offline\n");
	if (&execution("ping $opphost_ip -c1")) {
		&Log("[D] remote Hyper-V [$opphost_ip] is offline\n");
	} else {
		&Log("[D] remote Hyper-V [$opphost_ip] is online, starting VM\n");
		&EcVmPowerOn();
	}
} else {
	&Log("[D] remote VM [$oppec_name:$oppec_ip] is online, starting CLP\n");
	&execution("clpcl -s -h $oppec_name");
}

exit $r;
#--------------------------------------------------------------
# Functions
#--------------------------------------------------------------
sub IsRemoteClpOffline {
	my $stat_remote	= "";

	&execution("clpstat");
	foreach(@lines){
		chomp;
		if (/^\s{4}(\S+?)\s.*: (.+?)\s/) {
			$oppec_name = $1;
			$stat_remote = $2;
		}
		elsif (/<group>/){
			last;
		}
	}

	#&Log("[D] remote[$oppec_name:$stat_remote]\n");
	if ($stat_remote eq "Offline") {
		return 1; # TRUE
	} else {
		return 0; # FALSE
	}
}
#--------------------------------------------------------------
sub EcVmPowerOn {
	#&Log("[I] Starting [$oppec_ip][$oppec_name]\n");
	&execution("$ssh_prefix $opphost_ip Powershell \"Set-Variable ProgressPreference SilentlyContinue; Start-VM $oppec_name_on_hyperv\"");
	foreach (@lines) {
		chomp;
		&Log("[D] \t$_\n");
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