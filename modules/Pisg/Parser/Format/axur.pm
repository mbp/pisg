package Pisg::Parser::Format::axur;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[\d+/\d+/\d+ @ (\d+):\d+:\d+\] [\>\(|<]+([^>\s]+)[\)|>]\s+(.*)',
        actionline => '^\[\d+/\d+/\d+ @ (\d+):\d+:\d+\] \*\s+(\S+) (.*)',
        thirdline  => '^\[\d+/\d+/\d+ @ (\d+):(\d+):\d+\] \*\*\*\s+(\S+) (\S+) (\S+) (\S+) (\S+) (.*)',
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
            $hash{newtopic} = $8;

        } elsif (($7) eq '+o') {
            $hash{newmode} = '+o';

        } elsif (($7) eq '-o') {
            $hash{newmode} = '-o';

        } elsif (($4.$5) eq 'hasjoined') {
            $hash{newjoin} = $3;

        } elsif ((($4.$5) eq 'nowknown') || (($4.$5) eq 'nowknow')) {
            $hash{newnick} = $7;

        }

        return \%hash;

    } else {
        return;
    }
}

1;

