package Pisg::Parser::Format::zcbot;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^[^ ]+ (\d+):[^ ]+ :([^!]+)[^ ]+ PRIVMSG (\#[^ ]+) :([^\001].*)',
        actionline => '^[^ ]+ (\d+):[^ ]+ :([^!]+)[^ ]+ PRIVMSG (\#[^ ]+) :\001ACTION (.*)',
        thirdline  => '^[^ ]+ (\d+):(\d+):\d+ :([^!]+)[^ ]+ ([A-Z]+) (.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o && lc($3) eq lc($self->{cfg}->{channel})) {

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $4;

        return \%hash;
    } else {
        return;
    }
}

sub actionline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o && lc($3) eq lc($self->{cfg}->{channel})) {

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $4;

        return \%hash;
    } else {
        return;
    }
}

sub thirdline
{
    my ($self, $line, $lines) = @_;
    my %hash;
    my $tmp;
    
    if ($line =~ /$self->{thirdline}/o) {

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $3;

        my @arr = split(" ", $5);
        if ($4 eq 'KICK' && lc($arr[0]) eq lc($self->{cfg}->{channel})) {
            $hash{kicker} = $hash{nick};
            $hash{nick} = $arr[1];

        } elsif ($4 eq 'TOPIC' && lc($arr[0]) eq lc($self->{cfg}->{channel})) {
            $tmp = join(" ", @arr[1..$#arr]);
            $tmp =~ s/^://;
            $hash{newtopic} = $tmp;

        } elsif ($4 eq 'MODE' && lc($arr[0]) eq lc($self->{cfg}->{channel})) {
            $hash{newmode} = $arr[1];

        } elsif ($4 eq 'JOIN' && lc($arr[0]) eq ":".lc($self->{cfg}->{channel})) {
            $hash{newjoin} = $3;

        } elsif ($4 eq 'NICK') {
            $arr[0] =~ s/^://;
            $hash{newnick} = $arr[0];
        }

        return \%hash;

    } else {
        return;
    }
}

1;
