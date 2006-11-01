package Pisg::Parser::Format::miau;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm
# This Parser works with miau version 0.5.3, your milage may vary.

# 2005-05-07 Kresten Kjeldgaard <gathond@gathond.dk>
# This is a version of the muh2 parser that supports the log file format of the
# miau bouncer, mostly topic changes that are handled differently.

# 2006-10-26 adapted to miau logfile-format 0.6.x by mnh, jha and Myon 

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^[a-zA-Z]{3} \d{1,2} (\d+):\d+\S+ <([^>]+)> (.*)$',
        actionline => '^[a-zA-Z]{3} \d{1,2} (\d+):\d+\S+ \* (\S+) (.*)$',
        thirdline  => '^[a-zA-Z]{3} \d{1,2} (\d+):(\d+)\S+ [\-><\*][\-\*]{2} (.+)$'
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
        ($hash{nick}  = $2) =~ s/^[@%\+]//o; # Remove prefix
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
        ($hash{nick}  = $2) =~ s/^[@%\+]//o; # Remove prefix
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

        my @line = split(/\s/, $3);

        $hash{hour} = $1;
        $hash{min}  = $2;
        ($hash{nick}  = $line[0]) =~ s/^[@%\+]//o; # Remove prefix

        if ($#line >= 4 && ($line[1].$line[2]) eq 'waskicked') {
            $hash{kicker} = $line[4];

        } elsif ($#line >= 6 && (($line[1].$line[2]) eq 'haschanged')) {
            $hash{newtopic} = join(' ', @line[6..$#line]);
            $hash{newtopic} =~ s/^'//;
            $hash{newtopic} =~ s/'$//;

        } elsif ($#line >= 3 && ($line[1].$line[2]) eq 'setsmode') {
            $hash{newmode} = $line[3];

        } elsif ($#line >= 3 && ($line[2].$line[3]) eq 'hasjoined') {
            $hash{newjoin} = $line[0];

        } elsif ($#line >= 5 && ($line[2].$line[3]) eq 'nowknown') {
            $hash{newnick} = $line[5];
        }

        return \%hash;

    } else {
        return;
    }
}

1;
