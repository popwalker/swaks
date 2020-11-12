#!/usr/bin/env perl

use strict;

my $foo =<<'EOM';
./pexpect.pl \
  --outfile out.file \
  --errfile err.file \
  --command   "../../../swaks --to FOO -au user --dump AUTH" \
  --expect "Password:" \
  --send "TPASS"

pexpect2.pl --outfile out.file --errfile err.file --command   "..\..\..\swaks.pl --to FOO -au user --dump AUTH" --expect "Password:" --send "TPASS"
EOM

use Data::Dumper;
use Getopt::Long;
# use IO::Select;
use IPC::Run qw(start timer);

my $opts = {};
GetOptions($opts, 'command=s', 'outfile=s', 'errfile=s', 'expect=s@', 'send=s@') || die "Couldn't understand options\n";

my @expect = exists($opts->{expect}) ? @{$opts->{expect}} : ();
my @send   = exists($opts->{send})   ? @{$opts->{send}}   : ();
if (scalar(@expect) != scalar(@send)) {
	die "There must be an equal number of expect and send arguments\n";
}
if (!exists($opts->{outfile})) {
	die "required option --outfile not given\n";
}
if (!exists($opts->{errfile})) {
	die "required option --errfile not given\n";
}
if (!exists($opts->{command})) {
	die "required option --command not given\n";
}

my %strings = ();
foreach my $expect (@expect) {
	$strings{$expect} = shift(@send);
}

open(OUT, ">$opts->{outfile}");
open(ERR, ">$opts->{errfile}");

my @cmd = split(' ', $opts->{command}); # this is not correct in the long run
my @cmd = ('C:\\Strawberry\\perl\\bin\\perl.exe', '..\\..\\..\\swaks.pl', '--to', 'FOO', '-au', 'user', '--dump', 'AUTH');
my($in, $out, $err);
my $run;
eval {
	$run = start \@cmd, \$in, \$out, \$err, timer(1);

	my $wait  = 10; # seconds max
	my $start = time();
	while (time() < $start + $wait) {
		if (!length($out) && !length($err)) {
			$run->pump();
		}
		print OUT $out;
		print ERR $err;
		$in = '';
		foreach my $expect (keys(%strings)) {
			if ($out =~ /$expect/) {
				$in .= "$strings{$expect}\n";
				print OUT "$strings{$expect}\n";
			}
		}
		$out = $err = '';
		while (length($in)) {
			$run->pump();
		}
	}
	# $run->finish();
};

if ($run) {
	$run->finish();
}

close(OUT);
close(ERR);

exit;





my $bar =<<'EOM';


# my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym,
#                 'some', 'cmd', 'and', 'args');
# # or pass the command through the shell
$pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym, $opts->{command});
binmode($chld_out);
binmode($chld_err);
select((select($chld_in), $| = 1)[0]);


my $select = IO::Select->new();
$select->add($chld_out);
$select->add($chld_err);

my $wait  = 10; # seconds max
my $start = time();
print "starting loop\n";
while(my @ready = $select->can_read(1)) {
	print STDERR "read (select)\n";
	foreach my $fh (@ready) {
		print STDERR "read (fh)\n";
		# 10000 is kind of random.  Would be nice to read it all in one bite.  Might have to revisit and take multiple bites
		my $buff = '';
		my $ret  = sysread($fh, $buff, 10000);
		if ($fh == $chld_err) {
			print ERR $buff;
		}
		else {
			foreach my $expect (keys(%strings)) {
				if ($buff =~ /$expect/) {
					print $chld_in "$strings{$expect}\n";
				}
			}
			print OUT $buff;
		}
	}
	last if (time() > $start + $wait);
}

waitpid( $pid, 0 );

close(OUT);
close(ERR);
EOM
