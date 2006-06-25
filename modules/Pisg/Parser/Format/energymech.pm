package Pisg::Parser::Format::energymech;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[[^\]]*(\d{2}):\d+:\d+\] <([^>]+)> (.*)$',
        actionline => '^\[[^\]]*(\d{2}):\d+:\d+\] \* (\S+) (.*)$',
        thirdline  => '^\[[^\]]*(\d{2}):(\d+):\d+\] \*{3} (.+)$'
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

        my @line = split(/\s/, $3);

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $line[0];

        if ($#line >= 4 && ($line[1].$line[2]) eq 'waskicked') {
            $hash{kicker} = $line[4];
            $hash{kicktext} = $3;
            $hash{kicktext} =~ s/^[^\(]+\((.+)\)$/$1/;

        } elsif ($#line >= 4 && ($line[1].$line[2]) eq 'changestopic') {
            $hash{newtopic} = join(' ', @line[4..$#line]);
            $hash{newtopic} =~ s/^'//;
            $hash{newtopic} =~ s/'$//;

        } elsif ($#line >= 4 && ($line[1].$line[2]) eq 'setsmode:') {
            $hash{newmode} = $line[3];
            $hash{modechanges} = join(" ", splice(@line, 4));

        } elsif ($#line >= 1 && $line[0] eq 'Joins:') {
            $hash{nick} = $line[1];
            $hash{newjoin} = $line[1];
            
        } elsif ($#line >= 5 && ($line[2].$line[3]) eq 'nowknown') {
            $hash{newnick} = $line[5];
        }

        return \%hash;

    } else {
        return;
    }
}

1;
