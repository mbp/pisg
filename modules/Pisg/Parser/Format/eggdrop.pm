package Pisg::Parser::Format::eggdrop;

use strict;
$^W = 1;
 
sub new
{
    my $type = shift;
    my $self = {
        debug => $_[0],
        normalline => '^\[(\d+):\d+\] <([^>]+)> (.*)',
        actionline => '^\[(\d+):\d+\] Action: (\S+) (.*)',
        thirdline  => '^\[(\d+):(\d+)\] (\S+) (\S+) (\S+) (\S+)(.*)',
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
    #
    # The hash my also have a "repeated" key indicating the number of times
    # the line was repeated.
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/) {
	if (defined $7) {
	    $self->{debug}->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7");
	} else {
	    $self->{debug}->("[$lines] ***: $1 $2 $3 $4 $5 $6");
	}

	$hash{hour} = $1;
	$hash{min}  = $2;
	$hash{nick} = $3;

	if (($4.$5) eq 'kickedfrom') {
	    $7 =~ /^ by ([\S]+):.*/;
	    $hash{kicker} = $1;

	} elsif ($3 eq 'Topic') {
	    $7 =~ /^ by ([\S]+)![\S]+: (.*)/;
	    $hash{nick} = $1;
	    $hash{newtopic} = $2;

	} elsif (($4.$5) eq 'modechange') {
	    my $newmode = $6;
	    if ($7 =~ /^ .+ by ([\S]+)!.*/) {
		$hash{nick} = $1;
		$newmode =~ s/^\'//;
		$hash{newmode} = $newmode;
	    }

	} elsif ($5 eq 'joined') {
	    $hash{newjoin} = $3;

	} elsif (($3.$4) eq 'Nickchange:') {
	    $hash{nick} = $5;
	    $7 =~ /([\S]+)/;
	    $hash{newnick} = $1;

	} elsif (($3.$4.$5) eq 'Lastmessagerepeated') {
	    $hash{repeated} = $6;
	}

	return \%hash;

    } else {
	return;
    }
}

1;
