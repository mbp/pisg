package Pisg::Parser::Format::dircproxy;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;

    my $self = {
        cfg => $args{cfg},
	normalline => '^<([^!]+)![^>]+>\s\[(\d{2}):\d{2}\]\s(.+)$',
        actionline => '^\[([^!]+)![^\]]+\]\s\[(\d{2}):\d{2}\]\sACTION\s(.+)$',
	thirdline  => '^\-(\S+)\-\s\[(\d{2}:\d{2})\]\s(.+)$'
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {
        $hash{hour}   = $2;
        $hash{nick}   = $1;
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
        $hash{hour}   = $2;
        $hash{nick}   = $1;
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

        return
            if ($1 eq 'dircproxy');

        @line = split(/\s+/, $3);

        my @time = split(/:/, $2);
        $hash{hour} = $time[0];
        $hash{min} = $time[1];
        $hash{nick} = $line[0];

        if (defined($line[3]) && $line[0] eq 'Kicked') {
            $hash{kicker} = $line[3];
            $hash{nick} = $self->{cfg}->{maintainer};

        } elsif (defined($line[4]) && $line[1] eq 'kicked') {
            $hash{kicker} = $line[4];

        } elsif (defined($line[3]) && $line[2] eq 'changed') {
            if ($line[3] eq 'mode:') {
                $hash{newmode} = join(' ', @line[4..$#line]);
            } elsif ($line[3] eq 'topic:') {
                $hash{newtopic} = join(' ', @line[4..$#line]);
            }

        } elsif (defined($line[2]) && $line[2] eq 'joined') {
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
