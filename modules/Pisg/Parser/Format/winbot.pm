package Pisg::Parser::Format::winbot;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^(\d\d):\d\d\.\d\d \d+\/\d+\/\d+  <([^\/]+)\/([^\>]+)> (.*)',
        actionline => '^(\d\d):\d\d\.\d\d \d+\/\d+\/\d+  \* ([^\/]+)\/(\S+) (.*)',
        thirdline  => '^(\d\d):(\d\d)\.\d\d \d+\/\d+\/\d+  \*{3}\s(.+)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o && lc($3) eq lc($self->{cfg}->{channel})) {

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $4;

        return \%hash;
    }
    return;
}

sub actionline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o && lc($3) eq lc($self->{cfg}->{channel})) {

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $4;

        return \%hash;
    }
    return;
}

sub thirdline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $3;

        if ($3 =~ /^(\S+) was kicked from (\S+) by (\S+) .+/) {
            if (lc($2) eq lc($self->{cfg}->{channel})) {
                $hash{nick} = $1;
                $hash{kicker} = $3;
            }

        } elsif ($3 =~ /^([^\/]+)\/(\S+) changes topic to \"(.+)\"[^\"]*$/) {
            if (lc($2) eq lc($self->{cfg}->{channel})) {
                $hash{nick} = $1;
                $hash{newtopic} = $3;
            }

        } elsif ($3 =~ /^([^\/]+)\/(\S+) sets mode: (\S+) [^\)]+/) {
            if (lc($2) eq lc($self->{cfg}->{channel})) {
                $hash{nick} = $1;
                $hash{newmode} = $3;
            }

        } elsif ($3 =~ /^(\S+) has joined (\S+)/) {
            if (lc($2) eq lc($self->{cfg}->{channel})) {
                $hash{nick} = $1;
                $hash{newjoin} = $1;
            }

        } elsif ($3 =~ /^(\S+) is now known as (\S+)/) {
            $hash{nick} = $1;
            $hash{newnick} = $2;

        } elsif ($3 =~ /^(\S+) /) {
            $hash{nick} = $1;

        }

        return \%hash;

    } else {
        return;
    }
}

1;
