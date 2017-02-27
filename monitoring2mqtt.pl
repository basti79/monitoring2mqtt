#!/usr/bin/perl -w -I.

use strict;
use POSIX ":sys_wait_h";
use Fcntl qw(:flock);
use File::Slurp;
use Nagios::Plugin::Performance;
use JSON;
use Net::MQTT::Simple "localhost";

my $fh;
my $host = '';
my %checks;
my $chcnt = 0;
my %childs;
my $maxch = 10;

$SIG{CHLD} = sub {
	while ((my $chpid = waitpid(-1, &WNOHANG)) > 0) {
		my $x=$?;
		my %res;
		$res{'ret'} = ($x >> 8);
		$res{'host'} = $childs{$chpid};
		$res{'host'} =~ s/\|.*$//;
		$res{'check'} = $childs{$chpid};
		$res{'check'} =~ s/^.*\|//;
		$res{'raw'} = read_file("output.$chpid");
		unlink("output.$chpid");
		if ($res{'raw'} =~ /\|/) {
			$res{'out'} = $`;
			my @perf = Nagios::Plugin::Performance->parse_perfstring($');
			my %metrics;
			for my $p (@perf) {
				my %metric_hash = (
				    'label'    => $p->label,
				    'value'    => $p->value,
				    'uom'      => $p->uom,
				    'warning'  => $p->warning,
				    'critical' => $p->critical,
				    'min'      => $p->min,
				    'max'      => $p->max
				);
				$metrics{$p->label} = \%metric_hash;
			}
			$res{'metrics'} = \%metrics;
		} else {
			$res{'out'} = $res{'raw'};
		}
		$res{'last'} = time();
		publish "/host/$res{'host'}/$res{'check'}" => encode_json(\%res);
		$chcnt--;
	}
};

open($fh, "<monitoring2mqtt.conf") || die "Can't read from config file.";
flock($fh, LOCK_EX|LOCK_NB) || die "Unable to lock file $!";
while (<$fh>) {
	next if /^\s*$/;
	if (/^\s*\[(.*)\]\s*$/) {
		$host = $1;
		next;
	}
	if ($host eq '') {
		/^\s*(\S+)\s+(.*)$/;
		$checks{$1} = $2;
		next;
	}
	my $check;
	my $cmd;
	if (/^\s*(\S+)\s*$/) {
		$check = $1;
		if (!exists($checks{$check})) {
			die "Default command for '$check' not defined.";
		}
		$cmd = $checks{$check};
	} else {
		/^\s*(\S+)\s+(.*)$/;
		$check=$1;
		$cmd=$2;
	}
	$cmd =~ s/\%HOST\%/$host/g;
	my $chpid=fork();
	if ($chpid==0) {
		close($fh);
		exec("$cmd >output.$$");
		exit(255);
	} else {
		$chcnt++;
		$childs{$chpid} = "$host|$check";
		sleep(1) while ($chcnt >= $maxch);
	}
}

sleep(1) while ($chcnt > 0);

close($fh);
