package Pisg::Parser::Format::mozbot;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

# This is a parser for Mozbot's XMLLogger module, NOT the standard logs!
# File amended from Template.pm by Adam "Fatman" Richardson

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '<msg channel="#.+" nick="(.+)" time="(.+)">(.+)</msg>',
        actionline => '<emote channel="#.+" nick="(.+)" time="(.+)">(.+)</emote>',
        thirdline  => '<(.+) channel="#.+" nick="(.+)" time="(.+)">(.*)</.+>',
    };

    bless($self, $type);
    return $self;
}

# Parse a normal line - returns a hash with 'hour', 'nick' and 'saying'
sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {
        my $time      = $2;
        $hash{nick}   = $1;
        $hash{saying} = convert($3);

        $time =~ /T(\d\d)/;
        $hash{hour} = int($1);

        return \%hash;
    } else {
        return;
    }
}

# Parse an action line - returns a hash with 'hour', 'nick' and 'saying'
sub actionline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o) {
        my $time      = $2;
        $hash{nick}   = $1;
        $hash{saying} = convert($3);

        $time =~ /T(\d\d)/;
        $hash{hour} = int($1);

        return \%hash;
    } else {
        return;
    }
}

# Parses the 'third' line - (the third line is everything else, like
# topic changes, mode changes, kicks, etc.)
sub thirdline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {
        my $time  = $3;
        my $act   = $1;
        my $nick  = $2;
        my $doing = convert($4);

        $time =~ /T(\d\d):(\d\d)/;
        $hash{hour} = int($1);
        $hash{min}  = int($2);

        $hash{nick} = $nick;

        if ($act eq 'kick') {
            $hash{nick} = $doing;
            $hash{kicker} = $nick;
            $hash{kicktext} = '';

        } elsif ($act eq 'mode') {
            $hash{newmode} = $doing;

        } elsif ($act eq 'join') {
            $hash{newjoin} = $nick;

        } elsif ($act eq 'topic') {
            $hash{newtopic} = $doing;
        }

        return \%hash;
    } else {
        return;
    }
}

# Convert XML-entities
sub convert
{
   my $string = shift;
   $string =~ s/&apos;/\'/g;
   $string =~ s/&quot;/\"/g;
   $string =~ s/&gt;/>/g;
   $string =~ s/&lt;/</g;
   $string =~ s/&amp;/&/g;
   return $string;
}

1;
