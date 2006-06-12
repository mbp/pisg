package Pisg::Parser::Format::psybnc;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\d+-\d+-\d+-(\d+)-\d+-\d+:[^:]+::([^!]+)[^:]+ PRIVMSG [^:]+:([^\001]+)',
        actionline => '^\d+-\d+-\d+-(\d+)-\d+-\d+:[^:]+::([^!]+)[^:]+:\001ACTION ([^\001]*)',
        thirdline  => '^\d+-\d+-\d+-(\d+)-(\d+)-\d+:[^:]+::([^! .]+)[^ ]* (\w+) \S+ :?((\S*)\s*(.*))',
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

        if ($4 eq 'KICK') {
            $hash{kicker} = $hash{nick};
            $hash{nick} = $6;

        } elsif ($4 eq 'TOPIC') {
            $hash{newtopic} = $5;

        } elsif ($4 eq 'MODE') {
            $hash{newmode} = $6;

        } elsif ($4 eq 'JOIN') {
            $hash{newjoin} = $3;

        } elsif ($4 eq 'NICK') { # does this work?
            $hash{newnick} = $6;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
