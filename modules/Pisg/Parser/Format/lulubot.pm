# This is the lulubot log parser by Vianney Lecroart <acemtp@free.fr>
# More info about lulubot here: http://lulubot.berlios.de and
# here: http://developer.berlios.de/projects/lulubot
# Version tested with the CVS the 12/04/04

# [22-11-2004/14:42] *** Joined ace (~ace@154.25.145.85)
# [22-11-2004/15:00] <ace> morning
# [22-11-2004/15:01] * ace is back

package Pisg::Parser::Format::lulubot;

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[[^/]+/(\d+):\d+\] <([^>]+)> (.*)$',
        actionline => '^\[[^/]+/(\d+):\d+\] \* (\S+) (.*)$',
        thirdline  => '^\[[^/]+/(\d+):(\d+)\] \*{3} (\S+) (\S+) (.*)$',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {

        # Most log formats are regular enough that you can just match the
        # appropriate things with parentheses in the regular expression.

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

        # Most log formats are regular enough that you can just match the
        # appropriate things with parentheses in the regular expression.

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

        if ($3 eq 'Joined') {
            $hash{newjoin} = $4;
            $hash{nick} = $4;
        } elsif ($4 eq 'changed') {
            $5 =~ /^topic to (.*)$/;
            $hash{newtopic} = $1;
        } elsif ($4 eq 'is') {
            $5 =~ /^now known as (.*)$/;
            $hash{newnick} = $1;
        }

        return \%hash;
    } else {
        return;
    }
}

1;
