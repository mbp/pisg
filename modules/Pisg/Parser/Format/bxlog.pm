package Pisg::Parser::Format::bxlog;

use strict;
$^W = 1;

sub new
{
    my $type = shift;
    my $self = {
        debug => $_[0],
        normalline => '^\[\d+ \S+\/(\d+):\d+\] <([^>]+)> (.*)',
        actionline => '^\[\d+ \S+\/(\d+):\d+\] \* (\S+) (.*)',
        thirdline => '^\[\d+ \S+\/(\d+):(\d+)\] ([<>@!]) (.*)'
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

    if ($line =~ /$self->{actionline}/) {
	$self->{debug}->("[$lines] Action: $1 $2 $3");

	$hash{hour}    = $1;
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

    if ($line =~ /$self->{thirdline}/) {
	$self->{debug}->("[$lines] ***: $1 $2 $3 $4");

	$hash{hour} = $1;
	$hash{min}  = $2;

	if ($3 eq '<') {
	    if  ($4 =~ /^([^!]+)!\S+ was kicked off \S+ by ([^!]+)!/) {
		$hash{kicker} = $2;
		$hash{nick} = $1;
	    }

	} elsif ($3 eq '>') {
	    if ($4 =~ /^([^!])+!\S+ has joined \S+$/) {
		$hash{nick} = $1;
		$hash{newjoin} = $1;
	    }

	} elsif ($3 eq '@') {
	    if ($4 =~ /^Topic by ([^!:])[!:]*: (.*)$/) {
		$hash{nick} = $1;
		$hash{newtopic} = $2;

	    } elsif ($4 =~ /^mode \S+ \[([\S]+) [^\]]+\] by ([^!]+)!\S+$/) {
		$hash{newmode} = $1;
		$hash{nick} = $2;
	    }

	} elsif ($3 eq '!') {
	    if ($4 =~ /^(\S+) is known as (\S+)$/) {
		$hash{nick} = $1;
		$hash{newnick} = $2;
	    }
	}

	return \%hash;

    } else {
	return;
    }
}

1;
