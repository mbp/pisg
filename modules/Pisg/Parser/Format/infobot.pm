package Pisg::Parser::Format::infobot;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

# Note that infobot log files do not distinguish between action lines and
# normal lines.

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^(\d+) \[\d+\] <([^\/]+)\/[^>]+> (.*)',
        actionline => '^NA',
        thirdline  => '^(\d+) \[\d+\] >>> (.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;
    my $sec; my $min; my $hour; my $mday; my $mon; my $year;
    my $wday; my $yday; my $isdst;

    if ($line =~ /$self->{normalline}/o) {

        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($1);
        $hash{hour}   = $hour;
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
    my $sec; my $min; my $hour; my $mday; my $mon; my $year; 
    my $wday; my $yday; my $isdst;

    if ($line =~ /$self->{actionline}/o) {

        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($1);
        $hash{hour}   = $hour;
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
    my $sec; my $min; my $hour; my $mday; my $mon; my $year; 
    my $wday; my $yday; my $isdst;

    if ($line =~ /$self->{thirdline}/o) {

        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($1);
        $hash{hour} = $hour;
        $hash{min}  = $min;

        if ($2 =~ /^\[1m([^(\[0m)]*)\[0m was kicked off \[1m[^\[]*\[0m by \[1m([^(\[0m)]*)\[0m .*/) {
            $hash{nick} = $1;
            $hash{kicker} = $2;

        } elsif ($2 =~ /^([^(\[1m)]*)\[1m\[\[0m#[^\[ ]+( ?:?)(.*)\[1m\]\[0m set the topic: (.*)/) {
            $hash{nick} = $1;
            $hash{newtopic} = "$3$2$4";
        
        } elsif ($2 =~ /^mode\/\S* \[\[1m([\+\-]o+) .* by \[1m(\S*)\[0m/) {
            $hash{newmode} = $1;
            $hash{nick} = $2;
            
        } elsif ($2 =~ /^(\S*) \(\S*\) has joined \#\S*/) {
            $hash{newjoin} = $1;
        
        } elsif ($2 =~ /^\[1;32m([^(\[0m)]*)\[0m materializes into \[1;32m([^(\[0m)]*)\[0m/) {
            $hash{nick} = $1;
            $hash{newnick} = $2;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
