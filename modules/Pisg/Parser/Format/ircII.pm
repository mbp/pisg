package Pisg::Parser::Format::ircII;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm
# Parser for logs from ircII
# by James Andrewartha <trs80@tartarus.uwa.edu.au>
# based on Template.pm and Trillian.pm

# Note that you will need some triggers similar to these in your .ircrc to get
# timestamping:
# on #^timer 50 "*0" echo $0
# on #^timer 50 "*5" echo $0

# Known issues: the time of topic changes is only as accurate as the time-
# stamping (the above lines provide 5-minute accuracy).

use strict;
$^W = 1;

# Yes, global variables are bad. But they do need to be global to avoid pain.
my ($global_hour, $global_minute);

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^(<([^>]+)> (.*)|> (.*))',
        actionline => '^\* (\S+[^>]) (.*)',
        thirdline  => '^((\d+):(\d+)|\*{3} (.+)|IRC log started \w+ \w+ \w+ (\d+:\d+))',
    };

    bless($self, $type);
    return $self;
}

# Parse a normal line - returns a hash with 'hour', 'nick' and 'saying'
sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {
        $hash{hour}   = $global_hour;

        if ($1 =~ /^<([^>]+)> (.*)/) {
            $hash{nick}   = $1;
            $hash{saying} = $2;
        } elsif ($1 =~ /^> (.*)/) {
            $hash{nick} = $self->{cfg}->{maintainer};
            $hash{saying} = $1;
        }

        return \%hash;
    } else {
        return;
    }
}

# Parse an action line - returns a hash with 'hour', 'nick' and 'saying'
sub actionline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o) {

        $hash{hour}   = $global_hour;
        $hash{nick}   = $1;
        $hash{saying} = $2;

        return \%hash;
    } else {
        return;
    }
}

sub thirdline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

	    # Mainly stolen from Trillian.pm
        if ($1 =~ /^\*{3} (\S+) has been kicked off channel (\S+) by (\S+) .+/) {
            $hash{nick} = $1;
            $hash{kicker} = $3;

        } elsif ($1 =~ /^\*{3} (\S+) has changed the topic on channel (\S+) to (.+)/) {
             $hash{nick} = $1;
             $hash{newtopic} = $3;

        } elsif ($1 =~ /^\*{3} Mode change \"(\S+)[^\"]+\".+ by (.+)$/) {
             $hash{nick} = $2;
             $hash{newmode} = $1;

        } elsif ($1 =~ /^\*{3} (\S+) \S+ has joined channel \S+/) {
            $hash{nick} = $1;
            $hash{newjoin} = $1;

        } elsif ($1 =~ /^\*{3} (\S+) is now known as (\S+)/) {
            $hash{nick} = $1;
            $hash{newnick} = $2;

        } elsif ($1 =~ /^(\d+):(\d+)$/) {
            $global_hour = $1;
            $global_minute = $2;

        } elsif ($1 =~ /^IRC log started \w+ \w+ \w+ (\d+):(\d+)/) {
            $global_hour = $1;
            $global_minute = $2;
        }

        $hash{hour} = $global_hour;
        $hash{min}  = $global_minute;

        return \%hash;

    } else {
        return;
    }
}

1;
