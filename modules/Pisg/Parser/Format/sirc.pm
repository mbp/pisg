package Pisg::Parser::Format::sirc;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm
# parser for logs from sirc
# based on module by bartko <bartek09@netscape.net>

# the timestamps are needed for statistics generation
# for timestamping use the timestep script for sirc
# included in scripts/sirc-timestamp.pl

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '(\d+):\d+ <([^>\s]+)>\s+(.*)',
        actionline => '(\d+):\d+ \* (\S+) (.*)',
        thirdline  => '(\d+):(\d+) \*(.)\* (.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {

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
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o) {

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
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

        $hash{hour} = $1;
        $hash{min} = $2;

        if ($3 eq '>') {
            if ($4 =~ /^(\S+) \S+ has joined channel \S+$/) {
                $hash{newjoin} = $1;
	        $hash{nick} = $1;
            } elsif ($4 =~ /^You have joined channel \S+$/) {
                $hash{newjoin} = $self->{cfg}->{maintainer};
	        $hash{nick} = $self->{cfg}->{maintainer};
            }

        } elsif ($3 eq '<') {
            if ($4 =~ /^(\S+) has been kicked off channel \S+ by (\S+) \((.*)\)$/) {
                $hash{kicker} = $2;
                $hash{nick} = $1;
                $hash{kicktext} = $3;
            } elsif ($4 =~ /^You have been kicked off channel \S+ by (\S+)/) {
                $hash{kicker} = $1;
                $hash{nick} = $self->{cfg}->{maintainer};
                $hash{kicktext} = $2;
            }

        } elsif ($3 eq 'T') {
            if ($4 =~ /^(\S+) has changed the topic on channel \S+ to \"(.+)\"$/) {
                $hash{newtopic} = $2;
                $hash{nick} = $1;
            } elsif ($4 =~ /^You have changed the topic on channel \S+ to \"(.+)\"$/) {
                $hash{newtopic} = $1;
                $hash{nick} = $self->{cfg}->{maintainer};
            } elsif ($4 =~ /^Topic for \S+: (.+)$/) {
                $self->{topic_temp} = $1;
            } elsif ($self->{topic_temp} && ($4 =~ /^Topic for \S+ set by ([^!]+)!\S+/)) {
                $hash{nick} = $1;
                $hash{newtopic} = $self->{topic_temp};
                delete $self->{topic_temp};
            }

        } elsif ($3 eq '+' && ($4 =~ /^Mode change \"(\S+) ([^\"]+)\" on channel \S+ by (\S+)/)) {
           $hash{newmode} = $1;
           $hash{modechanges} = $2;
	   $hash{nick} = $3;

        } elsif ($3 eq 'N' && ($4 =~ /^(S+) is now known as (S+)$/)) {
            $hash{nick} = $1;
            $hash{newnick} = $2;

        }

        return \%hash;

    } else {
        return;
    }
}

1;
