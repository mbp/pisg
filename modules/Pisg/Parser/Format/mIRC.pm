package Pisg::Parser::Format::mIRC;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

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
        $hash{saying} = $3;
        ($hash{nick}  = $2) =~ s/^[@%\+~&]//o; # Remove prefix

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
        $hash{saying} = $3;
        ($hash{nick}  = $2) =~ s/^[@%\+~&]//o; # Remove prefix

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

        $hash{hour}  = $1;
        $hash{min}   = $2;
        ($hash{nick} = $line[0]) =~ s/^[@%\+~&]//o; # Remove prefix

        if ($#line >= 4 && ($line[1].$line[2]) eq 'waskicked') {
            $hash{kicker} = $line[4];

        } elsif ($#line >= 4 && ($line[1] eq 'changes')) {
            $hash{newtopic} = join(' ', @line[4..$#line]);
            $hash{newtopic} =~ s/^'//;
            $hash{newtopic} =~ s/'$//;

        } elsif ($#line >= 3 && ($line[1].$line[2]) eq 'setsmode:') {
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
