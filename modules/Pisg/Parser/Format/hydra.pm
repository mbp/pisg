package Pisg::Parser::Format::hydra;

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[\d+-\d+-\d+ (\d+):\d+:\d+\] <([^>\s]+)> (.*)',
        actionline => '^\[\d+-\d+-\d+ (\d+):\d+:\d+\] \* (\S+) (.+)',
        thirdline  => '^\[\d+-\d+-\d+ (\d+):(\d+):\d+\] \*{3} (.+)',
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

        # Format-specific stuff goes here.

        if ($3 =~ /^(\S+) was kicked from (\S+) by (\S+) (.+)/) {
            $hash{nick} = $1;
            $hash{kicker} = $3;
            $hash{kicktext} = $4;

        } elsif ($3 =~ /^(\S+) changed topic to (.+)/) {
             $hash{nick} = $1;
             $hash{newtopic} = $2;
             
        } elsif ($3 =~ /^(\S+) sets channel \S+ mode (\S+) (.+)/) {
             $hash{nick} = $1;
             $hash{newmode} = $2;
             $hash{modechanges} = $3;

        } elsif ($3 =~ /^(\S+) \S+ has joined channel \S+/) {
            $hash{nick} = $1;
            $hash{newjoin} = $1;

        } elsif ($3 =~ /^(\S+) changed nick to (\S+)/) {
            $hash{nick} = $1;
            $hash{newnick} = $2;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
