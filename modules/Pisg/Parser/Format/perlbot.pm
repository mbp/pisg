package Pisg::Parser::Format::perlbot;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^(\d+):\d+:\d+[^ ]+ <([^>]+)> (.*)',
        actionline => '^(\d+):\d+:\d+[^ ]+ \* (\S+) (.*)',
        thirdline  => '^(\d+):(\d+):\d+[^ ]+ (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)(.*)',
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
        ($hash{nick}  = $2) =~ s/^[@%\+~&]//o; # Remove prefix
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
        ($hash{nick}  = $2) =~ s/^[@%\+~&]//o; # Remove prefix
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
        ($hash{nick}  = $4) =~ s/^[@%\+~&]//o; # Remove prefix

        if (($3) eq '[KICK]') {
            $hash{kicker} = $8;

        } elsif ($3 eq '[TOPIC]') {
            $hash{newtopic} = "$5 $6 $7 $8 $9";

        } elsif (($3) eq '[MODE]') {
            $hash{newmode} = $7;

        } elsif (($5) eq 'joined') {
            $hash{newjoin} = $3;

        } elsif (($3) eq '[NICK]') {
            $hash{newnick} = $8;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
