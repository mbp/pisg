package Pisg::Parser::Format::dircproxy;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;

    my $self = {
        cfg => $args{cfg},
        normalline => '@^(\d+)\s<([^!]+)![^>]+>\s(.+)$',
        actionline => '@^(\d+)\s\[([^!]+)![^\]]+\]\sACTION\s(.+)$',
	thirdline  => '@^(\d+)\s\-\S+\-\s(.+)
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {
        my @time = localtime($1);
        $hash{hour}   = $time[2];
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
        my @time = localtime($1);
        $hash{hour}   = $time[2];
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
        my ($time, @line);
        @line = split(/\s+/, $2);

        my @time = localtime($1);
        $hash{hour} = $time[2];
        $hash{min} = $time[1];
        $hash{nick} = $line[0];


        if ($line[0] eq 'Kicked') {
            $hash{kicker} = $line[3];
            $hash{nick} = $self->{cfg}->{maintainer};

        } elsif ($line[1] eq 'kicked') {
            $hash{kicker} = $line[4];

        } elsif ($line[2] eq 'changed') {
            if ($line[3] eq 'mode:') {
                $hash{newmode} = join(' ', @line[4..$#line]);
            } elsif ($line[3] eq 'topic:') {
                $hash{newtopic} = join(' ', @line[4..$#line]);
            }

        } elsif ($line[2] eq 'joined') {
            $hash{newjoin} = $hash{nick};

        }
        # elsif ($line[0] eq 'NICK') {
        #    $hash{newnick} = $line[1];
        #    $hash{newnick} =~ s/^://;
        #}


        return \%hash;

    } else {
        return;
    }
}

1;
