package Pisg::Parser::Format::muh2;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm
# This Parser works with muh version muh-2.1 and above.
# muh got a new log-format, so this is version 2
# contact: boitl @ IRC, sebastian@mquant.de, 09/2003
# note:
# muh-2.1 is buggy in action-loggin. 
# apply http://www.mquant.de/downloads/muh-actionpatch.diff


use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[(\d+):\d+\S+ <([^>]+)> (.*)$',
        actionline => '^\[(\d+):\d+\S+ \* (\S+) (.*)$',
	thirdline  => '^\[(\d+):(\d+)\S+ \*{3} (.+)$'
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

        my @line = split(/\s/, $3);

        $hash{hour} = $1;
        $hash{min}  = $2;
        ($hash{nick}  = $line[0]) =~ s/^[@%\+~&]//o; # Remove prefix

        if ($#line >= 4 && ($line[1].$line[2]) eq 'waskicked') {
            $hash{kicker} = $line[4];

        } elsif ($#line >= 4 && ($line[1] eq 'changes')) {
            $hash{newtopic} = join(' ', @line[4..$#line]);
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
