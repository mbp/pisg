package Pisg::Parser::Format::grufti;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[(\d+):\d+\] <([^>]+)> (.*)',
        actionline => '^\[(\d+):\d+\] \* (\S+) (.*)',
        thirdline  => '^\[(\d+):(\d+)\] (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)(.*)',
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

        if ($5 eq 'kicked') {
            $hash{kicker} = $3;
            $hash{nick} = $6;

        } elsif (($4.$5) eq 'haschanged') {
            $hash{newtopic} = $9;

        } elsif (($4.$5) eq 'modechange') {
            $hash{newmode} = substr($6, 1);
            $hash{nick} = $9;
            $hash{nick} =~ /.*[by ](\S+)/;
            $hash{nick} = $1;

        } elsif ($5 eq 'joined') {
            $hash{newjoin} = $1;

        } elsif (($3.$4) eq 'Nickchange') {
            $hash{nick} = $7;
            $hash{newnick} = $9;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
