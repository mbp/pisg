package Pisg::Parser::Format::ircle;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^(\d+):\d+ \w+:[^\w]+(\w+): (.*)',
        actionline => '^(\d+):\d+ \w+:[^\w]+(\w+) (.*)',
        thirdline  => '^(\d+):(\d+) \w+: \*\*\* (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (.*)',
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

        if (($5.$6) eq 'beenkicked') {
            $hash{kicker} = $11;

        } elsif ($3 eq 'Topic') {
            $hash{newtopic} = "$6 $7 $8";

        } elsif (($3.$4) eq 'Modechange') {
            $hash{newmode} = substr($5, 1);

        } elsif (($5.$6) eq 'hasjoined') {
            $hash{newjoin} = $3;

        } elsif (($5.$6) eq 'nowknown') {
            $hash{newnick} = $8;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
