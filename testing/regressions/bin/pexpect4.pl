#!/usr/bin/env perl

use strict;
BEGIN {
use open "IN" => ":perlio", "OUT" => ":perlio";
};

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
use IPC::Run qw(start timer binary);
use Text::ParseWords;

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

open(OUT, ">$opts->{outfile}") || die "Couldn't open $opts->{outfile} to save command stdout: $!\n";
open(ERR, ">$opts->{errfile}") || die "Couldn't open $opts->{errfile} to save command stderr: $!\n";
binmode(OUT);
binmode(ERR);

# my @cmd = split(' ', $opts->{command}); # this is not correct in the long run
# my @cmd = ('C:\\Strawberry\\perl\\bin\\perl.exe', '..\\..\\..\\swaks.pl', '--to', 'FOO', '-au', 'user', '--dump', 'AUTH');
my @cmd = mshellwords($opts->{command});
my($in, $out, $err, $run);
eval {
	$run = start \@cmd, \$in, \$out, \$err, timer(1);
	shift(@cmd) if ($cmd[0] eq 'perl');
    print OUT "spawn ", join(' ', @cmd), "\r\n";

	my $wait  = 10; # seconds max
	my $start = time();
print STDOUT "HERE!\n";
	while (time() < $start + $wait) {
		if (!length($out) && !length($err)) {
print STDOUT "HERE 1!\n";
			$run->pump();
print STDOUT "HERE 2!\n";
		}
		# We make sure the output uses \r\n because that's what expect did, and it matches what is happening on windows anyway.
		# Annoyingly, it looks like expect changed \n into \r\n unconditionally, so we need to do the same thing.
		# $out =~ s%(^|[^\r])\n%$1\r\n%g;
		$out =~ s%\n%\r\n%g;
print STDOUT $out;
		print OUT $out;
		$err =~ s%\n%\r\n%g;
		print ERR $err;
		$in = '';
		foreach my $expect (keys(%strings)) {
			if ($out =~ /$expect/) {
				$in .= "$strings{$expect}\n";
				print OUT "$strings{$expect}\r\n";
			}
		}
		$out = $err = '';
		while (length($in)) {
			$run->pump();
		}
	}
};

if ($run) {
	$run->finish();
}

close(OUT);
close(ERR);

exit;

sub mshellwords {
	my $line = shift;
	my @return = ();

	if ($^O eq 'MSWin32') {
		$line =~ s/\\/::BACKSLASH::/g;
		foreach my $part (shellwords($line)) {
			$part =~ s/::BACKSLASH::/\\/g;
			push(@return, $part);
		}
	}
	else {
		@return = shellwords($line);
	}

	map { s/\%QUOTE_DOUBLE\%/"/g; s/\%QUOTE_SINGLE\%/'/g; } (@return);

	return @return;
}
