package Pisg::Parser::Format::grufti;

use strict;
$^W = 1;

my $normalline = '^\[(\d+):\d+\] <([^>]+)> (.*)';
my $actionline = '^\[(\d+):\d+\] \* (\S+) (.*)';
my $thirdline  = '^\[(\d+):(\d+)\] (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)(.*)';

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
	if (defined $9) {
	    $debug->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7 $8 $9");
	} else {
	    $debug->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7 $8");
	}

	$hash{hour} = $1;
	$hash{min}  = $2;
	$hash{nick} = $3;

	if ($5 eq 'kicked') {
	    $hash{kicker} = $3;
	    $hash{nick} = $6;

	} elsif (($4.$5) eq 'haschanged') {
	    $hash{newtopic} = $9;

	} elsif (($4.$5) eq 'modechange') {
	    $hash{newmode} = substr($6, 1);
	    $hash{nick} = $9;
	    $hash{nick} =~ /.*[by ](\S+)/;
	    $hash{nick} = $1;

	} elsif ($5 eq 'joined') {
	    $hash{newjoin} = $1;

	} elsif (($3.$4) eq 'Nickchange') {
	    $hash{nick} = $7;
	    $hash{newnick} = $9;
	}

	return \%hash;

    } else {
	return;
    }
}

1;
