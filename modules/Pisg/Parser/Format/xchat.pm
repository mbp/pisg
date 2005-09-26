package Pisg::Parser::Format::xchat;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

# This module supports both the old and new logformat (after 1.8.7)

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '(\d+):\d+:\d+ <[@%+~&]?([^>\s]+)>\s+(.*)',
        actionline => '(\d+):\d+:\d+ \*{1,}\s+(\S+) (.*)',
        thirdline  => '(\d+):(\d+):\d+ [<-]-[->]\s+(\S+) (\S+) (\S+) (\S+) ((\S+)\s*(\S+)?\s*(.*)?)',
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
        $hash{nick} = $3;

        if (($4.$5) eq 'haskicked') {
            $hash{kicker} = $3;
            $hash{nick} = $6;

        } elsif (($4.$5) eq 'haschanged') {
            $hash{newtopic} = $10;

        } elsif (($4.$5.$6) eq 'giveschanneloperator') {
            $hash{newmode} = '+o';

        } elsif (($4.$5.$6) eq 'removeschanneloperator') {
            $hash{newmode} = '-o';

        } elsif (($4.$5.$6) eq 'giveschannelhalf-operator') {
            $hash{newmode} = '+h';

        } elsif (($4.$5.$6) eq 'removeschannelhalf-operator') {
            $hash{newmode} = '-h';

        } elsif (($4.$5) eq 'givesvoice') {
            $hash{newmode} = '+v';

        } elsif (($4.$5) eq 'removesvoice') {
            $hash{newmode} = '-v';

        } elsif (($5.$6) eq 'hasjoined') {
            $hash{newjoin} = $1;

        } elsif (($5.$6) eq 'nowknown') {
            $hash{newnick} = $9;

        } elsif (($3.$4.$6) eq 'Topicforis') {
            $self->{topictemp} = $7;
            $hash{newtopic} = $7;

        } elsif (($3.$4.$6) eq 'Topicforset') {
            $hash{nick} = $9;
            $hash{newtopic} =  $self->{topictemp};

        }

        return \%hash;

    } else {
        return;
    }
}

1;
