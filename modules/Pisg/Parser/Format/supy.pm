package Pisg::Parser::Format::supy;

# pisg log parser for supybot bot
# http://supybot.sf.net
# Copyright Jerome Kerdreux / Licence GPL 
# contact Jerome.Kerdreux@finix.eu.org for more information

# This module supports both the old and new logformat (after 1.8.7)


use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
	# [12-Feb-2004 16:59:42]  <philipss> plop
	normalline => '^\[\d+-\w+-\d+ (\d+):\d+:\d+]  <(\S+)> (.*)',
	# [05-Mar-2004 17:28:10]  * Jkx|home bon je vais pas trainer ..
        actionline => '^\[\d+-\w+-\d+ (\d+):\d+:\d+]  \* (\S+) (.*)',
	# [17-Feb-2004 08:13:47]  *** Jkx changes topic to "Oh my god of topic"
        thirdline  => '\[\d+-\w+-\d+ (\d+):(\d+):\d+]  \*\*\* (\S+) (\S+) (\S+) (\S+) ?(.*)?',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {
        $hash{hour} = $1;
        $hash{nick} = $2;
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

        $hash{hour} = $1;
        $hash{nick} = $2;
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
        $hash{min} = $2;
        $hash{nick} = $3;

	
	
	# print "*** 1/$1 2/$2 3/$3 4/$4 5/$5 6/$6 7/$7 ***\n";

	# all action are catched except nick change because 
	# there aren't in the logfile :( 
	
        if (($4.$5) eq 'waskicked') {
            $hash{kicker} = $7;
            $hash{kicker} =~ s/\s.*//;

        } elsif (($4.$5) eq 'changestopic') {
            $hash{newtopic} = $7;
	} elsif (($4.$5) eq 'setsmode:') {
            $hash{newmode} = $6;

        } elsif (($4.$5) eq 'hasjoined') {
            $hash{newjoin} = $3;

        } 
	
	

	# print %hash;
	# print "\n";
        return \%hash;

    } else {
        return;
    }
}

1;
