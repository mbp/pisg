package Pisg::Parser::Format::muh;

# This is a Parser vor the well-known "muh-bouncer"
# by Bastian Friedrichs and Sebastian Erlhofer
# parser@boitl.org

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[\w\w\w \d\d \w\w\w (\d+):\d+:\d+\] <([^>\s]+)>\s+(.*)',
        actionline => '^\[\w\w\w \d\d \w\w\w (\d+):\d+:\d+\] <([^>\s]+)>\sACTION\s+(.*)',
        #thirdline  => '^\[\w\w\w \d\d \w\w\w (\d+):(\d+):\d+\] \*\*\*\s+(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (.*)',
        thirdline  => '^\[\w\w\w \d\d \w\w\w (\d+):(\d+):\d+\] \*\*\*\s+(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S*)(.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o and !($line =~ /$/)) {

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

        # Format-specific stuff goes here.

        if (($3.$6) eq 'Kickby') {
            $hash{kicker} = $7;
            $hash{nick} = $5;

        } elsif (($3.$4) eq 'Topicchange') {
            $hash{newtopic} = $10;
            #$hash{newtopic} = $9.$10;
            #$hash{newtopic} =~ s/^.* \):(.*)/$9$10/;
            $hash{nick}     = $8;


        } elsif ($3 eq 'Mode') {
            my $nm;
            $nm = substr($5, 1);
            if (($nm eq "+o") || ($nm eq "-o")) {
                $hash{nick} = $8;
                $hash{newmode} = $nm;
            }
            elsif (($nm eq "+oo") || ($nm eq "-oo")) {
                $hash{nick} = $9;
                $hash{newmode} = $nm;
            }
            elsif (($nm eq "+ooo") || ($nm eq "-ooo")) {
                $hash{nick} = substr($10, 1, index($10, ' ', 1)-1);
                $hash{newmode} = $nm;
            }


        } elsif (($2.$3) eq '\*\*\*Join') {
            $hash{newjoin} = $5;
        }


        return \%hash;

    } else {
        return;
    }
}

1;
