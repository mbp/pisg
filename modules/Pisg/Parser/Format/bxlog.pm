package Pisg::Parser::Format::bxlog;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[\d+ \S+\/(\d+):\d+\] <([^>]+)> (.*)',
        actionline => '^\[\d+ \S+\/(\d+):\d+\] \* (\S+) (.*)',
        thirdline => '^\[\d+ \S+\/(\d+):(\d+)\] ([<>@!]) (.*)'
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
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

        $hash{hour} = $1;
        $hash{min}  = $2;

        if ($3 eq '<') {
            if  ($4 =~ /^([^!]+)!\S+ was kicked off \S+ by ([^!]+)!/) {
                $hash{kicker} = $2;
                $hash{nick} = $1;
            }

        } elsif ($3 eq '>') {
            if ($4 =~ /^([^!]+)!\S+ has joined \S+$/) {
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
