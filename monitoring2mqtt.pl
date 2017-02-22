#!/usr/bin/perl -w -I.

use strict;
use Nagios::Plugin::Performance;
use JSON;
use Net::MQTT::Simple "localhost";

my $host = '';
my %checks;

open(IN, "<monitoring2mqtt.conf") || die "Can't read from config file.";
while (<IN>) {
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
	my %res;
	$res{'host'} = $host;
	$res{'check'} = $check;
	$res{'raw'} = `$cmd`;
	$res{'ret'} = ($? >> 8);
	chomp($res{'raw'});
	if ($res{'raw'} =~ /\|/) {
		$res{'out'} = $`;
		my @perf = Nagios::Plugin::Performance->parse_perfstring($');
		my @metrics = ();
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
			push(@metrics, \%metric_hash);
		}
		$res{'metrics'} = \@metrics;
	} else {
		$res{'out'} = $res{'raw'};
	}
	$res{'last'} = time();
	publish "/host/$host/$check" => encode_json(\%res);
}
close(IN);
