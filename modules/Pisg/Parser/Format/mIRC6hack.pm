package Pisg::Parser::Format::mIRC6hack;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

# To use this logging format, add the following to mIRC's remote script
# section:

=head1 mIRC script

# 2004-11-21 by coaster

alias me {
  if ($1) {
    .describe $active $1-
    echo $color(own) -qt $active ** $me $1-
  }
  else {
    echo $color(info) $active * /me: insufficient parameters
  }
}

on ^*:ACTION:*:*:{
  echo $color(action) -lt $iif($chan,$chan,$nick) ** $nick $1-
  haltdef
}

=cut

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[(\d+):\d+:?\d*\] <([^>]+)> (.*)',
        actionline  => '^\[(\d+):\d+:?\d*\] \*\* (\S+) (.+)',
        thirdline  => '^\[(\d+):(\d+):?\d*\] \* (.+)'
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
        $hash{saying} = $3;
        ($hash{nick}  = $2) =~ s/^[@%\+~&]//o; # Remove prefix

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
        $hash{saying} = $3;
        ($hash{nick}  = $2) =~ s/^[@%\+~&]//o; # Remove prefix

        return \%hash;
    } else {
        return;
    }
}

sub thirdline
{
    my ($self, $line, $lines, $action) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

        my @line = split(/\s/, $3);

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{saying} = $3;
        ($hash{nick} = $line[0]) =~ s/^[@%\+~&]//o; # Remove prefix

        if ($#line >= 4 && ($line[1].$line[2]) eq 'waskicked' && ($line[$#line] =~ /\)$/)) {
                $hash{kicker} = $line[4];

        } elsif ($#line >= 4 && ($line[1].$line[2]) eq 'werekicked' && ($line[$#line] =~ /\)$/)) {
                $hash{kicker} = $line[4];
                $hash{nick} = $self->{cfg}{maintainer};

        } elsif ($#line >= 4 && ($line[1] eq 'changes') && ($line[$#line] =~ /\'$/)) {
                $hash{newtopic} = join(' ', @line[4..$#line]);
                $hash{newtopic} =~ s/^'//;
                $hash{newtopic} =~ s/'$//;

        } elsif ($#line >= 3 && ($line[1].$line[2]) eq 'setsmode:') {
            $hash{newmode} = $line[3];

        } elsif ($#line == 4 && ($line[2].$line[3]) eq 'hasjoined') {
            $hash{newjoin} = $line[0];

        } elsif ($line[0] eq 'Joins:') { # Alt+O -> IRC -> Options -> Short join/parts
            $hash{newjoin} = $line[1];

        } elsif ($#line == 5 && ($line[2].$line[3]) eq 'nowknown') {
            $hash{newnick} = $line[5];

        } elsif ($action) {
            if (
                ($hash{saying} =~ /^Set by \S+ on \S+ \S+ \d+ \d+:\d+:\d+/) ||
                ($hash{saying} =~ /^Now talking in #\S+/) ||  
                ($hash{saying} =~ /^Topic is \'.*\'/) ||  
                ($hash{saying} =~ /^Disconnected/) ||  
                ($hash{saying} =~ /^\S+ has quit IRC \(.+\)/) ||  
                ($hash{saying} =~ /^\S+ has left \#\S+/) ||  
                ($hash{saying} =~ /^\S+\s\S+ has left \#\S+/) ||
                ($hash{saying} =~ /^\S+\s\S+ Quit \S+/) ||
                ($hash{saying} eq "You're not channel operator") ||
                ($hash{nick} eq 'Attempting' && $hash{saying} =~ /^to rejoin channel/) ||  
                ($hash{nick} eq 'Rejoined' && $hash{saying} =~ /^channel/) ||  
                ($hash{saying} =~ /^Retrieving #\S+ info\.\.\./)
              ) {
                return 0;
            } else {
                $hash{saying} =~ s/^\Q$hash{nick}\E //;
                return \%hash;
            }

        } else {
            return;
        }

        return \%hash
            unless ($action);

    }
    return;
}

1;
