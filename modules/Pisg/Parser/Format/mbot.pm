package Pisg::Parser::mbot;

use strict;
$^T = 1;


my $normalline = '^\S+ \S+ \d+ (\d+):\d+:\d+ \d+ <([^>]+)> (?!\001ACTION)(.*)';
my $actionline = '^\S+ \S+ \d+ (\d+):\d+:\d+ \d+ <([^>]+)> \001ACTION (.*)\001$';
my $thirdline  = '^\S+ \S+ \d+ (\d+):(\d+):\d+ \d+ (\S+) (\S+) ?(\S*) ?(\S*) ?(.*)';

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
	my $debugstring = "[$lines] ***: $1 $2 $3 $4";
	$debugstring .= " $5" if (defined $5);
	$debugstring .= " $6" if (defined $6);
	$debugstring .= " $7" if (defined $7);
	$debug->($debugstring);

	$hash{hour} = $1;
	$hash{min}  = $2;
	$hash{nick} = $3;

	if ($4 eq 'KICK') {
	    $hash{kicker} = $3;
	    $hash{nick} = $5;

	} elsif ($4 eq 'TOPIC') {
	    $hash{newtopic} = $5;
	    $hash{newtopic} =~ s/^.*://;

	} elsif ($4 eq 'MODE') {
	    $hash{newmode} = $5;

	} elsif ($4 eq 'JOIN') {
	    $3 =~ /^([^!]+)!/;
	    $hash{newjoin} = $1;
	    $hash{nick} = $1;

	} elsif ($4 eq 'NICK') {
	    $hash{newnick} = $5;
	}

	return \%hash;

    } else {
	return;
    }
}

1;
