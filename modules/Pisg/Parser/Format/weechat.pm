package Pisg::Parser::Format::weechat;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\d+ \S+ \d+ (\d+):\d+[^<]+<([^>]+)> (.*)',
        actionline => '^\d+ \S+ \d+ (\d+):\d+:\d+  -\*- (\S+) (.*)',
        thirdline  => '^\d+ \S+ \d+ (\d+):(\d+):\d+  (?:-=-|<--|-->) (\S+) (\S+) (\S+) (\S+) (\S+)(.*)',
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

        if (($4.$5) eq 'haskicked') {
            $hash{nick} = $6;
            $hash{kicker} = $3;

        } elsif ($4.$5.$6 eq 'haschangedtopic') {
            $hash{newtopic} = $8;
            $hash{newtopic} =~ m/to:(.*)/;
            $hash{newtopic} = $1;

        } elsif ($3 eq 'Mode') {
            $hash{newmode} = substr($5, 1);
            $hash{nick} = $8 || $7;
            $hash{nick} =~ s/.* (\S+)$/$1/; # Get the last word of the string

        } elsif (($5.$6) eq 'hasjoined') {
            $hash{newjoin} = $3;

        } elsif (($5.$6) eq 'nowknown') {
            if ($8 =~ /^\s+(\S+)/) {
                $hash{newnick} = $1;
            }
        }

        return \%hash;

    } else {
        return;
    }
}

1;
