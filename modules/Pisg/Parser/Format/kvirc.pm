package Pisg::Parser::Format::kvirc;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[(\d+):\d+[^ ]+ <([^>]+)> (.*)',
        actionline => '^\[(\d+):\d+[^ ]+ \*\*\* (\S+) (.*)',
        thirdline => '^\[(\d+):(\d+)[^ ]+ (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (.*)',
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
        $hash{min} = $2;
        $hash{nick} = $3;

        if (($4.$5.$6) eq 'hasbeenkicked') {
            $hash{kicker} = $10;

        } elsif (($5.$6) eq 'setstopic') {
            $hash{newtopic} = ($10.' '.$11);

        } elsif (($5.$6) eq 'setsmode') {
#can't be matched yet
            $hash{newmode} = substr($7, 1);

        } elsif (($5.$6) eq 'hasjoined') {
            $hash{newjoin} = $1;

        } elsif (($5.$6.$7) eq 'isnowknown') {
            $hash{newnick} = $9;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
