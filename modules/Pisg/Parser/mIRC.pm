package Pisg::Parser::mIRC;

use strict;
$^W = 1;

my $normalline = '^\[(\d+):\d+\] <([^>]+)> (.*)';
my $actionline = '^\[(\d+):\d+\] \* (\S+) (.*)';
my $thirdline  = '^\[(\d+):(\d+)\] \*\*\* (\S+) (\S+) (\S+) (\S+) (\S+)(.*)';

my ($debug);


sub new
{
    my $self = shift;
    $debug = shift;
    return bless {};
}

sub normalline
{
    # Parse a normal line - returns a hash with 'hour', 'nick' and 'saying'
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$normalline/) {
	$debug->("[$lines] Normal: $1 $2 $3");

	$hash{hour}   = $1;
	$hash{nick}   = $2;
	$hash{saying} = $3;

	return \%hash;
    } else {
	return;
    }
}

sub actionline
{
    # Parse an action line - returns a hash with 'hour', 'nick' and 'saying'
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$actionline/) {
	$debug->("[$lines] Action: $1 $2 $3");

	$hash{hour}   = $1;
	$hash{nick}   = $2;
	$hash{saying} = $3;

	return \%hash;
    } else {
	return;
    }
}

sub thirdline
{
    # Parses the 'third' line - (the third line is everything else, like
    # topic changes, mode changes, kicks, etc.)
    # thirdline() have to return a hash with the following keys, for
    # every format:
    #   hour            - the hour we're in (for timestamp loggin)
    #   min             - the minute we're in (for timestamp loggin)
    #   nick            - the nick
    #   kicker          - the nick which were kicked (if any)
    #   newtopic        - the new topic (if any)
    #   newmode         - deops or ops, must be '+o' or '-o', or '+ooo'
    #   newjoin         - a new nick which has joined the channel
    #   newnick         - a person has changed nick and this is the new nick
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$thirdline/) {
	if (defined $8) {
	    $debug->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7 $8");
	} else {
	    $debug->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7");
	}

	$hash{hour} = $1;
	$hash{min}  = $2;
	$hash{nick} = $3;

	if (($4.$5) eq 'waskicked') {
	    $hash{kicker} = $7;

	} elsif (($4.$5) eq 'changes') {
	    $hash{newtopic} = "$7 $8";

	} elsif (($4.$5) eq 'setsmode:') {
	    $hash{newmode} = $6;

	} elsif (($4.$5) eq 'hasjoined') {
	    $hash{newjoin} = $3;

	} elsif (($4.$5) eq 'nowknown') {
	    $hash{newnick} = $8;
	}

	return \%hash;

    } else {
	return;
    }
}

1;
