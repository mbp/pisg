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

my ($channel, $logfile, $format, $network, $outputfile, $maintainer,
$pagehead, $usersfile, $imagepath, $logdir, $lang, $bgcolor, $text, $hbgcolor,
$hcolor, $hicell, $hicell2, $tdcolor, $tdtop, $link, $vlink, $hlink, $headline,
$rankc, $minquote, $maxquote, $activenicks, $activenicks2, $topichistory,
$nicktracking, $timeoffset, $version, $debug, $debugfile);

# Values that _MUST_ be set below (unless you pass them on commandline)
$channel = "#channel";		# The name of your channel.
$logfile = "channel.log";	# The exact filename of the logfile
$format = "mIRC";		# logfile format. see FORMATS file
$network = "SomeIRCNet";	# Network the channels is using.
$outputfile = "index.html";	# The name of the html file to be generated
$maintainer = "MAINTAINER";	# The maintainer or bot which makes the logfile
$pagehead = "none";		# Some 'page header' file which you want to
				# include in top of the stats

$usersfile = "users.cfg";	# Path to users config file (aliases, ignores,
				# pics and more, see users.cfg for examples)

$imagepath = "";		# If your user pictures is located
				# some special directory, set the path here.

$logdir = "";			# If you specify a path to a dir here, then
				# pisg will take that dir, and parse ALL
				# logfiles in it, and create 1 HTML file
				# from it

$lang = 'EN';			# Language to use, EN | DE | DK | FR

# Here you can set the colors for your stats page..
$bgcolor = "#dedeee";		# Background color of the page
$text = "black";		# Normal text color
$hbgcolor = "#666699";		# Background color in headlines
$hcolor = "white";		# Text color in headline
$hicell = "#BABADD";		# Background color in highlighted cells
$hicell2 = "#CCCCCC";		# Background color in highlighted cells
$tdcolor = "black";		# Color of text in tables
$tdtop = "#C8C8DD";		# Top color in some tables.
$link = "#0b407a";		# Color of links
$vlink = "#0b407a";		# Color of visited links
$hlink = "#0b407a";		# Color of hovered links
$headline = "#000000";		# Border color of headlines
$rankc = "#CCCCCC";             # Colors of 'ranks' (1,2,3,4)

# Other things that you might set, but not everyone cares about them
$minquote = "25";		# Minimal value of letters for a random quote
$maxquote = "65";		# Maximum value of letters for a random quote
$activenicks = "25";		# Number of nicks to show in the 'top 25'
$activenicks2 = "30";		# Nicks to show in 'these didnt make it...'
$topichistory = "3";		# How many topics to show in 'latest topics'
$nicktracking = 0;		# Track nickchanges and create aliases (can
				# be slow, so it's disabled by default)

$timeoffset = "+0";		# A time offset on the stats page - if your
				# country has a different timezone than the
				# machine where the stats are being
				# generated, then for example do +1
				# to add 1 hour to the time

# You shouldn't care about anything below this point
$debug = 0;			# 0 = Debugging off, 1 = Debugging on
$debugfile = "debug.log";	# Path to debug file(must be set if $debug == 1)
$version = "v0.17pre1";

my ($lines, $kicked, $gotkicked, $smile, $longlines, $time, $timestamp, %alias,
$normalline, $actionline, $thirdline, @ignore, $line, $processtime, @topics,
%monologue, %kicked, %gotkick, %line, %length, %qpercent, %lpercent, %sadface,
%smile, $nicks, %longlines, %mono, %times, %question, %loud, $totallength,
%gaveop, %tookop, %joins, %actions, %sayings, %wordcount, %lastused,
$colorcode, $boldcode, $underlinecode, %gotban, %setban, %foul, $days,
$oldtime, $lastline, $actions, $normals, %userpics, %userlinks, %T,
$repeated, $lastnormal);

sub main
{
    init_pisg();        # Init commandline arguments and other things
    init_lineformats(); # Attempt to set line formats in compliance with user specification (--format)

    init_users_config();        # Init users config. (Aliases, ignores etc.)
    init_debug();       # Init the debugging file

    if ($logdir) {
        parse_dir();            # Run through all logfiles in dir
    } else {
        parse_file($logfile);   # Run through the whole logfile
    }

    create_html();      # Create the HTML
                        # (look here if you want to remove some of the
                        # stats which you don't care about)

    close_debug();      # Close the debugging file

    print "\nFile was parsed succesfully in $processtime on $time.\n";
}

sub init_pisg
{
    print "pisg $version - Perl IRC Statistics Generator\n\n";

    get_cmdlineoptions();

    $timestamp = time;

    if ($timeoffset =~ /\+(\d+)/) {
        # We must plus some hours to the time
        $timestamp += 3600 * $1; # 3600 seconds per hour

    } elsif ($timeoffset =~ /-(\d+)/) {
        # We must remove some hours from the time
        $timestamp -= 3600 * $1; # 3600 seconds per hour
    }

    # Set useful values.
    $days = 1;
    $oldtime = "00";
    $lastline = "";
    $actions = "0";
    $normals = "0";
    $colorcode = chr(3);
    $boldcode = chr(2);
    $underlinecode = chr(31);
    $time = localtime($timestamp);
    $repeated = 0;
    $lastnormal = "";

    print "Statistics for channel $channel \@ $network by $maintainer\n\n";
    print "Using language template: $lang\n\n" if ($lang ne 'EN');

}

sub init_lineformats {

    # These are the regular expressions which matches the lines in the logfile,
    # and looks different if it's xchat, mIRC or whatever.
    # If you want to add support for a new format - you first have to add the
    # regex here, and then you also have to modify the parse subroutines called
    # 'parse_normalline()', 'parse_actionline()' and 'parse_thirdline()'

    if ($format eq 'xchat') {
        $normalline = '^(\d+):\d+:\d+ <([^>]+)>\s+(.*)';
        $actionline = '^(\d+):\d+:\d+ \*\s+(\S+) (.*)';
        $thirdline = '^(\d+):(\d+):\d+ .--\s+(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (.*)';
    } elsif ($format eq 'mIRC') {
        $normalline = '^\[(\d+):\d+\] <([^>]+)> (.*)';
        $actionline = '^\[(\d+):\d+\] \* (\S+) (.*)';
        $thirdline = '^\[(\d+):(\d+)\] \*\*\* (\S+) (\S+) (\S+) (\S+) (\S+)(.*)';
    } elsif ($format eq 'eggdrop') {
        $normalline = '^\[(\d+):\d+\] <([^>]+)> (.*)';
        $actionline = '^\[(\d+):\d+\] Action: (\S+) (.*)';
        $thirdline = '^\[(\d+):(\d+)\] (\S+) (\S+) (\S+) (\S+)(.*)';
    } elsif ($format eq 'bxlog') {
        $normalline = '^\[\d+ \w+\/(\d+):\d+\] <([^>]+)> (.*)';
        $actionline = '^\[\d+ \w+\/(\d+):\d+\] \* (\S+) (.*)';
        $thirdline = '^\[\d+ \w+\/(\d+):(\d+)\] \S (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (.*)';
    } elsif ($format eq 'grufti') {
        $normalline = '^\[(\d+):\d+\] <([^>]+)> (.*)';
        $actionline = '^\[(\d+):\d+\] \* (\S+) (.*)';
        $thirdline = '^\[(\d+):(\d+)\] (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)(.*)';
    } else {
        die("Logfile format not supported, check \$format setting.\n");
    }

}

sub init_users_config
{

    if (open(USERS, $usersfile)) {

        my $lineno = 0;
        while (<USERS>)
        {
            $lineno++;
            my $line = $_;
            next if /^#/;

            if ($line =~ /<user.*>/) {
                my $nick;

                if ($line =~ /nick="([^"]+)"/) {
                    $nick = $1;
                } else {
                    print STDERR "Warning: no nick specified in $usersfile on line $lineno\n";
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

            }

        }

        close(USERS);
    }

}

sub init_debug
{
    if ($debug) {
        print "[ Debugging => $debugfile ]\n";
        open(DEBUG,"> $debugfile") or print STDERR "$0: Unable to open debug
        file($debugfile): $!\n";
        debug("*** pisg debug file for $logfile\n");

    }
}

sub parse_dir
{
    print "Going into $logdir and parsing all files there...\n\n";
    my $files = `ls $logdir`;

    my @filesarray = split(/\n/, $files);

    # Add trailing slash when it's not there..
    if (substr($logdir, -1) ne '/') {
        $logdir =~ s/(.*)/$1\//;
    }

    foreach my $file (@filesarray) {
        $file = $logdir . $file;
        parse_file($file);
    }

}

sub parse_file
{
    my $file = shift;

    # This parses the file..
    print "Analyzing log($file) in '$format' format...\n";

    open (LOGFILE, $file) or die("$0: Unable to open logfile($file): $!\n");

    while($line = <LOGFILE>) {
        $lines++; # Increment number of lines.

        # Strip mIRC color codes
        $line =~ s/$colorcode\d{1,2},\d{1,2}//g;
        $line =~ s/$colorcode\d{0,2}//g;
        # Strip mIRC bold and underline codes
        $line =~ s/[$boldcode$underlinecode]//g;

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

                    if ($l > $minquote && $l < $maxquote) {
                        $saying = htmlentities($saying);

                        # Creates $hash{nick}[n] - a hash of an array.
                        push (@{ $sayings{$nick} }, $saying);
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
                        next unless (length($word) > 5);
                        # ignore contractions
                        next if ($word =~ m/'..?$/);

                        $wordcount{$word}++ unless (grep /^\Q$word\E$/i, @ignore);
                        $lastused{$word} = $nick;
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
        elsif ($hashref = parse_thirdline($line)) {

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
                } elsif (defined($newnick) && ($nicktracking == 1)) {
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

        if (($format eq 'mIRC') || ($format eq 'xchat') || ($format eq
        'eggdrop') || ($format eq 'bxlog') || ($format eq 'grufti')) {

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

        if (($format eq 'mIRC') || ($format eq 'xchat') || ($format eq
        'eggdrop') || $format eq 'bxlog' || ($format eq 'grufti')) {

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
        } else {
          debug("[$lines] ***: $1 $2 $3 $4 $5 $6");
        }

        if ($format eq 'mIRC') {
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


        } elsif ($format eq 'xchat') {
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

        } elsif ($format eq 'eggdrop') {
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

        } elsif ($format eq 'bxlog') {
            $hash{hour} = $1;
            $hash{min} = $2;
            $hash{nick} = $3;

            if ($5 eq 'kicked') {
                $hash{kicker} = $9;
                $hash{kicker} =~ s/!.*$//;

            } elsif ($3 eq 'Topic') {
                $hash{nick} = substr($5, 0, -1);
                $hash{newtopic} = "$6 $7 $8 $9 $10";

            } elsif ($5 eq '[+o') {
                $hash{newmode} = '+o';
                $hash{newmode} = substr($6, 0, -1);

            } elsif ($5 eq '[-o') {
                $hash{newmode} = '-o';
                $hash{newmode} = substr($6, 0, -1);

            } elsif (($4.$5) eq 'hasjoined') {
                $hash{newjoin} = $1;

            } elsif (($4.$5) eq 'isknown') {
                $hash{newnick} = $6;
            }

            $hash{nick} =~ s/!.*$//;

        } elsif ($format eq 'grufti') {
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

    if (!$T{$lang}{$template}) {
        # Fall back to English if the language template doesn't exist
        $text = $T{EN}{$template};
    }

    $text = $T{$lang}{$template};

    if (!$text) {
        die("No such template $template\n");
    }

    foreach my $key (sort keys %hash) {
        $text =~ s/\[:$key\]/$hash{$key}/;
        $text =~ s/ü/&uuml;/g;
        $text =~ s/ö/&ouml;/g;
        $text =~ s/ä/&auml;/g;
        $text =~ s/ß/&szlig/g;
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
    if ($debug) {
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

    print "Now generating HTML($outputfile)...\n";

    open (OUTPUT, "> $outputfile") or die("$0: Unable to open outputfile($outputfile): $!\n");

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

    my $image = "pipe-blue.png";

    for my $hour (sort keys %times) {
        debug("Time: $hour => ". $times{$hour});

        if ($toptime[0] == $hour) {
            $image = "pipe-purple.png";
        } 

        my $size = ($times{$hour} / $highest_value) * 100;
        my $percent = ($times{$hour} / $lines) * 100;
        $percent =~ s/(\.\d)\d+/$1/;

        if ($timeoffset =~ /\+(\d+)/) {
            # We must plus some hours to the time
            $hour += $1;
            $hour = $hour % 24;
            if ($hour < 10) { $hour = "0" . $hour; }

        } elsif ($timeoffset =~ /-(\d+)/) {
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

    my $randomline;

    &headline(template_text('activenickstopic'));

    html("<table border=\"0\" width=\"614\"><tr>");
    html("<td>&nbsp;</td><td bgcolor=\"$tdtop\"><b>" . template_text('nick') . "</b></td><td bgcolor=\"$tdtop\"><b>" . template_text('numberlines') ."</b></td><td bgcolor=\"$tdtop\"><b>". template_text('randquote') ."</b></td>");
    if (%userpics) {
        html("<td bgcolor=\"$tdtop\"><b>" . template_text('userpic') ."</b></td>");
    }

    html("</tr>");

    my @active = sort { $line{$b} <=> $line{$a} } keys %line;

    if ($activenicks > $nicks) {
        $activenicks = $nicks;
        print "Note: There was less nicks in the logfile than your specificied there to be in most active nicks...\n";
    }

    my ($nick, $visiblenick);
    my $i = 1;
    for (my $c = 0; $c < $activenicks; $c++) {
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

        my $h = $hicell;
        $h =~ s/^#//;
        $h = hex $h;
        my $h2 = $hicell2;
        $h2 =~ s/^#//;
        $h2 = hex $h2;
        my $f_b = $h & 0xff;
        my $f_g = ($h & 0xff00) >> 8;
        my $f_r = ($h & 0xff0000) >> 16;
        my $t_b = $h2 & 0xff;
        my $t_g = ($h2 & 0xff00) >> 8;
        my $t_r = ($h2 & 0xff0000) >> 16;
        my $col_b  = sprintf "%0.2x", abs int(((($t_b - $f_b) / $activenicks) * +$c) + $f_b);
        my $col_g  = sprintf "%0.2x", abs int(((($t_g - $f_g) / $activenicks) * +$c) + $f_g);
        my $col_r  = sprintf "%0.2x", abs int(((($t_r - $f_r) / $activenicks) * +$c) + $f_r);


        html("<tr><td bgcolor=\"$rankc\" align=\"left\">");
        my $line = $line{$nick};
        html("$i</td><td bgcolor=\"#$col_r$col_g$col_b\">$visiblenick</td><td bgcolor=\"#$col_r$col_g$col_b\">$line</td><td bgcolor=\"#$col_r$col_g$col_b\">");
        html("\"$randomline\"</td>");

        if ($userpics{$nick}) {
            html("<td bgcolor=\"#$col_r$col_g$col_b\" align=\"center\"><img valign=\"middle\" src=\"$imagepath$userpics{$nick}\"></td>");
        }

        html("</tr>");
        $i++;
    }

    html("</table><br>");

    # ALMOST AS ACTIVE NICKS

    @active = sort { $line{$b} <=> $line{$a} } keys %line;

    my $nickstoshow = $activenicks + $activenicks2;

    unless ($nickstoshow > $nicks) {

        html("<br><b><i>" . template_text('nottop') . "</i></b><table><tr>");
        for (my $c = $activenicks; $c < $nickstoshow; $c++) {
            unless ($c % 5) { unless ($c == $activenicks) { html("</tr><tr>"); } }
            html("<td bgcolor=\"$rankc\" class=\"small\">");
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
        html("<td>&nbsp;</td><td bgcolor=\"$tdtop\"><b>" . template_text('word') . "</b></td>");
        html("<td bgcolor=\"$tdtop\"><b>" . template_text('numberuses') . "</b></td>");
        html("<td bgcolor=\"$tdtop\"><b>" . template_text('lastused') . "</b></td>");


        for(my $i = 0; $i < 10; $i++) {
            last unless $i < $#popular;
            my $a = $i + 1;
            my $popular = $popular[$i];
            my $wordcount = $wordcount{$popular[$i]};
            my $lastused = $lastused{$popular[$i]};
            html("<tr><td bgcolor=\"$rankc\"><b>$a</b>");
            html("<td bgcolor=\"$hicell\">$popular</td>");
            html("<td bgcolor=\"$hicell\">$wordcount</td>");
            html("<td bgcolor=\"$hicell\">$lastused</td>");
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
        html("<td>&nbsp;</td><td bgcolor=\"$tdtop\"><b>" . template_text('nick') . "</b></td>");
        html("<td bgcolor=\"$tdtop\"><b>" . template_text('numberuses') . "</b></td>");
        html("<td bgcolor=\"$tdtop\"><b>" . template_text('lastused') . "</b></td>");

       for(my $i = 0; $i < 5; $i++) {
           last unless $i < $#popular;
           my $a = $i + 1;
           my $popular = $popular[$i];
           my $wordcount = $wordcount{$popular[$i]};
           my $lastused = $lastused{$popular[$i]};
           html("<tr><td bgcolor=\"$rankc\"><b>$a</b>");
           html("<td bgcolor=\"$hicell\">$popular</td>");
           html("<td bgcolor=\"$hicell\">$wordcount</td>");
           html("<td bgcolor=\"$hicell\">$lastused</td>");
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
        html("<tr><td bgcolor=\"$hicell\">$text");
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
        html("<tr><td bgcolor=\"$hicell\">" . template_text('question3') . "</td></tr>");
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
        html("<tr><td bgcolor=\"$hicell\">$text");
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
        html("<tr><td bgcolor=\"$hicell\">$text</td></tr>");
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

        html("<tr><td bgcolor=\"$hicell\">$text");
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

        html("<tr><td bgcolor=\"$hicell\">$text</td></tr>");
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
         html("<tr><td bgcolor=\"$hicell\">$text");

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
         html("<tr><td bgcolor=\"$hicell\">$text</td></tr>");
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

         html("<tr><td bgcolor=\"$hicell\">$text");
         if (@monologue >= 2) {
             my %hash = (
                 nick => $monologue[1],
                 monos => $monologue{$monologue[1]}
             );

             my $text = template_text('mono2', %hash);
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
        html("<tr><td bgcolor=\"$hicell\">$text<br>");

        if (@len >= 2) {
            %hash = (
                channel => $channel,
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
        html("<tr><td bgcolor=\"$hicell\">$text<br>");

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

        html("<tr><td bgcolor=\"$hicell\">$text");

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
            channel => $channel
        );

        my $text = template_text('foul3', %hash);

        html("<tr><td bgcolor=\"$hicell\">$text</td></tr>");
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
        html("<tr><td bgcolor=\"$hicell\">$text");

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
            channel => $channel
        );
        my $text = template_text('sad3', %hash);
        html("<tr><td bgcolor=\"$hicell\">$text</td></tr>");
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

        html("<tr><td bgcolor=\"$hicell\">$text");

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
        my %hash = ( channel => $channel );
        my $text = template_text('mostop3', %hash);
        html("<tr><td bgcolor=\"$hicell\">$text</td></tr>");
    }
    if (@deops) {
        my %hash = (
            channel => $channel,
            nick => $deops[0],
            deops => $tookop{$deops[0]}
        );
        my $text = template_text('mostdeop1', %hash);

        html("<tr><td bgcolor=\"$hicell\">$text");

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
        my %hash = ( channel => $channel );
        my $text = template_text('mostdeop3', %hash);
        html("<tr><td bgcolor=\"$hicell\">$text");
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

        html("<tr><td bgcolor=\"$hicell\">$text");
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
            channel => $channel
        );

        my $text = template_text('smiles3', %hash);
        html("<tr><td bgcolor=\"$hicell\">$text</td></tr>");
    }
}

sub lasttopics
{
    debug("Total number of topics: ". scalar @topics);

    if (@topics) {
        my $ltopic = @topics - 1;
        my $tlimit = 0;

        $topichistory -= 1;


        if ($ltopic > $topichistory) { $tlimit = $ltopic - $topichistory; }

        for (my $i = $ltopic; $i >= $tlimit; $i--) {
            $topics[$i]{"topic"} = replace_links($topics[$i]{"topic"});
            my $topic = $topics[$i]{topic};
            my $nick = $topics[$i]{nick};
            my $hour = $topics[$i]{hour};
            my $min = $topics[$i]{min};
            html("<tr><td bgcolor=\"$hicell\"><i>$topic</i></td>");
            html("<td bgcolor=\"$hicell\">By <b>$nick</b> at <b>$hour:$min</b></td></tr>");
        }
       } else {
            html("<tr><td bgcolor=\"$hicell\">" . template_text('notopic') ."</td></tr>");
       }
}


# Some HTML subs
sub htmlheader
{
print OUTPUT <<HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>$channel @ $network channel statistics</title>
<style type="text/css">
a { text-decoration: none }
a:link { color: $link; }
a:visited { color: $vlink; }
a:hover { text-decoration: underline; color: $hlink }

body {
    background-color: $bgcolor;
    font-family: verdana, arial, sans-serif;
    font-size: 13px;
    color: $text;
}

td {
    font-family: verdana, arial, sans-serif;
    font-size: 13px;
    color: $tdcolor;
}

.title {
    font-family: tahoma, arial, sans-serif;
    font-size: 16px;
    font-weight: bold;
}

.headline { color: $hcolor; }
.small { font-family: verdana, arial, sans-serif; font-size: 10px; }
.asmall { font-family: arial narrow, sans-serif; font-size: 10px }
</style></head>
<body>
<div align="center">
HTML
my %hash = (
    channel => $channel,
    network => $network,
    maintainer => $maintainer,
    time => $time,
    days => $days,
    nicks => $nicks,
    channel => $channel
);
print OUTPUT "<span class=\"title\">" . template_text('pagetitle1', %hash) . "</span><br>";
print OUTPUT "<br>" . template_text('pagetitle2', %hash) . "<br>";
print OUTPUT template_text('pagetitle3', %hash) . "<br><br>";

}

sub htmlfooter
{
print OUTPUT <<HTML;
<span class="small">
Stats generated by <a href="http://pisg.sourceforge.net/" title="Go to the pisg homepage">pisg</a> $version<br>
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
     <td bgcolor="$headline">
      <table width="100%" cellpadding="2" cellspacing="0" border="0" align="center">
       <tr>
        <td bgcolor="$hbgcolor" class="text10">
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
    if ($pagehead ne 'none') {
        open(PAGEHEAD, $pagehead) or die("$0: Unable to open $pagehead for reading: $!\n");
        while (<PAGEHEAD>) {
            html($_);
        }
    }
}

sub close_debug
{
    if ($debug) {
        close(DEBUG) or print STDERR "$0: Cannot close debugfile($debugfile): $!\n";
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
-u --usersfile=xxx     : Users config file
-h --help              : Output this message and exit (-? also works).

Example:

 \$ pisg.pl -n IRCnet -f xchat -o suid.html -c \\#channel -l logfile.log

As always, all options may also be defined by editing the source and calling
pisg without arguments.

END_USAGE

    if (GetOptions('channel=s'    => \$channel,
                   'logfile=s'    => \$logfile,
                   'format=s'     => \$format,
                   'network=s'    => \$network,
                   'maintainer=s' => \$maintainer,
                   'outfile=s'    => \$outputfile,
                   'dir=s'        => \$logdir,
                   'ignorefile=s' => \$tmp,
                   'aliasfile=s'  => \$tmp,
                   'usersfile=s'  => \$usersfile,
                   'help|?'       => \$help
               ) == 0 or $help) {
                   die($usage);
               }

    if (@ARGV) {
        if ($ARGV[0]) { $channel = $ARGV[0]; }
        if ($ARGV[1]) { $logfile = $ARGV[1]; }
        if ($ARGV[2]) { $outputfile = $ARGV[2]; }
        if ($ARGV[3]) { $maintainer = $ARGV[3]; }
    }

    if ($tmp) {
        die("The aliasfile and ignorefile has been obsoleted by the new
        userscfg, please use that instead [look in users.cfg]\n");
    }

}

### English
$T{EN}{mostop1} = "<b>[:nick]</b> donated [:ops] ops in the channel...";
$T{EN}{mostop2} = "<b>[:nick]</b> was also very polite: [:ops] from her/him";
$T{EN}{mostop3} = "Strange, no op was given on [:channel]!";

$T{EN}{mostdeop1} = "<b>[:nick]</b> is the channel sheriff with [:deops] deops...";
$T{EN}{mostdeop2} = "<b>[:nick]</b> deoped [:deops] users";
$T{EN}{mostdeop3} = "Wow, no op was taken on [:channel]!";

$T{EN}{question1} = "<b>[:nick]</b> is either stupid or just making many questions... [:per]% lines contained a question!";
$T{EN}{question2} = "<b>[:nick]</b> didn't know that much either, [:per]% of his lines were questions";
$T{EN}{question3} = "Nobody asked questions here, just geniuses at this channel?";

$T{EN}{loud1} = "Loudest one was <b>[:nick]</b> who yelled [:per]% of the time!";
$T{EN}{loud2} = "Another <i>old yeller</i> was <b>[:nick]</b> who shouted [:per]% of the time!";
$T{EN}{loud3} = "Nobody raised an exclamation mark, wow.";

$T{EN}{gotkick1} = "<b>[:nick]</b> wasn't very popular, got kicked [:kicks] times!";
$T{EN}{gotkick2} = "<b>[:nick]</b> seemed to be hated too, [:kicks] kicks were received";

$T{EN}{joins} = "<b>[:nick]</b> couldn't decide to stay or to go, [:joins] joins during this reporting period!";

$T{EN}{kick1} = "<b>[:nick]</b> is insane or just a fair op, kicked a total of [:kicked] people!";
$T{EN}{kick2} = "[:oldnick]'s faithfull follower, <b>[:nick]</b>, kicked about [:kicked] people";
$T{EN}{kick3} = "Nice oppers here, no one got kicked!";

$T{EN}{mono1} = "<b>[:nick]</b> is talking to himself a lot, wrote over 5 lines in a row [:monos] times!";
$T{EN}{mono2} = "Another lonely one was <b>[:nick]</b>, who managed to hit [:monos] times";

$T{EN}{long1} = "<b>[:nick]</b> wrote longest lines, average of [:letters] per line...";
$T{EN}{long2} = "Channel average on [:channel] was [:avg] letters per line";

$T{EN}{short1} = "<b>[:nick]</b> wrote shortest lines, average of [:letters] per line...";
$T{EN}{short2} = "[:nick] was tight-lipped, too, averaging [:letters]";

$T{EN}{foul1} = "<b>[:nick]</b> has quite a potty mouth, [:per]% lines contained foul language";
$T{EN}{foul2} = "<b>[:nick]</b> also makes sailors blush, [:per]% of the time";
$T{EN}{foul3} = "Nobody is foul-mouthed at [:channel]! Get out much?";

$T{EN}{smiles1} = "<b>[:nick]</b> brings happiness to the world, [:per]% lines contained smiling faces :)";
$T{EN}{smiles2} = "<b>[:nick]</b> isn't a sad person either, who smiled [:per]% of the time";
$T{EN}{smiles3} = "Nobody smiles at [:channel]! Cheer up guys and girls.";

$T{EN}{sad1} = "<b>[:nick]</b> seems to be sad at the moment, [:per]% lines contained sad faces :(";
$T{EN}{sad2} = "<b>[:nick]</b> is also a sad person, who cried [:per]% of the time";
$T{EN}{sad3} = "Nobody is sad at [:channel]! What a happy channel :-)";

$T{EN}{notopic} = "A topic was never set on this channel";

## Topics

$T{EN}{bignumtopic} = "Big numbers";
$T{EN}{othernumtopic} = "Other interesting numbers";
$T{EN}{latesttopic} = "Latest Topics";
$T{EN}{activetimestopic} = "Most active times";
$T{EN}{activenickstopic} = "Most active nicks";
$T{EN}{mostwordstopic} = "Most used words";
$T{EN}{referencetopic} = "Most referenced nick";

## Other text

$T{EN}{totallines} = "Total number of lines: [:lines]";
$T{EN}{nick} = "Nick";
$T{EN}{numberlines} = "Number of lines";
$T{EN}{randquote} = "Random quote";
$T{EN}{userpic} = "Userpic";
$T{EN}{nottop} = "These didn't make it to the top:";
$T{EN}{word} = "Word";
$T{EN}{numberuses} = "Number of Uses";
$T{EN}{lastused} = "Last Used by";
$T{EN}{pagetitle1} = "[:channel] @ [:network] stats by [:maintainer]";
$T{EN}{pagetitle2} = "Statistics generated on [:time]";
$T{EN}{pagetitle3} = "During this [:days]\-days reporting period, a total number of <b>[:nicks]</b> different nicks were represented on [:channel].";

### German

$T{DE}{mostop1} = "<b>[:nick]</b> vergab [:ops] ops im Channel...";
$T{DE}{mostop2} = "<b>[:nick]</b> war auch sehr zuvorkommend: [:ops] von ihm/ihr";
$T{DE}{mostop3} = "Komisch, kein op wurde in [:channel] vergeben!";

$T{DE}{mostdeop1} = "<b>[:nick]</b> ist die Channel-Polizei. Er/Sie hat [:deops] Usern das @ wieder weggenommen...";
$T{DE}{mostdeop2} = "<b>[:nick]</b> nahm [:deops] Usern das @ wieder weg.";
$T{DE}{mostdeop3} = "Wow, niemand wurde deopped in [:channel]!";

$T{DE}{question1} = "<b>[:nick]</b> hat wohl in der Schule nicht gut aufgepasst... [:per]% seiner Zeilen enthielten eine Frage!";
$T{DE}{question2} = "<b>[:nick]</b> weiss wohl auch nicht viel, [:per]% seiner Zeilen waren Fragen";
$T{DE}{question3} = "Niemand hat hier was gefragt, sollte das etwa ein Channel voller Genies sein? ;)";

$T{DE}{loud1} = "Am lautesten war <b>[:nick]</b> der [:per]% der Zeit geschrieen hat!";
$T{DE}{loud2} = "Ein anderer <i>Schreihals</i> war <b>[:nick]</b> der/die [:per]% der Zeit rumgeschrieen hat!";
$T{DE}{loud3} = "Niemand hat ein Ausrufungszeichen benutzt, wow... Zurückhaltende User im Channel ;)";

$T{DE}{gotkick1} = "<b>[:nick]</b> war wohl der Channelclown, er/sie wurde [:kicks] mal gekickt!";
$T{DE}{gotkick2} = "<b>[:nick]</b> konnte sich scheinbar auch nicht benehmen, [:kicks] kicks für ihn/sie";

$T{DE}{joins} = "<b>[:nick]</b> konnte sich nicht entscheiden im Channel zu bleiben oder zu gehen, [:joins] joins während des Statistik-Zeitraums!";

$T{DE}{kick1} = "Ist <b>[:nick]</b> jetzt einfach nur ein fairer Op oder macht ihm/ihr das Spass? Er/Sie kickte [:kicked] User!";
$T{DE}{kick2} = "[:oldnick]'s würdiger Nachfolger, <b>[:nick]</b>, er/sie kickte [:kicked] User";
$T{DE}{kick3} = "Nette Opper hier, niemand wurde gekickt!";

$T{DE}{mono1} = "<b>[:nick]</b> spricht viel mit sich selbst, er/sie schrieb über 5 Zeilen in einer Reihe und das [:monos] mal!";
$T{DE}{mono2} = "Ein anderes einsames Herz ist <b>[:nick]</b>, der/die [:monos] mal mit sich selbst redete";

$T{DE}{long1} = "<b>[:nick]</b> ist die Labertasche im Channel Er/Sie schrieb die längste Zeile mit durchschnittlich [:letters] Buchstaben pro Zeile...";
$T{DE}{long2} = "Channel-Durchschnitt in [:channel] war [:avg] Buchstaben pro Zeile";

$T{DE}{short1} = "<b>[:nick]</b> ist nicht sehr Mitteilungsbedürftig. Er/Sie schrieb die kürzeste Zeile mit durchschnittlich [:letters] Buchstaben pro Zeile...";
$T{DE}{short2} = "[:nick] war auch sehr kurzfassend, durchschnittlich [:letters] Buchstaben pro Zeile";

$T{DE}{foul1} = "<b>[:nick]</b> hat in seiner/ihrer Jugend keine Erziehung genossen, [:per]% seiner/ihrer S&auml;tze enthielten Schimpfworte!";
$T{DE}{foul2} = "<b>[:nick]</b> war [:per]% der Zeit unartig (Ob da der Weihnachtsman noch kommt?)";
$T{DE}{foul3} = "Alle gut erzogen in [:channel], niemand hat Schimpfworte benutzt!";

$T{DE}{smiles1} = "<b>[:nick]</b> ist ein fröhlicher Mensch, [:per]% seiner/ihrer Zeilen enthielt ein fröhliches Smily :)";
$T{DE}{smiles2} = "<b>[:nick]</b> scheint auch glücklich zu sein. Er/Sie \"smilte\" [:per]% der Zeit";
$T{DE}{smiles3} = "Niemand \"smilte\" in [:channel]! Los Leute legt mal wieder ein Lächeln auf :)";

$T{DE}{sad1} = "<b>[:nick]</b> scheint im Moment nicht gut drauf zu sein, [:per]% seiner/ihrer Zeilen enthielten ein trauriges Smily :(";
$T{DE}{sad2} = "<b>[:nick]</b> ist auch eine traurige Person, die [:per]% der Zeit geweint hat";
$T{DE}{sad3} = "Niemand ist traurig in [:channel]! Was für ein fröhlicher Channel :)";

$T{DE}{notopic} = "In diesem Channel wurde kein Topic gesetzt";

## Topics

$T{DE}{bignumtopic} = "Die Zahlen sprechen für sich :)";
$T{DE}{othernumtopic} = "Andere interessante Zahlen";
$T{DE}{latesttopic} = "Letzte Topics";
$T{DE}{activetimestopic} = "Wann war am meisten los?";
$T{DE}{activenickstopic} = "Wer quatscht am meisten?";
$T{DE}{mostwordstopic} = "Am meisten benutzte Wörter";
$T{DE}{referencetopic} = "Begehrte Nicks :)";

## Other text

$T{DE}{totallines} = "Gesamtanzahl der Zeilen: [:lines]";
$T{DE}{nick} = "Nick";
$T{DE}{numberlines} = "Anzahl der Zeilen";
$T{DE}{randquote} = "Zufalls quote";
$T{DE}{userpic} = "Userbild";
$T{DE}{nottop} = "Sie haben es nicht an die Spitze geschafft:";
$T{DE}{word} = "Wort";
$T{DE}{numberuses} = "Wie oft benutzt";
$T{DE}{lastused} = "Zuletzt benutzt von";
$T{DE}{pagetitle1} = "[:channel] @ [:network] stats erstellt von [:maintainer]";
$T{DE}{pagetitle2} = "Statistik erstellt am [:time]";
$T{DE}{pagetitle3} = "Während des Statistikzeitraums von [:days] Tage(n) wurden <b>[:nicks]</b> verschiedene Nicks in [:channel] gezählt.";

### Danish
$T{DK}{mostop1} = "<b>[:nick]</b> gav [:ops] op status i kanalen...";
$T{DK}{mostop2} = "<b>[:nick]</b> var også venlig at gi': [:ops] fra sig";
$T{DK}{mostop3} = "Underligt, ingen har fået op på [:channel] endnu!";

$T{DK}{mostdeop1} = "<b>[:nick]</b> holder orden på [:channel] med [:deops] deops...";
$T{DK}{mostdeop2} = "<b>[:nick]</b> deoppede [:deops] brugere";
$T{DK}{mostdeop3} = "Hmm, der var ingen som fik op på [:channel]!";

$T{DK}{question1} = "<b>[:nick]</b> må være rimelig dum eller efterligner bare Spørge-Jørgen... [:per]% af hans linjer var spørgsmål!";
$T{DK}{question2} = "<b>[:nick]</b> var heller ingen Einstein, [:per]% af hans linjer var også spørgsmål";
$T{DK}{question3} = "Ingen spørgsmål på denne kanal. De må sørme være kloge!";

$T{DK}{loud1} = "Den mest larmende var <b>[:nick]</b>, som råbte [:per]% af tiden!";
$T{DK}{loud2} = "En anden skrigehals var <b>[:nick]</b>, som råbte [:per]% af tiden!";
$T{DK}{loud3} = "Der er ingen som råber. Leger de stilleleg?";

$T{DK}{gotkick1} = "<b>[:nick]</b> er ret upopulær, blev sparket ud [:kicks] gange!";
$T{DK}{gotkick2} = "<b>[:nick]</b> er heller ikke nogen Elvis, [:kicks] gange fik han sparket";

$T{DK}{joins} = "<b>[:nick]</b> er lidt forvirret. Han har været inde og ude af kanalen [:joins] gange!";

$T{DK}{kick1} = "<b>[:nick]</b> er magtsygt eller ved hvordan han/hun skal kontrollere sine fjender. Han har sparket [:kicked] folk ud af kanalen!";
$T{DK}{kick2} = "[:oldnick] har en efterfølger. <b>[:nick]</b> sparkede [:kicked] folk ud af kanalen";
$T{DK}{kick3} = "Venlige operatører må man sige. Ingen har fået sparket!";

$T{DK}{mono1} = "<b>[:nick]</b> snakker meget med sig selv. Han har skrevet over 5 linjer på en gang, [:monos] gange!";
$T{DK}{mono2} = "En anden ensom person var <b>[:nick]</b>, som snakkede til sig selv [:monos] gange";

$T{DK}{long1} = "<b>[:nick]</b> skriver meget lange sætninger. Gennemsnittet er [:letters] bogstaver pr. linje...";
$T{DK}{long2} = "Gennemsnittet på [:channel] er [:avg] bogstaver pr. linje";

$T{DK}{short1} = "<b>[:nick]</b> skrev de korteste linjer. Gennemsnittet er [:letters] bogstaver pr. linje...";
$T{DK}{short2} = "[:nick] skriver også korte linjer, med et gennesnit på [:letters]";

$T{DK}{foul1} = "<b>[:nick]</b> er lidt stor i munden, [:per]% af linjerne indholte uhøfligt sprog";
$T{DK}{foul2} = "<b>[:nick]</b> burde også vaske munden med sæbe med at det han fyrer af, [:per]% af tiden";
$T{DK}{foul3} = "Ingen rapkæftede på [:channel]!";

$T{DK}{smiles1} = "<b>[:nick]</b> er altid glad, [:per]% af linjerne havde glade ansigter :)";
$T{DK}{smiles2} = "<b>[:nick]</b> er heller ikke en trist person, som smilede [:per]% af tiden";
$T{DK}{smiles3} = "Ingen smiler på [:channel]! Op med humøret drenge og piger.";

$T{DK}{sad1} = "<b>[:nick]</b> er meget ked af det for tiden, [:per]% af linjerne havde sørgelige ansigter :(";
$T{DK}{sad2} = "<b>[:nick]</b> er også en trist person, som græd [:per]% af tiden";
$T{DK}{sad3} = "Ingen er kede af det på [:channel]! Sikke en glad kanal :-)";

$T{DK}{notopic} = "A topic was never set on this channel";

## Topics

$T{DK}{bignumtopic} = "Store numre";
$T{DK}{othernumtopic} = "Andre interessante numre";
$T{DK}{latesttopic} = "Sidst nyeste topics";
$T{DK}{activetimestopic} = "Mest aktive tider";
$T{DK}{activenickstopic} = "Mest aktive nicks";
$T{DK}{mostwordstopic} = "Mest brugte ord";
$T{DK}{referencetopic} = "Mest tiltalte nicks";

## Other text

$T{DK}{totallines} = "Hele antal linjer: [:lines]";
$T{DK}{nick} = "Nick";
$T{DK}{numberlines} = "Antal linjer";
$T{DK}{randquote} = "Tilfældig sætning";
$T{DK}{userpic} = "Brugerbillede";
$T{DK}{nottop} = "Disse nåede ikke til tops:";
$T{DK}{word} = "Ord";
$T{DK}{numberuses} = "Antal forbrug";
$T{DK}{lastused} = "Sidst brugt af";
$T{DK}{pagetitle1} = "[:channel] @ [:network] statistikker af [:maintainer]";
$T{DK}{pagetitle2} = "Statistikker lavet d. [:time]";
$T{DK}{pagetitle3} = "Igennem denne [:days]\-dages periode, har der været <b>[:nicks]</b> forskellige nicks på [:channel].";

### French

# Not exactly the translation but something fun
# Time translation needs more update

$T{FR}{mostop1} = "<b>[:nick]</b> a donné [:ops] ops sur le channel...";
$T{FR}{mostop2} = "<b>[:nick]</b> est aussi très poli : [:ops] ops de sa part";
$T{FR}{mostop3} = "Etrange, aucun op n'a été donné sur [:channel]!";

$T{FR}{mostdeop1} = "<b>[:nick]</b> est le shérif avec [:deops] deops...";
$T{FR}{mostdeop2} = "<b>[:nick]</b> a deopé [:deops] utilisateurs";
$T{FR}{mostdeop3} = "Wow, aucun op n'a été retiré sur [:channel]!";

$T{FR}{question1} = "<b>[:nick]</b> est soit stupide soit trop curieux... [:per]% de ses lignes contiennent une question!";
$T{FR}{question2} = "<b>[:nick]</b> n'en connait pas davantage, [:per]% de ses lignes étaient des questions";
$T{FR}{question3} = "Personne ne pose de question ici, tous des génies sur ce channel?";

$T{FR}{loud1} = "Le plus bruyant est <b>[:nick]</b> qui gueule [:per]% du temps!";
$T{FR}{loud2} = "Un autre <i>vieux raleur</i> est <b>[:nick]</b> qui braille [:per]% du temps!";
$T{FR}{loud3} = "Personne ne s'exclame ici, wow.";

$T{FR}{gotkick1} = "<b>[:nick]</b> n'est pas trés populaire, kické [:kicks] fois!";
$T{FR}{gotkick2} = "<b>[:nick]</b> n'a pas d'ami non plus, [:kicks] kicks reçus";

$T{FR}{joins} = "<b>[:nick]</b> ne sait pas s'il doit rester ou partir, [:joins] visites durant cette période!";

$T{FR}{kick1} = "<b>[:nick]</b> est malade ou alors aime bien jouer, son kick a sévi [:kicked] fois!";
$T{FR}{kick2} = "Un disciple de [:oldnick], <b>[:nick]</b>, a kické [:kicked] personnes";
$T{FR}{kick3} = "Les ops sont sympas ici, personne n'a été kické!";

$T{FR}{mono1} = "<b>[:nick]</b> se parle à lui-meme trés souvent, il a écrit plus de 5 lignes d'un coup à [:monos] reprises!";
$T{FR}{mono2} = "Un autre incompris est <b>[:nick]</b>, qui a tenté de le dépasser à [:monos] reprises";

$T{FR}{long1} = "<b>[:nick]</b> a écrit les lignes les plus longues, avec en moyenne [:letters] lettres par ligne...";
$T{FR}{long2} = "La moyenne sur [:channel] est de [:avg] lettres par ligne";

$T{FR}{short1} = "<b>[:nick]</b> a écrit les lignes les plus courtes, avec en moyenne [:letters] lettres par ligne...";
$T{FR}{short2} = "[:nick] n'a pas grand chose a dire non plus, en moyenne [:letters]";

$T{FR}{foul1} = "<b>[:nick]</b> a du mal a s'exprimer, [:per]% de ses lignes contiennent des mots incompréhensibles";
$T{FR}{foul2} = "<b>[:nick]</b> parle aussi comme un chartier, [:per]% du temps";
$T{FR}{foul3} = "Personne n'a de problème pour parler sur [:channel]! Pendant combien de temps encore?";

$T{FR}{smiles1} = "<b>[:nick]</b> apporte un peu de gaiété dans le monde, [:per]% de ses lignes contiennent un smiley :)";
$T{FR}{smiles2} = "<b>[:nick]</b> n'est pas triste non plus, il sourit [:per]% du temps";
$T{FR}{smiles3} = "Personne ne sourit sur [:channel]! Allez faites un effort quoi!";

$T{FR}{sad1} = "<b>[:nick]</b> semble un peu triste en ce moment, [:per]% de ses lignes contiennent un smiley :(";
$T{FR}{sad2} = "<b>[:nick]</b> est aussi bien triste, il pleure [:per]% du temps";
$T{FR}{sad3} = "Personne n'est triste sur [:channel]! Quel channel merveilleux :-)";

$T{FR}{notopic} = "Il n'y a jamais eu de topic sur ce channel";

## Topics

$T{FR}{bignumtopic} = "Les gros chiffres";
$T{FR}{othernumtopic} = "D'autres chiffres intéressants";
$T{FR}{latesttopic} = "Les derniers topics";
$T{FR}{activetimestopic} = "Les périodes d'intense activité";
$T{FR}{activenickstopic} = "Les nicks les plus actifs";
$T{FR}{mostwordstopic} = "Les mots les plus utilisés";
$T{FR}{referencetopic} = "Les mots les plus utilisés dans la conversation";

## Other text

$T{FR}{totallines} = "Nombre total de lignes: [:lines]";
$T{FR}{nick} = "Nick";
$T{FR}{numberlines} = "Nombre de lignes";
$T{FR}{randquote} = "Citation typique";
$T{FR}{userpic} = "Image";
$T{FR}{nottop} = "Ne sont pas dans le classement";
$T{FR}{word} = "Mot";
$T{FR}{numberuses} = "Nombre d'occurences";
$T{FR}{lastused} = "Dernière utilisation par";
$T{FR}{pagetitle1} = "[:channel] @ [:network] stats par [:maintainer]";
$T{FR}{pagetitle2} = "Statistiques générées le [:time]";
$T{FR}{pagetitle3} = "Durant cette periode de [:days] jours, <b>[:nicks]</b> nicks différents sont apparus sur [:channel].";

&main();        # Run the script
