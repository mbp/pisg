package Pisg::Parser::Format::irssi;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my $type = shift;
    my $self = {
        debug => $_[0],
        normalline => '^(\d+):\d+ <[@+ ]?([^>]+)> (.*)',
        actionline => '^(\d+):\d+  \* (\S+) (.*)',
        thirdline  => '^(\d+):(\d+) -\!- (\S+) (\S+) (\S+) (\S+) (\S+)(.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/) {
        $self->{debug}->("[$lines] Normal: $1 $2 $3");

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

    if ($line =~ /$self->{actionline}/) {
        $self->{debug}->("[$lines] Action: $1 $2 $3");

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

    if ($line =~ /$self->{thirdline}/) {
        if (defined $8) {
            $self->{debug}->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7 $8");
        } else {
            $self->{debug}->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7");
        }

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $3;

        if (($4.$5) eq 'waskicked') {
            $hash{kicker} = $8;
            $hash{kicker} =~ s/.* by (\w+) .*/$1/;

        } elsif ($4 eq 'changed') {
            $hash{newtopic} = $8;

        } elsif (substr($3, 0, 4) eq 'mode') {
            $hash{newmode} = substr($4, 1);
            $hash{nick} = $8;
            $hash{nick} =~ s/.* (\w+)$/$1/; # Get the last word of the string

        } elsif (($5.$6) eq 'hasjoined') {
            $hash{newjoin} = $3;

        } elsif (($4.$5) eq 'nowknown') {
            $hash{newnick} = $8;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
