package Pisg::Parser::Format::IRCAP;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

# Modifications to parse IRCAP 7.5 logs, made by Armando Camarero, September 2003.
# This file is a modification of the mIRC6 parser file included in Pisg 0.49.
# Copyright (C) 2003 Armando Camarero <arcepi10@terra.es>
#
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 2 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# To see this script working visit http://arcepi.hn.org/ED/ (statistics aren't online 24x7 - hosted at my computer...)
# Sorry if the script isn't too clean, it is the first thing I programmed (I also learnt Perl doing this), but I can say
# it works perfectly.
# This script needs log timestamp to be enabled in mIRC: File -> Options -> IRC: Logging and mark Timestamp logs.

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[(\d+):\d+:?\d*\] <([^>]+)> (.*)',
        thirdline  => '^\[(\d+):(\d+):?\d*\] (\*\*\*|\*) (.+)',
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
        ($hash{nick}  = $2) =~ s/^[@%\+~&]//o; # Remove prefix
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

    return $self->thirdline($line, $lines, 1);
}

sub thirdline
{
    my ($self, $line, $lines, $action) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

        my @line = split(/\s/, $3);
	my @linea = split (/\s/, $line);
        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{saying}  = $3;
        ($hash{nick}  = $line[0]) =~ s/^[@%\+~&]//o; # Remove prefix
	if ($#linea >= 2 and $linea[2] eq 'topic:') {
	#print $linea[2], "\n";
	}
       if ($#linea >= 7 && ($linea[3].$linea[4]) eq 'hasido') {
                $hash{kicker} = $linea[7];
		$hash{nick} = $linea[2];
		my $razon = join (' ', @linea[8..$#linea]);
		$razon =~ s/(\(|\))//g;
		$hash{kicktext} = $razon;
		#print "kick detectado: $linea[7] kickeo a $linea[2], razón $razon\n";

        } elsif ($#line >= 4 && ($line[1].$line[2]) eq 'werekicked' && ($line[$#line] =~ /\)$/)) {
                $hash{kicker} = $line[4];
                $hash{nick} = $self->{cfg}{maintainer};

        } elsif ($#linea >= 4 && ($linea[2] eq 'topic:')) {
                $hash{newtopic} = join(' ', @linea[5..$#linea]);
                $hash{newtopic} =~ s/^'//;
                $hash{newtopic} =~ s/'$//;
		$hash{nick} = $linea[3];
		
        } elsif ($#linea >= 5 && $linea[2] eq 'modo:') {
		#print "Cambio de modo detectado\n";
		$linea[5] =~ s/\[//g;
		$linea[6] =~ s/\]//g;
		#print $linea[6], "\n";
		$hash{newmode} = $linea[5]; 	# newmode es +o -o etc....
	    	$hash{modechanges} = $linea[6];	# modechanges es el nick al que se le da/quita la @
		$hash{nick} = $linea[3];	# nick, como siempre, es el que la da.
		
        } elsif ($#linea == 7 && $linea[6] eq 'entra') {
		#print "Entrada al canal detectada de $linea[2]\n";
		$hash{newjoin} = $linea[2];
		$hash{nick} = $linea[2];
		
        } elsif ($#linea == 5 && ($linea[3].$linea[4]) eq 'esahora') {
		#print "Cambio de nick detectado\n";
		$hash{newnick} = $linea[5];
		$hash{nick} = $linea[2];

        } elsif ($action) {
		$line =~ s/^\[(\d+):(\d+):?\d*\] \* //;
		$hash{saying} = $line;
		my @nick = split (' ', $hash{saying});
		$hash{nick} = $nick[0];
		#print $line, "\n";
		#print $hash{saying}, "\n";
            if (
                ($hash{saying} =~ /^Set by \S+ on \S+ \S+ \d+ \d+:\d+:\d+/) ||
                ($hash{saying} =~ /^Now talking in #\S+/) ||  
                ($hash{saying} =~ /^Topic is \'.*\'/) ||  
                ($hash{saying} =~ /^Disconnected/) ||  
                ($hash{saying} =~ /^\S+ has quit IRC \(.+\)/) ||  
                ($hash{saying} =~ /^\S+ has left \#\S+/) ||  
                ($hash{saying} eq "You're not channel operator") ||
                ($hash{nick} eq 'Attempting') ||  
                ($hash{nick} eq 'Rejoined') ||  
                ($hash{saying} =~ /^Retrieving #\S+ info\.\.\./) ||
		($hash{saying} =~ /^\[/)
              ) {
		#print "$hash{saying} No es una ACCION\n";
                return 0;
            } else {
		   #print "Detectada una ACCION: $hash{saying}\n";
		   #print $nick[0], "\n";
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
