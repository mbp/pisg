package Pisg::Parser::Format::mbot;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\S+ \S+ [ \d]\d (\d+):\d+:\d+ \d+ <([^>]+)> (?!\001ACTION)(.*)',
        actionline => '^\S+ \S+ [ \d]\d (\d+):\d+:\d+ \d+ <([^>]+)> \001ACTION (.*)\001$',
        thirdline  => '^\S+ \S+ [ \d]\d (\d+):(\d+):\d+ \d+ (\S+) (\S+) ?(\S*) ?(\S*) ?(.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {

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
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o) {

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
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $3;

        if ($4 eq 'KICK') {
            $hash{kicker} = $3;
            $hash{nick} = $5;

        } elsif ($4 eq 'TOPIC') {
            $hash{newtopic} = $5." ".$6." ".$7;

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
