package Pisg::Parser::Format::xchat;

use strict;
$^W = 1;

sub new
{
    my $type = shift;
    my $self = {
        debug => $_[0],
        normalline => '^(\d+):\d+:\d+ <([^>]+)>\s+(.*)',
        actionline => '^(\d+):\d+:\d+ \*\s+(\S+) (.*)',
        thirdline  => '^(\d+):(\d+):\d+ .--\s+(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    # Parse a normal line - returns a hash with 'hour', 'nick' and 'saying'
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/) {
	$self->{debug}->("[$lines] Normal: $1 $2 $3");

	$hash{hour} = $1;
	$hash{nick} = $2;
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

    if ($line =~ /$self->{actionline}/) {
	$self->{debug}->("[$lines] Action: $1 $2 $3");

	$hash{hour} = $1;
	$hash{nick} = $2;
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

    if ($line =~ /$self->{thirdline}/) {
	$self->{debug}->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7 $8 $9");

	$hash{hour} = $1;
	$hash{min} = $2;
	$hash{nick} = $3;

	if (($4.$5) eq 'haskicked') {
	    $hash{kicker} = $3;
	    $hash{nick} = $6;

	} elsif (($4.$5) eq 'haschanged') {
	    $hash{newtopic} = $9;

	} elsif (($4.$5) eq 'giveschannel') {
	    $hash{newmode} = '+o';

	} elsif (($4.$5) eq 'removeschannel') {
	    $hash{newmode} = '-o';

	} elsif (($5.$6) eq 'hasjoined') {
	    $hash{newjoin} = $1;

	} elsif (($5.$6) eq 'nowknown') {
	    $hash{newnick} = $8;
	}

	return \%hash;

    } else {
	return;
    }
}

1;
