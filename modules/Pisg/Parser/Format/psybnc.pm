package Pisg::Parser::Format::psybnc;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\d+-\d+-\d+-(\d+)-\d+-\d+:[^:]+::([^!]+)[^:]+:(.*)',
        actionline => '^\d+-\d+-\d+-(\d+)-\d+-\d+:[^:]+::([^!]+)[^:]+:\001ACTION (.*)',
        thirdline  => '^\d+-\d+-\d+-(\d+)-(\d+)-\d+:[^:]+::([^!]+)[^ ]+ (\w+) (.*)',
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

        my @arr = split(" ", $5);
        if ($4 eq 'KICK') {
            $hash{kicker} = $hash{nick};
            $hash{nick} = $arr[1];

        } elsif ($4 eq 'TOPIC') {
            $hash{newtopic} = join(" ", @arr[1..@arr]);

        } elsif ($4 eq 'MODE') {
            $hash{newmode} = $arr[1];
            $hash{newtopic} =~ s/^://;

        } elsif ($4 eq 'JOIN') {
            $hash{newjoin} = $3;

        } elsif ($4 eq 'NICK') {
            $hash{newnick} = $arr[1];;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
