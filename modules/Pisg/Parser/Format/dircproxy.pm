package Pisg::Parser::Format::dircproxy;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;

    my $self = {
        cfg             => $args{cfg},
        normalline      => '^<([^!]+)![^>]+>\s\[(\d{2}):\d{2}\]\s(.+)$',
        actionline      => '^\[([^!]+)![^\]]+\]\s\[(\d{2}):\d{2}\]\sACTION\s(.+)$',
        thirdline       => '^\-(\S+)\-\s\[(\d{2}:\d{2})\]\s(.+)$',
        normalline_old  => '^@(\d+)\s<([^!]+)![^>]+>\s(.+)$',
        actionline_old  => '^@(\d+)\s\[([^!]+)![^\]]+\]\sACTION\s(.+)$',
        thirdline_old   => '^@(\d+)\s\S+\s(.+)$'
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
    } elsif ($line =~ /$self->{normalline_old}/o) {
        $hash{hour}   = (localtime($1))[2];
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
        $hash{hour}   = $2;
        $hash{nick}   = $1;
        $hash{saying} = $3;

        return \%hash;
    } elsif ($line =~ /$self->{actionline_old}/o) {
        $hash{hour}   = (localtime($1))[2];
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
    my @word;

    if ($line =~ /$self->{thirdline}/o) {
        return if ($1 eq 'dircproxy');

        @word = split(/\s+/, $3);

        my @time = split(/:/, $2);
        $hash{hour} = $time[0];
        $hash{min} = $time[1];

    } elsif ($line =~ /$self->{thirdline_old}/o) {
        return if ($1 eq 'dircproxy');

        @word = split(/\s+/, $2);

        $hash{hour} = (localtime($1))[2];
        $hash{min} = (localtime($1))[1];

    } else {
        return;
    }


    # the real parser here for thirdline...
    $hash{nick} = $word[0];
    
    if (defined($word[3]) && $word[0] eq 'Kicked') {
        $hash{kicker} = $word[3];
        $hash{nick} = $self->{cfg}->{maintainer};

    } elsif (defined($word[4]) && $word[1] eq 'kicked') {
        $hash{kicker} = $word[4];

    } elsif (defined($word[3]) && $word[2] eq 'changed') {
        if ($word[3] eq 'mode:') {
            $hash{newmode} = join(' ', @word[4..$#word]);
        } elsif ($word[3] eq 'topic:') {
            $hash{newtopic} = join(' ', @word[4..$#word]);
        }

    } elsif (defined($word[2]) && $word[2] eq 'joined') {
        $hash{newjoin} = $hash{nick};

    }
    # elsif ($word[0] eq 'NICK') {
    #    $hash{newnick} = $word[1];
    #    $hash{newnick} =~ s/^://;
    #}


    return \%hash;
}

1;
