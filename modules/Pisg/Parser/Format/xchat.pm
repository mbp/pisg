package Pisg::Parser::Format::xchat;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        debug => $args{debug},
        normalline => '^(\d+):\d+:\d+ <([^>\s]+)>\s+(.*)',
        actionline => '^(\d+):\d+:\d+ \*\s+(\S+) (.*)',
        thirdline  => '^(\d+):(\d+):\d+ .--\s+(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {
        $self->{debug}->("[$lines] Normal: $1 $2 $3");

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
        $self->{debug}->("[$lines] Action: $1 $2 $3");

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
        $self->{debug}->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7 $8 $9");

        $hash{hour} = $1;
        $hash{min} = $2;
        $hash{nick} = $3;

        if (($4.$5) eq 'haskicked') {
            $hash{kicker} = $3;
            $hash{nick} = $6;

        } elsif (($4.$5) eq 'haschanged') {
            $hash{newtopic} = $9;

        } elsif (($4.$5) eq 'giveschannel') {
            $hash{newmode} = '+o';

        } elsif (($4.$5) eq 'removeschannel') {
            $hash{newmode} = '-o';

        } elsif (($5.$6) eq 'hasjoined') {
            $hash{newjoin} = $1;

        } elsif (($5.$6) eq 'nowknown') {
            $hash{newnick} = $8;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
