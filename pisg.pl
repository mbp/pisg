#!/usr/bin/perl -w

use strict;
use Getopt::Long;

# pisg - Perl IRC Statistics Generator
#
# Copyright (C) 2001  <Morten 'LostStar' Brix Pedersen> - morten@wtf.dk
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

my $config;

# Values that _MUST_ be set below (unless you pass them on commandline)
$config->{channel} = "#channel";	# The name of your channel.
$config->{logfile} = "channel.log";	# The exact filename of the logfile
$config->{format} = "mIRC";		# logfile format. see FORMATS file
$config->{network} = "SomeIRCNet";	# Network the channels is using.
$config->{outputfile} = "index.html";	# The name of the html file to be generated
$config->{maintainer} = "MAINTAINER";	# The maintainer or bot which makes the logfile
$config->{pagehead} = "none";		# Some 'page header' file which you want to
					# include in top of the stats

$config->{configfile} = "pisg.cfg";	# Path to config file (aliases, ignores,
					# pics and more, see pisg.cfg for examples)

$config->{imagepath} = "";	# If your user pictures is located
				# some special directory, set the path here.

$config->{logdir} = "";		# If you specify a path to a dir here, then
				# pisg will take that dir, and parse ALL
				# logfiles in it, and create 1 HTML file
				# from it

$config->{lang} = 'EN';			# Language to use:
			   	        # EN | DE | DK | FR | ES | PL
$config->{langfile} = 'lang.txt';	# Name of language file

$config->{prefix} = "";         # If you specify a string here and have $logdir
                                # set, then only those files starting with
                                # $prefix in $logdir will be read.



# Here you can set the colors for your stats page..
$config->{bgcolor} = "#dedeee";		# Background color of the page
$config->{text} = "black";		# Normal text color
$config->{hbgcolor} = "#666699";	# Background color in headlines
$config->{hcolor} = "white";		# Text color in headline
$config->{hicell} = "#BABADD";		# Background color in highlighted cells
$config->{hicell2} = "#CCCCCC";		# Background color in highlighted cells
$config->{tdcolor} = "black";		# Color of text in tables
$config->{tdtop} = "#C8C8DD";		# Top color in some tables.
$config->{link} = "#0b407a";		# Color of links
$config->{vlink} = "#0b407a";		# Color of visited links
$config->{hlink} = "#0b407a";		# Color of hovered links
$config->{headline} = "#000000";	# Border color of headlines
$config->{rankc} = "#CCCCCC";           # Colors of 'ranks' (1,2,3,4)
$config->{pic1} = "pipe-blue.png";	# Bar-graphic-file for normal times
$config->{pic2} = "pipe-purple.png";    # Bar-graphic-file for top-times

# Other things that you might set, but not everyone cares about them
$config->{minquote} = "25";	# Minimal value of letters for a random quote
$config->{maxquote} = "65";	# Maximum value of letters for a random quote
$config->{wordlength} = "5";	# The minimum number of chars an interesting
				# word may be (in 'most referenced words')
$config->{activenicks} = "25";	# Number of nicks to show in the 'top 25'
$config->{activenicks2} = "30";	# Nicks to show in 'these didnt make it...'
$config->{topichistory} = "3";	# How many topics to show in 'latest topics'
$config->{nicktracking} = 0;	# Track nickchanges and create aliases (can
				# be slow, so it's disabled by default)

$config->{timeoffset} = "+0";	# A time offset on the stats page - if your
				# country has a different timezone than the
				# machine where the stats are being
				# generated, then for example do +1
				# to add 1 hour to the time

# You shouldn't care about anything below this point
$config->{debug} = 0;			# 0 = Debugging off, 1 = Debugging on
$config->{debugfile} = "debug.log";	# Path to debug file(must be set if $debug == 1)
$config->{version} = "v0.18-cvs";

my ($lines, $kicked, $gotkicked, $smile, $longlines, $time, $timestamp, %alias,
$normalline, $actionline, $thirdline, @ignore, $line, $processtime, @topics,
%monologue, %kicked, %gotkick, %line, %length, %qpercent, %lpercent, %sadface,
%smile, $nicks, %longlines, %mono, %times, %question, %loud, $totallength,
%gaveop, %tookop, %joins, %actions, %sayings, %wordcount, %lastused, %gotban,
%setban, %foul, $days, $oldtime, $lastline, $actions, $normals, %userpics,
%userlinks, %T, $repeated, $lastnormal);

sub main
{
    init_config();      # Init config. (Aliases, ignores, other options etc.)
    init_pisg();        # Init commandline arguments and other things
    init_lineformats(); # Attempt to set line formats in compliance with user specification (--format)

    init_debug(); 	        # Init the debugging file

    if ($config->{logdir}) {
        parse_dir();            # Run through all logfiles in dir
    } else {
        parse_file($config->{logfile});   # Run through the whole logfile
    }

    create_html();      # Create the HTML
                        # (look here if you want to remove some of the
                        # stats which you don't care about)

    close_debug();      # Close the debugging file

    print "\nFile was parsed succesfully in $processtime on $time.\n";
}

sub init_pisg
{
    print "pisg $config->{version} - Perl IRC Statistics Generator\n\n";

    get_cmdlineoptions();
    get_language_templates();

    $timestamp = time;

    if ($config->{timeoffset} =~ /\+(\d+)/) {
        # We must plus some hours to the time
        $timestamp += 3600 * $1; # 3600 seconds per hour

    } elsif ($config->{timeoffset} =~ /-(\d+)/) {
        # We must remove some hours from the time
        $timestamp -= 3600 * $1; # 3600 seconds per hour
    }

    # Set useful values.
    $days = 1;
    $oldtime = "00";
    $lastline = "";
    $actions = "0";
    $normals = "0";
    $time = localtime($timestamp);
    $repeated = 0;
    $lastnormal = "";

    # Add trailing slash when it's not there..
    if (substr($config->{imagepath}, -1) ne '/') {
        $config->{imagepath} =~ s/(.*)/$1\//;
    }

    print "Statistics for channel $config->{channel} \@ $config->{network} by $config->{maintainer}\n\n";

}

sub init_lineformats {

    # These are the regular expressions which matches the lines in the logfile,
    # and looks different if it's xchat, mIRC or whatever.
    # If you want to add support for a new format - you first have to add the
    # regex here, and then you also have to modify the parse subroutines called
    # 'parse_normalline()', 'parse_actionline()' and 'parse_thirdline()'

    if ($config->{format} eq 'xchat') {
        $normalline = '^(\d+):\d+:\d+ <([^>]+)>\s+(.*)';
        $actionline = '^(\d+):\d+:\d+ \*\s+(\S+) (.*)';
        $thirdline = '^(\d+):(\d+):\d+ .--\s+(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (.*)';
    } elsif ($config->{format} eq 'mIRC') {
        $normalline = '^\[(\d+):\d+\] <([^>]+)> (.*)';
        $actionline = '^\[(\d+):\d+\] \* (\S+) (.*)';
        $thirdline = '^\[(\d+):(\d+)\] \*\*\* (\S+) (\S+) (\S+) (\S+) (\S+)(.*)';
    } elsif ($config->{format} eq 'eggdrop') {
        $normalline = '^\[(\d+):\d+\] <([^>]+)> (.*)';
        $actionline = '^\[(\d+):\d+\] Action: (\S+) (.*)';
        $thirdline = '^\[(\d+):(\d+)\] (\S+) (\S+) (\S+) (\S+)(.*)';
    } elsif ($config->{format} eq 'bxlog') {
        $normalline = '^\[\d+ \S+\/(\d+):\d+\] <([^>]+)> (.*)';
        $actionline = '^\[\d+ \S+\/(\d+):\d+\] \* (\S+) (.*)';
        $thirdline = '^\[\d+ \S+\/(\d+):(\d+)\] ([<>@!]) (.*)';
    } elsif ($config->{format} eq 'grufti') {
        $normalline = '^\[(\d+):\d+\] <([^>]+)> (.*)';
        $actionline = '^\[(\d+):\d+\] \* (\S+) (.*)';
        $thirdline = '^\[(\d+):(\d+)\] (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)(.*)';

    } else {
        die("Logfile format not supported, check \$config->{format} setting.\n");
    }

}

sub init_config
{

    if (open(CONFIG, $config->{configfile})) {

        my $lineno = 0;
        while (<CONFIG>)
        {
            $lineno++;
            my $line = $_;
            next if /^#/;

            if ($line =~ /<user.*>/) {
                my $nick;

                if ($line =~ /nick="([^"]+)"/) {
                    $nick = $1;
                } else {
                    print STDERR "Warning: no nick specified in $config->{configfile} on line $lineno\n";
                    next;
                }

                if ($line =~ /alias="([^"]+)"/) {
                    my @thisalias = split(/\s+/, $1);
                    push(@{ $alias{$nick} }, @thisalias);
                }

                if ($line =~ /pic="([^"]+)"/) {
                    $userpics{$nick} = $1;
                }

                if ($line =~ /link="([^"]+)"/) {
                    $userlinks{$nick} = $1;
                }

                if ($line =~ /ignore="Y"/i) {
                    push(@ignore, $nick);
                }

            } elsif ($line =~ /<settings(.*)>/) {

                my $settings = $1;
                while ($settings =~ s/[ \t]([^=]+)=["']([^"']*)["']//) {
					my $vars = $1;
					my $keys = $2;
					while ($vars =~ s/([A-Z])/\l$1/s) {
						$config->{$vars} = $keys;
					}
                    $config->{$1} = $2;
                    debug("Conf: $1 = $2");
                }

            }

        }

        close(CONFIG);
    }

}

sub init_debug
{
    if ($config->{debug}) {
        print "[ Debugging => $config->{debugfile} ]\n";
        open(DEBUG,"> $config->{debugfile}") or print STDERR "$0: Unable to open debug
        file($config->{debugfile}): $!\n";
        debug("*** pisg debug file for $config->{logfile}\n");

    }
}

sub parse_dir
{
    print "Going into $config->{logdir} and parsing all files there...\n\n";
    my $files = `ls $config->{logdir}`;

    my @filesarray = split(/\n/, $files);

    # Add trailing slash when it's not there..
    if (substr($config->{logdir}, -1) ne '/') {
        $config->{logdir} =~ s/(.*)/$1\//;
    }

    foreach my $file (@filesarray) {
        if ($config->{prefix} eq "" || $file =~ /^$config->{prefix}/) {
            $file = $config->{prefix} . $file;
            parse_file($file);
        }
    }

}

sub parse_file
{
    my $file = shift;

    # This parses the file..
    print "Analyzing log($file) in '$config->{format}' format...\n";

    if ($file =~ /.bz$/ || $file =~ /.bz2$/) {
        open (LOGFILE, "bunzip2 -c $file |") or die("$0: Unable to open logfile($file): $!\n");
    } elsif ($file =~ /.gz$/) {
        open (LOGFILE, "gunzip -c $file |") or die("$0: Unable to open logfile($file): $!\n");
    } else {
        open (LOGFILE, $file) or die("$0: Unable to open logfile($file): $!\n");
    }

    while($line = <LOGFILE>) {
        $lines++; # Increment number of lines.

        $line = strip_mirccodes($line);

        my $hashref;

        # Match normal lines.
        if ($hashref = parse_normalline($line)) {

            my ($hour, $nick, $saying, $i);

            for ($i = 0; $i <= $repeated; $i++) {

                if ($i > 0) {
                    $hashref = parse_normalline($lastnormal);
                    $lines++; #Increment number of lines for repeated lines
                }


                $hour = $hashref->{hour};
                $nick = find_alias($hashref->{nick});
                $saying = $hashref->{saying};

                # Timestamp collecting
                $times{$hour}++;

                unless (grep /^\Q$nick\E$/i, @ignore) {
                    $normals++;
                    $line{$nick}++;

                    # Count up monologues

                    if ($lastline eq $nick) {
                        $mono{$nick}++;

                        if ($mono{$nick} == "5") {
                            $monologue{$nick}++;
                            $mono{$nick} = 0;
                        }
                    } else {
                        $mono{$nick} = 0;
                    }

                    $lastline = $nick;

                    my $l = length($saying);

                    if ($l > $config->{minquote} && $l < $config->{maxquote}) {
                        # Creates $hash{nick}[n] - a hash of an array.
                        push (@{ $sayings{$nick} }, htmlentities($saying));
                        $longlines{$nick}++;
                    }

                    $question{$nick}++
                        if ($saying =~ /\?/);

                    $loud{$nick}++
                        if ($saying =~ /!/);

                    $foul{$nick}++
                        if ($saying =~ /ass|fuck|bitch|shit|scheisse|scheiße|kacke|arsch|ficker|ficken|schlampe/);

                    # Who smiles the most?
                    # A regex matching al lot of smilies

                    $smile{$nick}++
                        if ($saying =~ /[8;:=][ ^-o]?[)pPD}\]>]/);
                    $sadface{$nick}++
                        if ($saying =~ /[8;:=][ ^-]?[\(\[\\\/{]/);

                    # Don't count http:// as a :/ face
                    $sadface{$nick}--
                        if ($saying =~ /\w+:\/\//);

                    foreach my $word (split(/[\s,!?.:;)(]+/, $saying)) {
                        # remove uninteresting words
                        next unless (length($word) > $config->{wordlength});
                        # ignore contractions
                        next if ($word =~ m/'..?$/);

                        $wordcount{htmlentities($word)}++ unless (grep /^\Q$word\E$/i, @ignore);
                        $lastused{htmlentities($word)} = $nick;
                    }


                    $length{$nick} += $l;
                    $totallength += $l;
                }
            }
            $lastnormal = $line;
            $repeated = 0;
        }

        # Match action lines.
        elsif ($hashref = parse_actionline($line)) {

            my ($hour, $nick, $saying);

            $hour = $hashref->{hour};
            $nick = find_alias($hashref->{nick});
            $saying = $hashref->{saying};

            # Timestamp collecting
            $times{$hour}++;

            unless (grep /^\Q$nick\E$/i, @ignore) {
                $actions++;
                $line{$nick}++;

                my $len = length($saying);
                $length{$nick} += $len;
                $totallength += $len;
            }
        }

        # Match *** lines.
        elsif (($hashref = parse_thirdline($line)) && $hashref->{nick}) {

            my ($hour, $min, $nick, $kicker, $newtopic, $newmode, $newjoin, $newnick);

            $hour = $hashref->{hour};
            $min = $hashref->{min};
            $nick = find_alias($hashref->{nick});
            $kicker = $hashref->{kicker};
            $newtopic = $hashref->{newtopic};
            $newmode = $hashref->{newmode};
            $newjoin = $hashref->{newjoin};
            $newnick = $hashref->{newnick};

            # Timestamp collecting
            $times{$hour}++;

            unless (grep /^\Q$nick\E$/i, @ignore) {

                if (defined($kicker)) {
                    unless (grep /^\Q$kicker\E$/i, @ignore) {
                        $gotkick{$nick}++;
                        $kicked{$kicker}++;
                    }
                } elsif (defined($newtopic)) {
                    my $tcount = @topics;

                    $topics[$tcount]{topic} = htmlentities($newtopic);
                    $topics[$tcount]{nick} = $nick;
                    $topics[$tcount]{hour} = $hour;
                    $topics[$tcount]{min} = $min;

                    # Strip off the quotes (')
                    $topics[$tcount]{topic} =~ s/^\'(.*)\'$/$1/;
                } elsif (defined($newmode)) {
                    my @opchange = opchanges($newmode);
                    unless (exists $gaveop{$nick}) { $gaveop{$nick} = 0 }
                    $gaveop{$nick} += $opchange[0] if $opchange[0];
                    $tookop{$nick} += $opchange[1] if $opchange[1];
                } elsif (defined($newjoin)) {
                    $joins{$nick}++;
                } elsif (defined($newnick) && ($config->{nicktracking} == 1)) {
                    if (find_alias($newnick) eq $newnick) {
                        if (defined($alias{$nick}) && !defined($alias{$newnick})) {
                            push (@{$alias{$nick}}, $newnick);
                        } elsif (defined($alias{$newnick}) && !defined($alias{$nick})) {
                            push (@{$alias{$newnick}}, $nick);
                        } elsif ($nick =~ /Guest/) {
                            push (@{$alias{$newnick}}, ($newnick, $nick));
                        } else {
                            push (@{$alias{$nick}}, ($nick, $newnick));
                        }
                    }
                }

            }

            if ($hour < $oldtime) { $days++ }
            $oldtime = $hour;

        }
    }

    close(LOGFILE);

    my ($sec,$min,$hour) = gmtime(time - $^T);
    $processtime = sprintf("%02d hours, %02d minutes and %02d seconds", $hour,  $min, $sec);

    $nicks = scalar keys %line;

    print "Finished analyzing log, $days days total.\n";
}


# Here is the 3 parse sub routines, their function is to return a hash with
# the elements in the line. This is where we add the format dependent stuff.
sub parse_normalline
{
    # Parse a normal line - returns a hash with 'hour', 'nick' and 'saying'
    my $line = shift;
    my %hash;

    if ($line =~ /$normalline/) {
        debug("[$lines] Normal: $1 $2 $3");

        if (($config->{format} eq 'mIRC') || ($config->{format} eq 'xchat') || ($config->{format} eq
        'eggdrop') || ($config->{format} eq 'bxlog') || ($config->{format} eq 'grufti')) {

            $hash{hour} = $1;
            $hash{nick} = $2;
            $hash{saying} = $3;

        } else {
            die("Format not supported?!\n");
        }

        return \%hash;

    } else {
        return;
    }
}

sub parse_actionline
{
    # Parse an action line - returns a hash with 'hour', 'nick' and 'saying'
    my $line = shift;
    my %hash;

    if ($line =~ /$actionline/) {
        debug("[$lines] Action: $1 $2 $3");

        if (($config->{format} eq 'mIRC') || ($config->{format} eq 'xchat') || ($config->{format} eq
        'eggdrop') || $config->{format} eq 'bxlog' || ($config->{format} eq 'grufti')) {

            $hash{hour} = $1;
            $hash{nick} = $2;
            $hash{saying} = $3;

        } else {
            die("Format not supported?!\n");
        }

        return \%hash;

    } else {
        return;
    }
}

sub parse_thirdline
{
    # Parses the 'third' line - (the third line is everything else, like
    # topic changes, mode changes, kicks, etc.)
    # parse_thirdline() have to return a hash with the following keys, for
    # every format:
    #   hour            - the hour we're in (for timestamp loggin)
    #   min             - the minute we're in (for timestamp loggin)
    #   nick            - the nick
    #   kicker          - the nick which were kicked (if any)
    #   newtopic        - the new topic (if any)
    #   newmode         - a deop or an op, must be '+o' or '-o'
    #   newjoin         - a new nick which has joined the channel
    #   newnick         - a person has changed nick and this is the new nick
    my $line = shift;
    my %hash;

    if ($line =~ /$thirdline/) {
        if ($7) {
          debug("[$lines] ***: $1 $2 $3 $4 $5 $6 $7");
        } elsif ($5) {
          debug("[$lines] ***: $1 $2 $3 $4 $5 $6");
        } else {
          debug("[$lines] ***: $1 $2 $3 $4");
        }


        if ($config->{format} eq 'mIRC') {
            $hash{hour} = $1;
            $hash{min} = $2;
            $hash{nick} = $3;

            if (($4.$5) eq 'waskicked') {
                $hash{kicker} = $7;

            } elsif (($4.$5) eq 'changestopic') {
                $hash{newtopic} = "$7 $8";

            } elsif (($4.$5) eq 'setsmode:') {
                $hash{newmode} = $6;

            } elsif (($4.$5) eq 'hasjoined') {
                $hash{newjoin} = $3;

            } elsif (($4.$5) eq 'nowknown') {
                $hash{newnick} = $8;
            }


        } elsif ($config->{format} eq 'xchat') {
            $hash{hour} = $1;
            $hash{min} = $2;
            $hash{nick} = $3;

            if (($4.$5) eq 'haskicked') {
                $hash{kicker} = $3;
                $hash{nick} = $6;

            } elsif (($4.$5) eq 'haschanged') {
                $hash{newtopic} = $9;

            } elsif (($4.$5) eq 'giveschannel') {
                $hash{newmode} = '+o';

            } elsif (($4.$5) eq 'removeschannel') {
                $hash{newmode} = '-o';

            } elsif (($5.$6) eq 'hasjoined') {
                $hash{newjoin} = $1;

            } elsif (($5.$6) eq 'nowknown') {
                $hash{newnick} = $8;
            }

        } elsif ($config->{format} eq 'eggdrop') {
            $hash{hour} = $1;
            $hash{min} = $2;
            $hash{nick} = $3;

            if (($4.$5) eq 'kickedfrom') {
                $7 =~ /^ by ([\S]+):.*/;
                $hash{kicker} = $1;

            } elsif ($3 eq 'Topic') {
                $7 =~ /^ by ([\S]+)![\S]+: (.*)/;
                $hash{nick} = $1;
                $hash{newtopic} = $2;

            } elsif (($4.$5) eq 'modechange') {
                $hash{newmode} = $6;
                $7 =~ /^ .+ by ([\S]+)!.*/;
                $hash{nick} = $1;
                $hash{newmode} =~ s/^\'//;

            } elsif ($5 eq 'joined') {
                $hash{newjoin} = $3;

            } elsif (($3.$4) eq 'Nickchange:') {
                $hash{nick} = $5;
                $7 =~ /([\S]+)/;
                $hash{newnick} = $1;

            } elsif (($3.$4.$5) eq 'Lastmessagerepeated') {
                $repeated = $6;
            }

        } elsif ($config->{format} eq 'bxlog') {
            $hash{hour} = $1;
            $hash{min} = $2;

            if ($3 eq '<') {
                if  ($4 =~ /^([^!]+)!([\S+]) was kicked off (\S+) by ([^!]+)!(\S+) \(([^)]+)\)$/) {
                    $hash{kicker} = $4;
                    $hash{nick} = $1;
                }

            } elsif ($3 eq '>') {
                if ($4 =~ /^([^!])+!(\S+) has joined (\S+)$/) {
                    $hash{nick} = $1;
                    $hash{newjoin} = $1;
                }

            } elsif ($3 eq '@') {
                if ($4 =~ /^Topic by ([^!:])[!:]*: (.*)$/) {
                    $hash{nick} = $1;
                    $hash{newtopic} = $2;

                } elsif ($4 =~ /^mode (\S+) \[([+-]o)\S* (\S+)[^\]]*\] by ([^!]+)!(\S+)$/) {
                    $hash{newmode} = $2;
                    $hash{nick} = $4;
                }

            } elsif ($3 eq '!') {
                if ($4 =~ /^(\S+) is known as (\S+)$/) {
                  $hash{nick} = $1;
                  $hash{newnick} = $2;
                }
            }

        } elsif ($config->{format} eq 'grufti') {
            $hash{hour} = $1;
            $hash{min} = $2;
            $hash{nick} = $3;

            if ($5 eq 'kicked') {
                $hash{kicker} = $3;
                $hash{nick} = $6;

            } elsif (($4.$5) eq 'haschanged') {
                $hash{newtopic} = $9;

            } elsif (($4.$5) eq 'modechange') {
                $hash{newmode} = substr($6, 1);
                $hash{nick} = substr($9, 1);

            } elsif ($5 eq 'joined') {
                $hash{newjoin} = $1;

            } elsif (($3.$4) eq 'Nickchange') {
                $hash{nick} = $7;
                $hash{newnick} = $9;
            }

        } else {
            die("Format not supported?!\n");
        }

        return \%hash;

    } else {
        return;
    }
}


sub opchanges
{
    my @modes = split(//, $_[0]);
    my ($mode,$plus)        = ("",0);
    my ($gaveop,$tookop)    = (0,0);

    foreach (@modes) {
        if    (/^\+$/) { $plus  = 1; next; }
        elsif (/^-$/)  { $plus  = 0; next; }
        else  { next unless /^o$/ }

        if ($plus) { $gaveop++ } else { $tookop++ }
    }

    my @out = ($gaveop,$tookop);
    return @out;
}

sub strip_mirccodes
{
    my $line = shift;

    my $boldcode = chr(2);
    my $colorcode = chr(3);
    my $plaincode = chr(15);
    my $reversecode = chr(22);
    my $underlinecode = chr(31);

    # Strip mIRC color codes
    $line =~ s/$colorcode\d{1,2},\d{1,2}//g;
    $line =~ s/$colorcode\d{0,2}//g;
    # Strip mIRC bold, plain, reverse and underline codes
    $line =~ s/[$boldcode$underlinecode$reversecode$plaincode]//g;

    return $line;
}

sub htmlentities
{
    my $str = shift;

    $str =~ s/\&/\&amp;/g;
    $str =~ s/\</\&lt;/g;
    $str =~ s/\>/\&gt;/g;

    return $str;
}

sub html
{
    my $html = shift;
    print OUTPUT $html . "\n";
}

sub template_text
{
    # This function is for the homemade template system. It receives a name
    # of a template and a hash with the fields in the template to update to
    # its corresponding value
    my $template = shift;
    my %hash = @_;

    my $text;

    if (!$T{$config->{lang}}{$template}) {
        # Fall back to English if the language template doesn't exist
        $text = $T{EN}{$template};
    }

    $text = $T{$config->{lang}}{$template};

    if (!$text) {
        die("No such template $template\n");
    }

    foreach my $key (sort keys %hash) {
        $text =~ s/\[:$key\]/$hash{$key}/;
        $text =~ s/ü/&uuml;/g;
        $text =~ s/ö/&ouml;/g;
        $text =~ s/ä/&auml;/g;
        $text =~ s/ß/&szlig;/g;
        $text =~ s/å/&aring;/g;
        $text =~ s/æ/&aelig;/g;
        $text =~ s/ø/&oslash;/g;
    }

    return $text;

}


sub replace_links
{
    # Sub to replace urls and e-mail addys to links
    my $str = shift;
    my $nick = shift;

    if ($nick) {
        $str =~ s/(http|https|ftp|telnet|news)(:\/\/[-a-zA-Z0-9_]+.[-a-zA-Z0-9.,_~=:;&@%?#\/+]+)/<a href="$1$2" target="_blank" title="Open in new window: $1$2">$nick<\/a>/g;
        $str =~ s/([-a-zA-Z0-9._]+@[-a-zA-Z0-9_]+.[-a-zA-Z0-9._]+)/<a href="mailto:$1" title="Mail to $nick">$nick<\/a>/g;
    } else {
        $str =~ s/(http|https|ftp|telnet|news)(:\/\/[-a-zA-Z0-9_]+.[-a-zA-Z0-9.,_~=:;&@%?#\/+]+)/<a href="$1$2" target="_blank" title="Open in new window: $1$2">$1$2<\/a>/g;
        $str =~ s/([-a-zA-Z0-9._]+@[-a-zA-Z0-9_]+.[-a-zA-Z0-9._]+)/<a href="mailto:$1" title="Mail to $1">$1<\/a>/g;
    }


    return $str;

}

sub debug
{
    if ($config->{debug}) {
        my $debugline = $_[0] . "\n";
        print DEBUG $debugline;
    }
}

sub find_alias
{
    my $nick = shift;

    foreach (keys %alias) {
        return $_ if (grep /^\Q$nick\E$/i, @{$alias{$_}});
    }

    return $nick;
}

sub create_html
{

    # This is where all subroutines get executed, you can actually design
    # your own layout here, the lines should be self-explainable

    print "Now generating HTML($config->{outputfile})...\n";

    open (OUTPUT, "> $config->{outputfile}") or die("$0: Unable to open outputfile($config->{outputfile}): $!\n");

    htmlheader();
    pageheader();
    activetimes();
    activenicks();

    headline(template_text('bignumtopic'));
    html("<table width=\"614\">\n"); # Needed for sections
    questions();
    loudpeople();
    mostsmiles();
    mostsad();
    longlines();
    shortlines();
    html("</table>"); # Needed for sections

    mostusedword();

    mostreferenced();

    headline(template_text('othernumtopic'));
    html("<table width=\"614\">\n"); # Needed for sections
    gotkicks();
    mostkicks();
    mostop();
    mostmonologues();
    mostjoins();
    mostfoul();
    html("</table>"); # Needed for sections

    headline(template_text('latesttopic'));
    html("<table width=\"614\">\n"); # Needed for sections
    lasttopics();
    html("</table>"); # Needed for sections

    my %hash = ( lines => $lines );
    html(template_text('totallines', %hash) . "<br><br>");

    htmlfooter();

    close(OUTPUT);

}


sub activetimes
{
    # The most actives times on the channel

    my (%output, $tbgcolor);

    &headline(template_text('activetimestopic'));

    my @toptime = sort { $times{$b} <=> $times{$a} } keys %times;

    my $highest_value = $times{$toptime[0]};

    my @now = localtime($timestamp);

    my $image;

    for my $hour (sort keys %times) {
        debug("Time: $hour => ". $times{$hour});
        if ($toptime[0] == $hour) {
            $image = $config->{pic2};
        } else {
            $image = $config->{pic1};
        }

        my $size = ($times{$hour} / $highest_value) * 100;
        my $percent = ($times{$hour} / $lines) * 100;
        $percent =~ s/(\.\d)\d+/$1/;

        if ($config->{timeoffset} =~ /\+(\d+)/) {
            # We must plus some hours to the time
            $hour += $1;
            $hour = $hour % 24;
            if ($hour < 10) { $hour = "0" . $hour; }

        } elsif ($config->{timeoffset} =~ /-(\d+)/) {
            # We must remove some hours from the time
            $hour -= $1;
            $hour = $hour % 24;
            if ($hour < 10) { $hour = "0" . $hour; }
        }

        $output{$hour} = "<td align=\"center\" valign=\"bottom\" class=\"asmall\">$percent%<br><img src=\"$image\" width=\"15\" height=\"$size\" alt=\"$percent\"></td>\n";
    }

    html("<table border=\"0\" width=\"614\"><tr>\n");

    for ($b = 0; $b < 24; $b++) {
        if ($b < 10) { $a = "0" . $b; } else { $a = $b; }

        if (!defined($output{$a}) || $output{$a} eq "") {
            html("<td align=\"center\" valign=\"bottom\" class=\"asmall\">0%</td>");
        } else {
            html($output{$a});
        }
    }

    html("</tr><tr>");

    for ($b = 0; $b < 24; $b++) {
        if ($now[2] == $b) { $tbgcolor = "\#AAAAAA"; } else { $tbgcolor = "\#CCCCCC"; }
        html("<td bgcolor=\"$tbgcolor\" align=\"center\" class=\"small\">$b</td>");
}

    html("</tr></table>");
}

sub activenicks
{
    # The most active nicks (those who wrote most lines)

    headline(template_text('activenickstopic'));

    html("<table border=\"0\" width=\"614\"><tr>");
    html("<td>&nbsp;</td><td bgcolor=\"$config->{tdtop}\"><b>" . template_text('nick') . "</b></td><td bgcolor=\"$config->{tdtop}\"><b>" . template_text('numberlines') ."</b></td><td bgcolor=\"$config->{tdtop}\"><b>". template_text('randquote') ."</b></td>");
    if (%userpics) {
        html("<td bgcolor=\"$config->{tdtop}\"><b>" . template_text('userpic') ."</b></td>");
    }

    html("</tr>");

    my @active = sort { $line{$b} <=> $line{$a} } keys %line;

    if ($config->{activenicks} > $nicks) {
        $config->{activenicks} = $nicks;
        print "Note: There was less nicks in the logfile than your specificied there to be in most active nicks...\n";
    }

    my ($nick, $visiblenick, $randomline);
    my $i = 1;
    for (my $c = 0; $c < $config->{activenicks}; $c++) {
        $nick = $active[$c];
        $visiblenick = $active[$c];

        if (!$longlines{$nick}) {
            $randomline = "";
        } else {
            my $rand = rand($longlines{$nick});
            $randomline = $sayings{$nick}[$rand];
        }

        # Convert URLs and e-mail addys to links
        $randomline = replace_links($randomline);

        # Add a link to the nick if there is any
        if ($userlinks{$nick}) {
            $visiblenick = replace_links($userlinks{$nick}, $nick);
        }

        my $h = $config->{hicell};
        $h =~ s/^#//;
        $h = hex $h;
        my $h2 = $config->{hicell2};
        $h2 =~ s/^#//;
        $h2 = hex $h2;
        my $f_b = $h & 0xff;
        my $f_g = ($h & 0xff00) >> 8;
        my $f_r = ($h & 0xff0000) >> 16;
        my $t_b = $h2 & 0xff;
        my $t_g = ($h2 & 0xff00) >> 8;
        my $t_r = ($h2 & 0xff0000) >> 16;
        my $col_b  = sprintf "%0.2x", abs int(((($t_b - $f_b) / $config->{activenicks}) * +$c) + $f_b);
        my $col_g  = sprintf "%0.2x", abs int(((($t_g - $f_g) / $config->{activenicks}) * +$c) + $f_g);
        my $col_r  = sprintf "%0.2x", abs int(((($t_r - $f_r) / $config->{activenicks}) * +$c) + $f_r);


        html("<tr><td bgcolor=\"$config->{rankc}\" align=\"left\">");
        my $line = $line{$nick};
        html("$i</td><td bgcolor=\"#$col_r$col_g$col_b\">$visiblenick</td><td bgcolor=\"#$col_r$col_g$col_b\">$line</td><td bgcolor=\"#$col_r$col_g$col_b\">");
        html("\"$randomline\"</td>");

        if ($userpics{$nick}) {
            html("<td bgcolor=\"#$col_r$col_g$col_b\" align=\"center\"><img valign=\"middle\" src=\"$config->{imagepath}$userpics{$nick}\"></td>");
        }

        html("</tr>");
        $i++;
    }

    html("</table><br>");

    # Almost as active nicks ('These didn't make it to the top..')

    my $nickstoshow = $config->{activenicks} + $config->{activenicks2};

    unless ($nickstoshow > $nicks) {

        html("<br><b><i>" . template_text('nottop') . "</i></b><table><tr>");
        for (my $c = $config->{activenicks}; $c < $nickstoshow; $c++) {
            unless ($c % 5) { unless ($c == $config->{activenicks}) { html("</tr><tr>"); } }
            html("<td bgcolor=\"$config->{rankc}\" class=\"small\">");
            my $nick = $active[$c];
            my $lines = $line{$nick};
            html("$nick ($lines)</td>");
        }

        html("</table>");
    }


}

sub mostusedword
{
    # Lao the infamous word usage statistics
    my %usages;

    foreach my $word (sort keys %wordcount) {
        next if exists $line{$word};
        $usages{$word} = $wordcount{$word};
    }


    my @popular = sort { $usages{$b} <=> $usages{$a} } keys %usages;

    if (@popular) {
        &headline(template_text('mostwordstopic'));

        html("<table border=\"0\" width=\"614\"><tr>");
        html("<td>&nbsp;</td><td bgcolor=\"$config->{tdtop}\"><b>" . template_text('word') . "</b></td>");
        html("<td bgcolor=\"$config->{tdtop}\"><b>" . template_text('numberuses') . "</b></td>");
        html("<td bgcolor=\"$config->{tdtop}\"><b>" . template_text('lastused') . "</b></td>");


        for(my $i = 0; $i < 10; $i++) {
            last unless $i < $#popular;
            my $a = $i + 1;
            my $popular = $popular[$i];
            my $wordcount = $wordcount{$popular[$i]};
            my $lastused = $lastused{$popular[$i]};
            html("<tr><td bgcolor=\"$config->{rankc}\"><b>$a</b>");
            html("<td bgcolor=\"$config->{hicell}\">$popular</td>");
            html("<td bgcolor=\"$config->{hicell}\">$wordcount</td>");
            html("<td bgcolor=\"$config->{hicell}\">$lastused</td>");
            html("</tr>");
       }

       html("</table>");
   }

}


sub mostreferenced
{
    my %usages;

    foreach my $word (sort keys %wordcount) {
        next unless exists $line{$word};
        $usages{$word} = $wordcount{$word};
    }

    my @popular = sort { $usages{$b} <=> $usages{$a} } keys %usages;

    if (@popular) {

        &headline(template_text('referencetopic'));

        html("<table border=\"0\" width=\"614\"><tr>");
        html("<td>&nbsp;</td><td bgcolor=\"$config->{tdtop}\"><b>" . template_text('nick') . "</b></td>");
        html("<td bgcolor=\"$config->{tdtop}\"><b>" . template_text('numberuses') . "</b></td>");
        html("<td bgcolor=\"$config->{tdtop}\"><b>" . template_text('lastused') . "</b></td>");

       for(my $i = 0; $i < 5; $i++) {
           last unless $i < $#popular;
           my $a = $i + 1;
           my $popular = $popular[$i];
           my $wordcount = $wordcount{$popular[$i]};
           my $lastused = $lastused{$popular[$i]};
           html("<tr><td bgcolor=\"$config->{rankc}\"><b>$a</b>");
           html("<td bgcolor=\"$config->{hicell}\">$popular</td>");
           html("<td bgcolor=\"$config->{hicell}\">$wordcount</td>");
           html("<td bgcolor=\"$config->{hicell}\">$lastused</td>");
           html("</tr>");
       }
   html("</table>");
   }

}

sub questions
{
    # Persons who asked the most questions

    foreach my $nick (sort keys %question) {
        if ($line{$nick} > 100) {
            $qpercent{$nick} = ($question{$nick} / $line{$nick}) * 100;
            $qpercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @question = sort { $qpercent{$b} <=> $qpercent{$a} } keys %qpercent;

    if (@question) {
        my %hash = (
            nick => $question[0],
            per => $qpercent{$question[0]}
        );

        my $text = template_text('question1', %hash);
        html("<tr><td bgcolor=\"$config->{hicell}\">$text");
        if (@question >= 2) {
            my %hash = (
                nick => $question[1],
                per => $qpercent{$question[1]}
            );

            my $text = template_text('question2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");

    } else {
        html("<tr><td bgcolor=\"$config->{hicell}\">" . template_text('question3') . "</td></tr>");
    }
}

sub loudpeople
{
    # The ones who speak LOUDLY!

    foreach my $nick (sort keys %loud) {
        if ($line{$nick} > 100) {
            $lpercent{$nick} = ($loud{$nick} / $line{$nick}) * 100;
            $lpercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @loud = sort { $lpercent{$b} <=> $lpercent{$a} } keys %lpercent;

    if (@loud) {
        my %hash = (
            nick => $loud[0],
            per => $lpercent{$loud[0]}
        );

        my $text = template_text('loud1', %hash);
        html("<tr><td bgcolor=\"$config->{hicell}\">$text");
        if (@loud >= 2) {
            my %hash = (
                nick => $loud[1],
                per => $lpercent{$loud[1]}
            );

            my $text = template_text('loud2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");

    } else {
        my $text = template_text('loud3');
        html("<tr><td bgcolor=\"$config->{hicell}\">$text</td></tr>");
    }

}

sub gotkicks
{
    # The persons who got kicked the most

    my @gotkick = sort { $gotkick{$b} <=> $gotkick{$a} } keys %gotkick;

    if (@gotkick) {
        my %hash = (
            nick => $gotkick[0],
            kicks => $gotkick{$gotkick[0]}
        );

        my $text = template_text('gotkick1', %hash);

        html("<tr><td bgcolor=\"$config->{hicell}\">$text");
        if (@gotkick >= 2) {
            my %hash = (
                nick => $gotkick[1],
                kicks => $gotkick{$gotkick[1]}
            );

            my $text = template_text('gotkick2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");
    }
}

sub mostjoins
{

    my @joins = sort { $joins{$b} <=> $joins{$a} } keys %joins;

    if (@joins) {
        my %hash = (
            nick => $joins[0],
            joins => $joins{$joins[0]}
        );

        my $text = template_text('joins', %hash);

        html("<tr><td bgcolor=\"$config->{hicell}\">$text</td></tr>");
    }
}


sub mostkicks
{
     # The person who got kicked the most

     my @kicked = sort { $kicked{$b} <=> $kicked{$a} } keys %kicked;

     if (@kicked) {
         my %hash = (
             nick => $kicked[0],
             kicked => $kicked{$kicked[0]}
         );

         my $text = template_text('kick1', %hash);
         html("<tr><td bgcolor=\"$config->{hicell}\">$text");

         if (@kicked >= 2) {
         my %hash = (
             oldnick => $kicked[0],
             nick => $kicked[1],
             kicked => $kicked{$kicked[1]}
         );

         my $text = template_text('kick2', %hash);
             html("<br><span class=\"small\">$text</span>");
         }
         html("</td></tr>");
     } else {
         my $text = template_text('kick3');
         html("<tr><td bgcolor=\"$config->{hicell}\">$text</td></tr>");
     }

}

sub mostmonologues
{
    # The person who had the most monologues (speaking to himself)

     my @monologue = sort { $monologue{$b} <=> $monologue{$a} } keys %monologue;

     if (@monologue) {
         my %hash = (
             nick => $monologue[0],
             monos => $monologue{$monologue[0]}
         );

         my $text = template_text('mono1', %hash);

         html("<tr><td bgcolor=\"$config->{hicell}\">$text");
         if (@monologue >= 2) {
             my %hash = (
                 nick => $monologue[1],
                 monos => $monologue{$monologue[1]}
             );

             my $text = template_text('mono2', %hash);
             if ($monologue{$monologue[1]} == 1 && $config->{lang} eq 'EN') {
                $text = substr $text, 0, -1;
             }
             html("<br><span class=\"small\">$text</span>");
         }
         html("</td></tr>");
     }
}

sub longlines
{

    my %len;

    # The person(s) who wrote the longest lines

    foreach my $nick (sort keys %length) {
        if ($line{$nick} > 100) {
            $len{$nick} = $length{$nick} / $line{$nick};
            $len{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @len = sort { $len{$b} <=> $len{$a} } keys %len;

    my $all_lines = $normals + $actions;

    my $totalaverage;

    if ($all_lines > 0) {
        $totalaverage = $totallength / $all_lines;
        $totalaverage =~ s/(\.\d)\d+/$1/;
    }

    if (@len) {
        my %hash = (
            nick => $len[0],
            letters => $len{$len[0]}
        );

        my $text = template_text('long1', %hash);
        html("<tr><td bgcolor=\"$config->{hicell}\">$text<br>");

        if (@len >= 2) {
            %hash = (
                channel => $config->{channel},
                avg => $totalaverage
            );

            $text = template_text('long2', %hash);
            html("<span class=\"small\">$text</span></td></tr>");
        }
    }
}

sub shortlines
{
    # This sub should be combined with the longlines sub at some point.. it
    # does basically the same thing.

    my %len;

    # The person(s) who wrote the shortest lines

    foreach my $nick (sort keys %length) {
        if ($line{$nick} > 5) {
            $len{$nick} = $length{$nick} / $line{$nick};
            $len{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @len = sort { $len{$a} <=> $len{$b} } keys %len;

    if (@len) {
        my %hash = (
            nick => $len[0],
            letters => $len{$len[0]}
        );

        my $text = template_text('short1', %hash);
        html("<tr><td bgcolor=\"$config->{hicell}\">$text<br>");

        if (@len >= 2) {
            %hash = (
                nick => $len[1],
                letters => $len{$len[1]}
            );

            $text = template_text('short2', %hash);
            html("<span class=\"small\">$text</span></td></tr>");
        }
    }

}

sub mostfoul
{
    my %spercent;

    foreach my $nick (sort keys %foul) {
        if ($line{$nick} > 15) {
            $spercent{$nick} = ($foul{$nick} / $line{$nick}) * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @foul = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@foul) {

        my %hash = (
            nick => $foul[0],
            per => $spercent{$foul[0]}
        );

        my $text = template_text('foul1', %hash);

        html("<tr><td bgcolor=\"$config->{hicell}\">$text");

        if (@foul >= 2) {
            my %hash = (
                nick => $foul[1],
                per => $spercent{$foul[1]}
            );

            my $text = template_text('foul2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }

       html("</td></tr>");
    } else {
        my %hash = (
            channel => $config->{channel}
        );

        my $text = template_text('foul3', %hash);

        html("<tr><td bgcolor=\"$config->{hicell}\">$text</td></tr>");
    }
}


sub mostsad
{
    my %spercent;

    foreach my $nick (sort keys %sadface) {
        if ($line{$nick} > 100) {
            $spercent{$nick} = ($sadface{$nick} / $line{$nick}) * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @sadface = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@sadface) {
        my %hash = (
            nick => $sadface[0],
            per => $spercent{$sadface[0]}
        );

        my $text = template_text('sad1', %hash);
        html("<tr><td bgcolor=\"$config->{hicell}\">$text");

        if (@sadface >= 2) {
            my %hash = (
                nick => $sadface[1],
                per => $spercent{$sadface[1]}
            );

            my $text = template_text('sad2', %hash);

            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");
    } else {
        my %hash = (
            channel => $config->{channel}
        );
        my $text = template_text('sad3', %hash);
        html("<tr><td bgcolor=\"$config->{hicell}\">$config->text</td></tr>");
    }
}


sub mostop
{
    my @ops = sort { $gaveop{$b} <=> $gaveop{$a} } keys %gaveop;
    my @deops = sort { $tookop{$b} <=> $tookop{$a} } keys %tookop;

    if (@ops) {
        my %hash = (
            nick => $ops[0],
            ops => $gaveop{$ops[0]}
        );

        my $text = template_text('mostop1', %hash);

        html("<tr><td bgcolor=\"$config->{hicell}\">$text");

        if (@ops >= 2) {
            my %hash = (
                nick => $ops[1],
                ops => $gaveop{$ops[1]}
            );

            my $text = template_text('mostop2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");
    } else {
        my %hash = ( channel => $config->{channel} );
        my $text = template_text('mostop3', %hash);
        html("<tr><td bgcolor=\"$config->{hicell}\">$text</td></tr>");
    }
    if (@deops) {
        my %hash = (
            channel => $config->{channel},
            nick => $deops[0],
            deops => $tookop{$deops[0]}
        );
        my $text = template_text('mostdeop1', %hash);

        html("<tr><td bgcolor=\"$config->{hicell}\">$text");

        if (@deops >= 2) {
            my %hash = (
                nick => $deops[1],
                deops => $tookop{$deops[1]}
            );
            my $text = template_text('mostdeop2', %hash);

            html("<br><span class=\"small\">$text</span>");
        }
            html("</td></tr>");
    } else {
        my %hash = ( channel => $config->{channel} );
        my $text = template_text('mostdeop3', %hash);
        html("<tr><td bgcolor=\"$config->{hicell}\">$text");
    }
}

sub mostsmiles
{
    # The person(s) who smiled the most :-)

    my %spercent;

    foreach my $nick (sort keys %smile) {
        if ($line{$nick} > 100) {
            $spercent{$nick} = ($smile{$nick} / $line{$nick}) * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @smiles = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@smiles) {
        my %hash = (
            nick => $smiles[0],
            per => $spercent{$smiles[0]}
        );

        my $text = template_text('smiles1', %hash);

        html("<tr><td bgcolor=\"$config->{hicell}\">$text");
        if (@smiles >= 2) {
            my %hash = (
                nick => $smiles[1],
                per => $spercent{$smiles[1]}
            );

            my $text = template_text('smiles2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");

    } else {
        my %hash = (
            channel => $config->{channel}
        );

        my $text = template_text('smiles3', %hash);
        html("<tr><td bgcolor=\"$config->{hicell}\">$text</td></tr>");
    }
}

sub lasttopics
{
    debug("Total number of topics: ". scalar @topics);

    if (@topics) {
        my $ltopic = @topics - 1;
        my $tlimit = 0;

        $config->{topichistory} -= 1;


        if ($ltopic > $config->{topichistory}) { $tlimit = $ltopic - $config->{topichistory}; }

        for (my $i = $ltopic; $i >= $tlimit; $i--) {
            $topics[$i]{"topic"} = replace_links($topics[$i]{"topic"});
            my $topic = $topics[$i]{topic};
            my $nick = $topics[$i]{nick};
            my $hour = $topics[$i]{hour};
            my $min = $topics[$i]{min};
            html("<tr><td bgcolor=\"$config->{hicell}\"><i>$topic</i></td>");
            html("<td bgcolor=\"$config->{hicell}\">By <b>$nick</b> at <b>$hour:$min</b></td></tr>");
        }
       } else {
            html("<tr><td bgcolor=\"$config->{hicell}\">" . template_text('notopic') ."</td></tr>");
       }
}


# Some HTML subs
sub htmlheader
{
print OUTPUT <<HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>$config->{channel} @ $config->{network} channel statistics</title>
<style type="text/css">
a { text-decoration: none }
a:link { color: $config->{link}; }
a:visited { color: $config->{vlink}; }
a:hover { text-decoration: underline; color: $config->{hlink} }

body {
    background-color: $config->{bgcolor};
    font-family: verdana, arial, sans-serif;
    font-size: 13px;
    color: $config->{text};
}

td {
    font-family: verdana, arial, sans-serif;
    font-size: 13px;
    color: $config->{tdcolor};
}

.title {
    font-family: tahoma, arial, sans-serif;
    font-size: 16px;
    font-weight: bold;
}

.headline { color: $config->{hcolor}; }
.small { font-family: verdana, arial, sans-serif; font-size: 10px; }
.asmall { font-family: arial narrow, sans-serif; font-size: 10px }
</style></head>
<body>
<div align="center">
HTML
my %hash = (
    channel => $config->{channel},
    network => $config->{network},
    maintainer => $config->{maintainer},
    time => $time,
    days => $days,
    nicks => $nicks,
    channel => $config->{channel}
);
print OUTPUT "<span class=\"title\">" . template_text('pagetitle1', %hash) . "</span><br>";
print OUTPUT "<br>" . template_text('pagetitle2', %hash) . "<br>";
print OUTPUT template_text('pagetitle3', %hash) . "<br><br>";

}

sub htmlfooter
{
print OUTPUT <<HTML;
<span class="small">
Stats generated by <a href="http://www.wtf.dk/hp/index.php?page=pisg" title="Go to the pisg homepage">pisg</a> $config->{version}<br>
pisg by <a href="http://www.wtf.dk/hp/" title="Go to the authors homepage">Morten "LostStar" Brix Pedersen</a> and others<br>
Stats generated in $processtime
</span>
</div>
</body>
</html>
HTML
}

sub headline
{
    my ($title) = @_;
print OUTPUT <<HTML;
   <br>
   <table width="610" cellpadding="1" cellspacing="0" border="0">
    <tr>
     <td bgcolor="$config->{headline}">
      <table width="100%" cellpadding="2" cellspacing="0" border="0" align="center">
       <tr>
        <td bgcolor="$config->{hbgcolor}" class="text10">
         <div align="center" class="headline"><b>$title</b></div>
        </td>
       </tr>
      </table>
     </td>
    </tr>
   </table>
HTML
}

sub pageheader
{
    if ($config->{pagehead} ne 'none') {
        open(PAGEHEAD, $config->{pagehead}) or die("$0: Unable to open $config->{pagehead} for reading: $!\n");
        while (<PAGEHEAD>) {
            html($_);
        }
    }
}

sub close_debug
{
    if ($config->{debug}) {
        close(DEBUG) or print STDERR "$0: Cannot close debugfile($config->{debugfile}): $!\n";
    }
}

sub get_cmdlineoptions
{
    my $tmp;
    # Commandline options
    my $help;

my $usage = <<END_USAGE;
Usage: pisg.pl [-c channel] [-l logfile] [-o outputfile] [-m
maintainer]  [-f format] [-n network] [-d logdir] [-a aliasfile]
[-i ignorefile] [-h]

-c --channel=xxx       : Set channel name
-l --logfile=xxx       : Log file to parse
-o --outfile=xxx       : Name of html file to create
-m --maintainer=xxx    : Channel/statistics maintainer
-f --format=xxx        : Logfile format [see FORMATS file]
-n --network=xxx       : IRC Network this channel is on.
-d --dir=xxx           : Analyze all files in this dir. Ignores logfile.
-p --prefix=xxx        : Analyse only files starting with xxx in dir.
                         Only works with --dir
-u --configfile=xxx    : Config file
-h --help              : Output this message and exit (-? also works).

Example:

 \$ pisg.pl -n IRCnet -f xchat -o suid.html -c \\#channel -l logfile.log

As always, all options may also be defined by editing the source and calling
pisg without arguments.

END_USAGE

    if (GetOptions('channel=s'    => \$config->{channel},
                   'logfile=s'    => \$config->{logfile},
                   'format=s'     => \$config->{format},
                   'network=s'    => \$config->{network},
                   'maintainer=s' => \$config->{maintainer},
                   'outfile=s'    => \$config->{outputfile},
                   'dir=s'        => \$config->{logdir},
                   'prefix=s'     => \$config->{prefix},
                   'ignorefile=s' => \$tmp,
                   'aliasfile=s'  => \$tmp,
                   'configfile=s'  => \$config->{configfile},
                   'help|?'       => \$help
               ) == 0 or $help) {
                   die($usage);
               }

    if (@ARGV) {
        if ($ARGV[0]) { $config->{channel} = $ARGV[0]; }
        if ($ARGV[1]) { $config->{logfile} = $ARGV[1]; }
        if ($ARGV[2]) { $config->{outputfile} = $ARGV[2]; }
        if ($ARGV[3]) { $config->{maintainer} = $ARGV[3]; }
    }

    if ($tmp) {
        die("The aliasfile and ignorefile has been obsoleted by the new
        pisg.cfg, please use that instead [look in pisg.cfg]\n");
    }

}

sub get_language_templates
{
    use FindBin;

    open(FILE, $config->{langfile}) or open (FILE, $FindBin::Bin . "/$config->{langfile}") or die("$0: Unable to open language file($config->{langfile}): $!\n");

    my $current_lang;

    while (<FILE>)
    {
        my $line = $_;
        next if /^#/;

        if ($line =~ /<lang name=\"([^"]+)\">/) {
            # Found start tag, setting the current language
            $current_lang = "$1";
        }

        elsif ($line =~ /<\/lang>/) {
            # Found end tag, resetting the current language
            $current_lang = '';
        }
        
        elsif ($line =~ /(\w+) = "(.*)"$/ && $current_lang ne '') {
            $T{$current_lang}{$1} = $2;
        }
    }

    close(FILE);

    print "Using language template: $config->{lang}\n\n" if ($config->{lang} ne 'EN');

}
    
&main();        # Run the script
