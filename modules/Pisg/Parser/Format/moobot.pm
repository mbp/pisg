package Pisg::Parser::Format::moobot;

use strict;
$^W = 1;


sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\d{4}-\d{2}-\d{2} (\d{2}):\d{2}:\d{2} :([^! ]+)(?:![^ ]+)? PUBMSG ([^ ]+) :(.*)',
        actionline => '^\d{4}-\d{2}-\d{2} (\d{2}):\d{2}:\d{2} :([^! ]+)(?:![^ ]+)? CTCP ([^ ]+) :ACTION (.*)',
        thirdline  => '^\d{4}-\d{2}-\d{2} (\d{2}):(\d{2}):\d{2} :([^! ]+)(?:![^ ]+)? ([^ ]+) :?([^ ]+) ?(.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o and
	lc($3) eq lc($self->{cfg}->{channel})) {

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $4;

        return \%hash;
    } else {
        return;
    }
}

sub actionline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o and
	lc($3) eq lc($self->{cfg}->{channel})) {

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $4;

        return \%hash;
    } else {
        return;
    }
}

sub thirdline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o and
	lc($5) eq ($self->{cfg}->{channel})) {

	my $args = $6;

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $3;

	if ($4 eq "KICK") {
	    $hash{kicker} = $3;
	    $args =~ /^([^ ]+)/;
	    $hash{nick} = $1;

	} elsif ($4 eq "TOPIC") {
	    $args =~ s/^://;
	    $hash{newtopic} = $args;

	} elsif ($4 eq "MODE") {
	    $hash{newmode} = $args;

	} elsif ($4 eq "JOIN") {
	    $hash{newjoin} = $3;
	}

        return \%hash;

    # Nick changes do not have an associated channel.
    } elsif ($line =~ /$self->{thirdline}/o and
	     $4 eq "NICK") {
	
        $hash{hour}    = $1;
        $hash{min}     = $2;
        $hash{nick}    = $3;
	$hash{newnick} = $5;

        return \%hash;

    } else {
        return;
    }
}

1;
