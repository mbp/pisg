#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use FindBin;
use lib $FindBin::Bin . "/modules";     # Module search path

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

my ($debug);
# Default values for pisg. Their meanings are explained in CONFIG-README.
#
# If you are a user of pisg, you shouldn't change it here, but instead on
# commandline or in pisg.cfg

my $conf = {
    channel => "#channel",
    logfile => "channel.log",
    format => "mIRC",
    network => "SomeIRCNet",
    outputfile => "index.html",
    maintainer => "MAINTAINER",
    pagehead => "none",
    configfile => "pisg.cfg",
    imagepath => "",
    logdir => "",
    lang => 'EN',
    langfile => 'lang.txt',
    prefix => "",
    modules_dir => $FindBin::Bin . "/modules",     # Module search path

    # Colors / Layout

    bgcolor => "#dedeee",
    bgpic => '',
    text => "black",
    hbgcolor => "#666699",
    hcolor => "white",
    hicell => "#BABADD",
    hicell2 => "#CCCCCC",
    tdcolor => "black",
    tdtop => "#C8C8DD",
    link => "#0b407a",
    vlink => "#0b407a",
    hlink => "#0b407a",
    headline => "#000000",
    rankc => "#CCCCCC",

    pic_v_0 => "blue-v.png",
    pic_v_6 => "green-v.png",
    pic_v_12 => "yellow-v.png",
    pic_v_18 => "red-v.png",
    pic_h_0 => "blue-h.png",
    pic_h_6 => "green-h.png",
    pic_h_12 => "yellow-h.png",
    pic_h_18 => "red-h.png",

    # Stats settings

    show_linetime => 0,
    show_time => 1,
    show_words => 0,
    show_wpl => 0,
    show_cpl => 0,
    show_legend => 1,
    show_kickline => 1,
    show_actionline => 1,
    show_shoutline => 1,
    show_violentlines => 1,

    # Less important things

    minquote => 25,
    maxquote => 65,
    wordlength => 5,
    activenicks => 25,
    activenicks2 => 30,
    topichistory => 3,
    nicktracking => 1,
    timeoffset => "+0",

    # Misc settings

    foul => 'ass fuck bitch shit scheisse scheiße kacke arsch ficker ficken schlampe',
    violent => 'slaps beats smacks',
    ignorewords => '',
    tablewidth => 614,
    regexp_aliases => 0,

    # Developer stuff

    debug => 0,
    debugfile => "debug.log",
    version => "v0.22-cvs",
};

my ($chans, $users);

my ($lines, $smile, $time, $timestamp, %alias, $normalline, $actionline,
$thirdline, $processtime, @topics, %monologue, %kicked, %gotkick,
%line, %length, %sadface, %smile, $nicks, %longlines, %mono, %times, %question,
%loud, $totallength, %gaveop, %tookop, %joins, %actions, %sayings, %wordcount,
%lastused, %gotban, %setban, %foul, $days, $oldtime, $lastline, $actions,
$normals, %T, $repeated, $lastnormal, %shout, %violence, %attacked, %words,
%line_time, @urls, %urlnick, %kickline, %actionline, %shoutline, %violenceline,
%attackedline);


sub main
{
    print "pisg $conf->{version} - Perl IRC Statistics Generator\n\n";
    init_config();      # Init config. (Aliases, ignores, other options etc.)
    get_language_templates(); # Get translations from lang.txt
    parse_channels();   # parse any channels in <channel> statements
    do_channel()
        unless ($conf->{chan_done}{$conf->{channel}});

    close_debug();      # Close the debugging file
}

sub do_channel
{
    $conf->{parser} = choose_log_format($conf->{format});
    if (defined $conf->{parser}) {
	init_debug()
	    unless ($conf->{debugstarted});       # Init the debugging file
	init_pisg();        # Init commandline arguments and other things
	init_words();       # Init words. (Foulwords etc)


	if ($conf->{logdir}) {
	    parse_dir();        # Run through all logfiles in dir
	} else {
	    parse_file($conf->{logfile});   # Run through the whole logfile
	}

	create_html()
	    if ($lines > 0);# Create the HTML
                            # (look here if you want to remove some of the
                            # stats which you don't care about)

	print "\nFile parsed succesfully in $processtime on $time.\n";
	$conf->{chan_done}{$conf->{channel}} = 1;
    } else {
	print STDERR "Skipping channel $conf->{channel}\n";
    }
}

# The function to choose which module to use. 
sub choose_log_format {
    my $format = shift;
    my $parser = undef;
    eval <<_END;
use lib '$conf->{modules_dir}';
use Pisg::Parser::$format;
\$parser = new Pisg::Parser::$format(\$debug);
_END
    if ($@) {
        print STDERR "Could not load parser for '$format': $@\n";
        return undef;
    }
    return $parser;
}

sub parse_channels
{
    my %origconf = %{ $conf };

    foreach my $channel (keys %{ $chans }) {
        foreach (keys %{ $chans->{$channel} }) {
            $conf->{$_} = $chans->{$channel}{$_};
        }
        do_channel();
        $origconf{chan_done} = $conf->{chan_done};
        %{ $conf } = %origconf;
    }
}

sub init_pisg
{

    # Reset all variables

    undef $lastnormal;
    undef $smile;

    undef $normalline;
    undef $actionline;
    undef $thirdline;
    undef $processtime;
    undef @topics;

    undef %monologue;
    undef %kicked;
    undef %gotkick;
    undef %line;
    undef %length;
    undef %sadface;

    undef %smile;
    undef $nicks;
    undef %longlines;
    undef %mono;
    undef %times;
    undef %question;
    undef %loud;
    undef $totallength;

    undef %gaveop;
    undef %tookop;
    undef %joins;
    undef %actions;
    undef %sayings;
    undef %wordcount;
    undef %lastused;
    undef %gotban;

    undef %setban;
    undef %foul;

    undef $lastnormal;
    undef %shout;

    undef %violence;
    undef %attacked;
    undef %words;
    undef %line_time;


    $timestamp = time();
    $conf->{start} = time();

    if ($conf->{timeoffset} =~ /\+(\d+)/) {
        # We must plus some hours to the time
        $timestamp += 3600 * $1; # 3600 seconds per hour

    } elsif ($conf->{timeoffset} =~ /-(\d+)/) {
        # We must remove some hours from the time
        $timestamp -= 3600 * $1; # 3600 seconds per hour
    }

    # Add trailing slash when it's not there..
    $conf->{imagepath} =~ s/([^\/])$/$1\//;

    # Set some values
    $days = 1;
    $oldtime = "00";
    $lastline = "";
    $actions = "0";
    $normals = "0";
    $time = localtime($timestamp);
    $repeated = 0;
    $lines = 0;

    print "Using language template: $conf->{lang}\n\n" if ($conf->{lang} ne 'EN');

    print "Statistics for channel $conf->{channel} \@ $conf->{network} by $conf->{maintainer}\n\n";

}

sub init_config
{
    get_cmdlineoptions();

    if ((open(CONFIG, $conf->{configfile}) or open(CONFIG, $FindBin::Bin . "/$conf->{configfile}"))) {
	print "Using config file: $conf->{configfile}\n";

	my $lineno = 0;
        while (my $line = <CONFIG>)
        {
            $lineno++;
            next if ($line =~ /^#/);

            if ($line =~ /<user.*>/) {
                my $nick;

                if ($line =~ /nick="([^"]+)"/) {
                    $alias{lc($nick = $1)} = $1;
                } else {
                    print STDERR "Warning: no nick specified in $conf->{configfile} on line $lineno\n";
                    next;
                }

                if ($line =~ /alias="([^"]+)"/) {
                    my @thisalias = split(/\s+/, lc($1));
                    foreach (@thisalias) {
		        if ($conf->{regexp_aliases} and $_ =~ /[\[\]\{\}\(\)\?\+\.\*\^\\]/) {
                            $conf->{aliaswilds}{$_} = $nick;
                        } elsif (not $conf->{regexp_aliases} and $_ =~ s/\*/\.\*/g) {
                            $_ =~ s/([\|\[\]\{\}\(\)\?\+\^\\])/\\$1/g; # quote it if it is a wildcard
                            $conf->{aliaswilds}{$_} = $nick;
                        } else {
                            $alias{$_} = $nick;
                        }
                    }
                }

                if ($line =~ /pic="([^"]+)"/) {
                    $users->{userpics}{$nick} = $1;
                }

                if ($line =~ /link="([^"]+)"/) {
                    $users->{userlinks}{$nick} = $1;
                }

                if ($line =~ /ignore="Y"/i) {
                    $users->{ignores}{$nick} = 1;
                }

                if ($line =~ /sex="([MmFf])"/i) {
                    $users->{sex}{$nick} = lc($1);
                }

            } elsif ($line =~ /<set(.*)>/) {

                my $settings = $1;
                while ($settings =~ s/[ \t]([^=]+)=["']([^"']*)["']//) {
                    my $var = lc($1); # Make the string lowercase
                    unless (($conf->{$var} eq $2) || $conf->{cmdl}{$var}) {
                        $conf->{$var} = $2;
                    }
                    $debug->("Conf: $var = $2");
                }

            } elsif ($line =~ /<channel=['"]([^'"]+)['"](.*)>/i) {
                my ($channel, $settings) = ($1, $2);
                $chans->{$channel}->{channel} = $channel;
                $conf->{chan_done}{$conf->{channel}} = 1; # don't parse channel in $conf->{channel} if a channel statement is present
                while ($settings =~ s/\s([^=]+)=["']([^"']*)["']//) {
                    my $var = lc($1);
                    $chans->{$channel}{$var} = $2;
                    $debug->("Channel conf $channel: $var = $2");
                }
                while (<CONFIG>) {
                    last if ($_ =~ /<\/*channel>/i);
                    while ($_ =~ s/^\s*(\w+)\s*=\s*["']([^"']*)["']//) {
                        my $var = lc($1);
                        unless ($conf->{cmdl}{$var}) {
                            $chans->{$channel}{$var} = $2;
                        }
                        $debug->("Conf $channel: $var = $2");
                    }
                }
            }
        }

        close(CONFIG);
    }

}

sub init_words {
    $conf->{foul} =~ s/\s+/|/g;
    foreach (split /\s+/, $conf->{ignorewords}) {
        $conf->{ignoreword}{$_} = 1;
    }
    $conf->{violent} =~ s/\s+/|/g;
}

sub init_debug
{
    $conf->{debugstarted} = 1;
    if ($conf->{debug}) {
        print "[ Debugging => $conf->{debugfile} ]\n";
        open(DEBUG,"> $conf->{debugfile}") or print STDERR "$0: Unable to open debug
        file($conf->{debugfile}): $!\n";
        $debug->("*** pisg debug file for $conf->{logfile}\n");
        if ($conf->{debugqueue}) {
            print DEBUG $conf->{debugqueue};
            delete $conf->{debugqueue};
        }
    } else {
	$debug = sub {};
    }
}

sub parse_dir
{
    # Add trailing slash when it's not there..
    $conf->{logdir} =~ s/([^\/])$/$1\//;

    print "Going into $conf->{logdir} and parsing all files there...\n\n";
    my @filesarray;
    opendir(LOGDIR, $conf->{logdir}) or die("Can't opendir $conf->{logdir}: $!");
    @filesarray = grep { /^[^\.]/ && /^$conf->{prefix}/ && -f "$conf->{logdir}/$_" } readdir(LOGDIR) or die("No files in \"$conf->{logdir}\" matched prefix \"$conf->{prefix}\"");
    closedir(LOGDIR);
    
    foreach my $file (sort @filesarray) {
        $file = $conf->{logdir} . $file;
        parse_file($file);
    }
}

sub parse_file
{
    my $file = shift;
    my $foulwords = $conf->{foul};
    my $urlcount = 0;

    # This parses the file..
    print "Analyzing log($file) in '$conf->{format}' format...\n";

    if ($file =~ /.bz2{0,1}$/ && -f $file) {
        open (LOGFILE, "bunzip2 -c $file |") or die("$0: Unable to open logfile($file): $!\n");
    } elsif ($file =~ /.gz$/ && -f $file) {
        open (LOGFILE, "gunzip -c $file |") or die("$0: Unable to open logfile($file): $!\n");
    } else {
        open (LOGFILE, $file) or die("$0: Unable to open logfile($file): $!\n");
    }
    while(my $line = <LOGFILE>) {
        $lines++; # Increment number of lines.

        my $hashref;

        # Match normal lines.
        if ($hashref = $conf->{parser}->normalline($line, $lines)) {

	    if (defined $hashref->{repeated}) {
		$repeated = $hashref->{repeated};
	    }

            my ($hour, $nick, $saying, $i);

            for ($i = 0; $i <= $repeated; $i++) {
                $line = strip_mirccodes($line);

                if ($i > 0) {
                    $hashref = $conf->{parser}->normalline($lastnormal, $lines);
                    $lines++; #Increment number of lines for repeated lines
                }

                $hour = $hashref->{hour};
                $nick = find_alias($hashref->{nick});
                $saying = $hashref->{saying};

                # Timestamp collecting
                $times{$hour}++;

                unless ($users->{ignores}{$nick}) {
                    $normals++;
                    $line{$nick}++;
                    $line_time{$nick}[int($hour/6)]++;

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

                    if ($l > $conf->{minquote} && $l < $conf->{maxquote}) {
                        # Creates $hash{nick}
                        if (!(defined $sayings{$nick}) || (rand($longlines{$nick} + 50) < 15)) {
                            $sayings{$nick} = $saying;
                        }
                        $longlines{$nick}++;
                    }

                    $question{$nick}++
                        if ($saying =~ /\?/o);

                    $loud{$nick}++
                        if ($saying =~ /!/o);

                    if ($saying !~ /[a-z0-9:]/o && $saying =~ /[A-Z]+/o) {
                        $shout{$nick}++;
                        $shoutline{$nick} = $line;
                    }

                    $foul{$nick}++
                        if ($saying =~ /$foulwords/i);

                    # Who smiles the most?
                    # A regex matching al lot of smilies

                    $smile{$nick}++
                        if ($saying =~ /[8;:=][ ^-o]?[)pPD}\]>]/o);

                    if (($saying =~ /[8;:=][ ^-]?[\(\[\\\/{]/o) && !($saying =~ /\w+:\/\//o)) {
                        $sadface{$nick}++;
                    }

                    if ($saying =~ /(\w+):\/\/(\S+)/o) {
                        $urls[$urlcount] = $1 . "://" . $2;
                        $urlnick{$urls[$urlcount]} = $nick;
                        $urlcount++;
                    }

                    parse_words($saying, $nick);

                    $length{$nick} += $l;
                    $totallength += $l;
                }
            }
            $lastnormal = $line;
            $repeated = 0;
        }

        # Match action lines.
        elsif ($hashref = $conf->{parser}->actionline($line, $lines)) {

            my ($hour, $nick, $saying);

            $hour = $hashref->{hour};
            $nick = find_alias($hashref->{nick});
            $saying = $hashref->{saying};

            # Timestamp collecting
            $times{$hour}++;
            $line = strip_mirccodes($line);

            unless ($users->{ignores}{$nick}) {
                $actions++;
                $actions{$nick}++;
                $actionline{$nick} = $line;
                $line{$nick}++;
                $line_time{$nick}[int($hour/6)]++;

                if ($saying =~ /^($conf->{violent}) (\S+)/) {
                    $violence{$nick}++;
                    $attacked{$2}++;
                    $violenceline{$nick} = $line;
                    $attackedline{$2} = $line;
                }


                my $len = length($saying);
                $length{$nick} += $len;
                $totallength += $len;

                parse_words($saying, $nick);
            }
        }

        # Match *** lines.
        elsif (($hashref = $conf->{parser}->thirdline($line, $lines)) &&
	       $hashref->{nick}) {

            my ($hour, $min, $nick, $kicker, $newtopic, $newmode, $newjoin, $newnick);

            $hour = $hashref->{hour};
            $min = $hashref->{min};
            $nick = find_alias($hashref->{nick});
            $kicker = find_alias($hashref->{kicker})
                if ($hashref->{kicker});
            $newtopic = $hashref->{newtopic};
            $newmode = $hashref->{newmode};
            $newjoin = $hashref->{newjoin};
            $newnick = $hashref->{newnick};

            # Timestamp collecting
            $times{$hour}++;
            $line = strip_mirccodes($line);

            unless ($users->{ignores}{$nick}) {

                if (defined($kicker)) {
                    unless ($users->{ignores}{$kicker}) {
                        $gotkick{$nick}++;
                        $kicked{$kicker}++;
                        $kickline{$nick} = $line;
                    }
                } elsif (defined($newtopic)) {
                    unless ($newtopic eq '') {
                        my $tcount = @topics;

                        $topics[$tcount]{topic} = $newtopic;
                        $topics[$tcount]{nick} = $nick;
                        $topics[$tcount]{hour} = $hour;
                        $topics[$tcount]{min} = $min;
                    }
                } elsif (defined($newmode)) {
                    my @opchange = opchanges($newmode);
                    $gaveop{$nick} += $opchange[0] if $opchange[0];
                    $tookop{$nick} += $opchange[1] if $opchange[1];
                } elsif (defined($newjoin)) {
                    $joins{$nick}++;
                } elsif (defined($newnick) && ($conf->{nicktracking} == 1)) {
                    my $lcnewnick = lc($newnick);
                    my $lcnick = lc($nick);
                    if ($lcnewnick eq lc(find_alias($newnick))) {
                        if (!defined($alias{$lcnick})) {
                            if (defined($alias{$lcnewnick})) {
                                $alias{$lcnick} = $alias{$lcnewnick};
                            } elsif ($nick =~ /^Guest/o) {
                                $alias{$lcnick} = $newnick;
                                $alias{$lcnewnick} = $newnick;
                            } else {
                                $alias{$lcnewnick} = $nick;
                                $alias{$lcnick} = $nick;
                            }
                        } elsif (!defined($alias{$lcnewnick})) {
                            $alias{$lcnewnick} = $nick;
                        }
                    }
                }

            }

            if ($hour < $oldtime) { $days++ }
            $oldtime = $hour;

        }
    }

    close(LOGFILE);

    my ($sec,$min,$hour) = gmtime(time() - $conf->{start});
    $processtime = sprintf("%02d hours, %02d minutes and %02d seconds", $hour,  $min, $sec);

    $nicks = scalar keys %line;

    print "Finished analyzing log, $days days total.\n";
}

sub opchanges
{
    my (@ops, $plus);
    while ($_[0] =~ s/^(.)//o) {
        if ($1 eq "o") {
            $ops[$plus]++;
        } elsif ($1 eq "+") {
            $plus = 0;
        } elsif ($1 eq "-") {
            $plus = 1;
        }
    }

    return @ops;
}

sub parse_words
{
    my $saying = shift;
    my $nick = shift;

    foreach my $word (split(/[\s,!?.:;)(]+/o, $saying)) {
        $words{$nick}++;
        # remove uninteresting words
        next unless (length($word) >= $conf->{wordlength});
        next if ($conf->{ignoreword}{$word});

        # ignore contractions
        next if ($word =~ m/'..?$/o);

	# Also ignore stuff from URLs.
	next if ($word =~ m{https?|^//});

        $wordcount{$word}++ unless ($users->{ignores}{$word});
        $lastused{$word} = $nick;
    }

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
    $line =~ s/$colorcode\d{1,2},\d{1,2}//go;
    $line =~ s/$colorcode\d{0,2}//go;
    # Strip mIRC bold, plain, reverse and underline codes
    $line =~ s/[$boldcode$underlinecode$reversecode$plaincode]//go;

    return $line;
}

sub htmlentities
{
    my $str = shift;

    $str =~ s/\&/\&amp;/go;
    $str =~ s/\</\&lt;/go;
    $str =~ s/\>/\&gt;/go;
    $str =~ s/ü/&uuml;/go;
    $str =~ s/ö/&ouml;/go;
    $str =~ s/ä/&auml;/go;
    $str =~ s/ß/&szlig;/go;
    $str =~ s/å/&aring;/go;
    $str =~ s/æ/&aelig;/go;
    $str =~ s/ø/&oslash;/go;

    return $str;
}

sub html
{
    my $html = shift;
    print OUTPUT "$html\n";
}

sub template_text
{
    # This function is for the homemade template system. It receives a name
    # of a template and a hash with the fields in the template to update to
    # its corresponding value
    my $template = shift;
    my %hash = @_;

    my $text;

    unless ($text = $T{$conf->{lang}}{$template}) {
        # Fall back to English if the language template doesn't exist

        if ($text = $T{EN}{$template}) {
            print "Note: There was no translation in $conf->{lang} for '$template' - falling back to English..\n";
        } else {
            die("No such template '$template' in language file.\n");
        }

    }

    $hash{channel} = $conf->{channel};

    foreach my $key (sort keys %hash) {
        $text =~ s/\[:$key\]/$hash{$key}/;
        $text =~ s/ü/&uuml;/go;
        $text =~ s/ö/&ouml;/go;
        $text =~ s/ä/&auml;/go;
        $text =~ s/ß/&szlig;/go;
        $text =~ s/å/&aring;/go;
        $text =~ s/æ/&aelig;/go;
        $text =~ s/ø/&oslash;/go;
    }

    if ($text =~ /\[:.*?:.*?:\]/o) {
        $text =~ s/\[:(.*?):(.*?):\]/get_subst($1,$2,\%hash)/geo;
    }
    return $text;

}

sub get_subst {
    my ($m,$f,$hash) = @_;
    if ($hash->{nick} && $users->{sex}{$hash->{nick}}) {
        if ($users->{sex}{$hash->{nick}} eq 'm') {
            return $m;
        } elsif ($users->{sex}{$hash->{nick}} eq 'f') {
            return $f;
        } 
    }
    return "$m/$f";
}

sub replace_links
{
    # Sub to replace urls and e-mail addys to links
    my $str = shift;
    my $nick = shift;

    if ($nick) {
        $str =~ s/(http|https|ftp|telnet|news)(:\/\/[-a-zA-Z0-9_]+\.[-a-zA-Z0-9.,_~=:;&@%?#\/+]+)/<a href="$1$2" target="_blank" title="Open in new window: $1$2">$nick<\/a>/go;
        $str =~ s/([-a-zA-Z0-9._]+@[-a-zA-Z0-9_]+\.[-a-zA-Z0-9._]+)/<a href="mailto:$1" title="Mail to $nick">$nick<\/a>/go;
    } else {
        $str =~ s/(http|https|ftp|telnet|news)(:\/\/[-a-zA-Z0-9_]+\.[-a-zA-Z0-9.,_~=:;&@%?#\/+]+)/<a href="$1$2" target="_blank" title="Open in new window: $1$2">$1$2<\/a>/go;
        $str =~ s/([-a-zA-Z0-9._]+@[-a-zA-Z0-9_]+\.[-a-zA-Z0-9._]+)/<a href="mailto:$1" title="Mail to $1">$1<\/a>/go;
    }


    return $str;

}

$debug = sub {
    if ($conf->{debug} or not $conf->{debugstarted}) {
	my $debugline = $_[0] . "\n";
	if ($conf->{debugstarted}) {
	    print DEBUG $debugline;
	} else {
	    $conf->{debugqueue} .= $debugline;
	}
    }
};

sub find_alias
{
    my $nick = shift;
    my $lcnick = lc($nick);

    if ($alias{$lcnick}) {
        return $alias{$lcnick};
    } elsif ($conf->{aliaswilds}) {
        foreach (keys %{ $conf->{aliaswilds} }) {
            if ($nick =~ /^$_$/i) {
	        $alias{$lcnick} = $conf->{aliaswilds}{$_};
                return $conf->{aliaswilds}{$_};
            }
        }
    }

    return $nick;
}

sub create_html
{

    # This is where all subroutines get executed, you can actually design
    # your own layout here, the lines should be self-explainable

    print "Now generating HTML($conf->{outputfile})...\n";

    open (OUTPUT, "> $conf->{outputfile}") or die("$0: Unable to open outputfile($conf->{outputfile}): $!\n");

    if ($conf->{show_time}) {
        $conf->{tablewidth} += 40;
    }
    if ($conf->{show_words}) {
        $conf->{tablewidth} += 40;
    }
    if ($conf->{show_wpl}) {
        $conf->{tablewidth} += 40;
    }
    if ($conf->{show_cpl}) {
        $conf->{tablewidth} += 40;
    }
    $conf->{headwidth} = $conf->{tablewidth} - 4;
    htmlheader();
    pageheader();
    activetimes();
    activenicks();

    headline(template_text('bignumtopic'));
    html("<table width=\"$conf->{tablewidth}\">\n"); # Needed for sections
    questions();
    loudpeople();
    shoutpeople();
    violent();
    mostsmiles();
    mostsad();
    longlines();
    shortlines();
    mostwords();
    mostwordsperline();
    html("</table>"); # Needed for sections

    mostusedword();

    mostreferencednicks();

    mosturls();

    headline(template_text('othernumtopic'));
    html("<table width=\"$conf->{tablewidth}\">\n"); # Needed for sections
    gotkicks();
    mostkicks();
    mostop();
    mostactions();
    mostmonologues();
    mostjoins();
    mostfoul();
    html("</table>"); # Needed for sections

    headline(template_text('latesttopic'));
    html("<table width=\"$conf->{tablewidth}\">\n"); # Needed for sections
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
        $debug->("Time: $hour => ". $times{$hour});
        $image = "pic_v_".(int($hour/6)*6);
        $image = $conf->{$image};
        $debug->("Image: $image");

        my $size = ($times{$hour} / $highest_value) * 100;
        my $percent = ($times{$hour} / $lines) * 100;
        $percent =~ s/(\.\d)\d+/$1/;

        if ($size < 1 && $size != 0) {
            # Opera doesn't understand '0.xxxx' in the height="xx" attr,
            # so we simply round up to 1.0 here.

            $size = 1.0;
        }

        if ($conf->{timeoffset} =~ /\+(\d+)/) {
            # We must plus some hours to the time
            $hour += $1;
            $hour = $hour % 24;
            if ($hour < 10) { $hour = "0" . $hour; }

        } elsif ($conf->{timeoffset} =~ /-(\d+)/) {
            # We must remove some hours from the time
            $hour -= $1;
            $hour = $hour % 24;
            if ($hour < 10) { $hour = "0" . $hour; }
        }

        $output{$hour} = "<td align=\"center\" valign=\"bottom\" class=\"asmall\">$percent%<br><img src=\"$image\" width=\"15\" height=\"$size\" alt=\"$percent\"></td>\n";
    }

    html("<table border=\"0\" width=\"$conf->{tablewidth}\"><tr>\n");

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

    if($conf->{show_legend} == 1) {
        &legend();
    }
}

sub legend
{
    html("<table align=\"center\" border=\"0\" width=\"520\"><tr>");
    html("<td align=\"center\" class=\"asmall\"><img src=\"$conf->{pic_h_0}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"\"> = 0-5</td>");
    html("<td align=\"center\" class=\"asmall\"><img src=\"$conf->{pic_h_6}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"\"> = 6-11</td>");
    html("<td align=\"center\" class=\"asmall\"><img src=\"$conf->{pic_h_12}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"\"> = 12-17</td>");
    html("<td align=\"center\" class=\"asmall\"><img src=\"$conf->{pic_h_18}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"\"> = 18-23</td>");
    html("</tr></table>\n");
}

sub activenicks
{
    # The most active nicks (those who wrote most lines)

    headline(template_text('activenickstopic'));

    html("<table border=\"0\" width=\"$conf->{tablewidth}\"><tr>");
    html("<td>&nbsp;</td><td bgcolor=\"$conf->{tdtop}\"><b>"
    . template_text('nick') . "</b></td><td bgcolor=\"$conf->{tdtop}\"><b>"
    . template_text('numberlines')
    . "</b></td><td bgcolor=\"$conf->{tdtop}\"><b>"
    . ($conf->{show_time} ? template_text('show_time')."</b></td><td bgcolor=\"$conf->{tdtop}\"><b>" : "")
    . ($conf->{show_words} ? template_text('show_words')."</b></td><td bgcolor=\"$conf->{tdtop}\"><b>" : "")
    . ($conf->{show_wpl} ? template_text('show_wpl')."</b></td><td bgcolor=\"$conf->{tdtop}\"><b>" : "")
    . ($conf->{show_cpl} ? template_text('show_cpl')."</b></td><td bgcolor=\"$conf->{tdtop}\"><b>" : "")
    . template_text('randquote') ."</b></td>");
    if (scalar keys %{$users->{userpics}} > 0) {
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('userpic') ."</b></td>");
    }

    html("</tr>");

    my @active = sort { $line{$b} <=> $line{$a} } keys %line;

    if ($conf->{activenicks} > $nicks) {
        $conf->{activenicks} = $nicks;
        print "Note: There was less nicks in the logfile than your specificied there to be in most active nicks...\n";
    }

    my ($nick, $visiblenick, $randomline, %hash);
    my $i = 1;
    for (my $c = 0; $c < $conf->{activenicks}; $c++) {
        $nick = $active[$c];
        $visiblenick = $active[$c];

        if (!$longlines{$nick}) {
            $randomline = "";
        } else {
            $randomline = htmlentities($sayings{$nick});
        }

        # Convert URLs and e-mail addys to links
        $randomline = replace_links($randomline);

        # Add a link to the nick if there is any
        if ($users->{userlinks}{$nick}) {
            $visiblenick = replace_links($users->{userlinks}{$nick}, $nick);
        }

        my $h = $conf->{hicell};
        $h =~ s/^#//;
        $h = hex $h;
        my $h2 = $conf->{hicell2};
        $h2 =~ s/^#//;
        $h2 = hex $h2;
        my $f_b = $h & 0xff;
        my $f_g = ($h & 0xff00) >> 8;
        my $f_r = ($h & 0xff0000) >> 16;
        my $t_b = $h2 & 0xff;
        my $t_g = ($h2 & 0xff00) >> 8;
        my $t_r = ($h2 & 0xff0000) >> 16;
        my $col_b  = sprintf "%0.2x", abs int(((($t_b - $f_b) / $conf->{activenicks}) * +$c) + $f_b);
        my $col_g  = sprintf "%0.2x", abs int(((($t_g - $f_g) / $conf->{activenicks}) * +$c) + $f_g);
        my $col_r  = sprintf "%0.2x", abs int(((($t_r - $f_r) / $conf->{activenicks}) * +$c) + $f_r);


        html("<tr><td bgcolor=\"$conf->{rankc}\" align=\"left\">");
        my $line = $line{$nick};
        my $w    = $words{$nick};
        my $ch   = $length{$nick};
        html("$i</td><td bgcolor=\"#$col_r$col_g$col_b\">$visiblenick</td>"
        . ($conf->{show_linetime} ?
        "<td bgcolor=\"$col_r$col_g$col_b\">".user_linetimes($nick,$active[0])."</td>"
        : "<td bgcolor=\"#$col_r$col_g$col_b\">$line</td>")
        . ($conf->{show_time} ?
        "<td bgcolor=\"$col_r$col_g$col_b\">".user_times($nick)."</td>"
        : "")
        . ($conf->{show_words} ?
        "<td bgcolor=\"#$col_r$col_g$col_b\">$w</td>"
        : "")
        . ($conf->{show_wpl} ?
        "<td bgcolor=\"#$col_r$col_g$col_b\">".sprintf("%.1f",$w/$line)."</td>"
        : "")
        . ($conf->{show_cpl} ?
        "<td bgcolor=\"#$col_r$col_g$col_b\">".sprintf("%.1f",$ch/$line)."</td>"
        : "")
        ."<td bgcolor=\"#$col_r$col_g$col_b\">");
        html("\"$randomline\"</td>");

        if ($users->{userpics}{$nick}) {
            html("<td bgcolor=\"#$col_r$col_g$col_b\" align=\"center\"><img valign=\"middle\" src=\"$conf->{imagepath}$users->{userpics}{$nick}\"></td>");
        }

        html("</tr>");
        $i++;
    }

    html("</table><br>");

    # Almost as active nicks ('These didn't make it to the top..')

    my $nickstoshow = $conf->{activenicks} + $conf->{activenicks2};
    $hash{totalnicks} = $nicks - $nickstoshow;

    unless ($nickstoshow > $nicks) {

        html("<br><b><i>" . template_text('nottop') . "</i></b><table><tr>");
        for (my $c = $conf->{activenicks}; $c < $nickstoshow; $c++) {
            unless ($c % 5) { unless ($c == $conf->{activenicks}) { html("</tr><tr>"); } }
            html("<td bgcolor=\"$conf->{rankc}\" class=\"small\">");
            my $nick = $active[$c];
            my $lines = $line{$nick};
            html("$nick ($lines)</td>");
        }

        html("</table>");
    }

    if($hash{totalnicks} > 0) {
        html("<br><b>" . template_text('totalnicks', %hash) . "</b><br>");
    }
}

sub user_linetimes {
    my $nick = shift;
    my $top  = shift;
    my $bar   = "";
    my $len = ($line{$nick} / $line{$top}) * 100;
    my $debuglen = 0;
    for (my $i = 0; $i <= 3; $i++) {
        next if not defined $line_time{$nick}[$i];
        my $w = int(($line_time{$nick}[$i] / $line{$nick}) * $len);
        $debuglen += $w;
        if ($w) {
            my $pic = 'pic_h_'.(6*$i);
            $bar .= "<img src=\"$conf->{$pic}\" border=\"0\" width=\"$w\" height=\"15\" align=\"middle\" alt=\"\">";
        }
    }
    $debug->("Length='$len', Sum='$debuglen'");
    return "$bar&nbsp;$line{$nick}";
}

sub user_times {
    my $nick = shift;
    my $bar   = "";
    for (my $i = 0; $i <= 3; $i++) {
        next if not defined $line_time{$nick}[$i];
        my $w = int(($line_time{$nick}[$i] / $line{$nick}) * 40);
        if ($w) {
            my $pic = 'pic_h_'.(6*$i);
            $bar .= "<img src=\"$conf->{$pic}\" border=\"0\" width=\"$w\" height=\"15\" alt=\"\">";
        }
    }
    return $bar;
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

        html("<table border=\"0\" width=\"$conf->{tablewidth}\"><tr>");
        html("<td>&nbsp;</td><td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('word') . "</b></td>");
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('numberuses') . "</b></td>");
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('lastused') . "</b></td>");


        for(my $i = 0; $i < 10; $i++) {
            last unless $i < $#popular;
            my $a = $i + 1;
            my $popular = $popular[$i];
            my $wordcount = htmlentities($wordcount{$popular[$i]});
            my $lastused = htmlentities($lastused{$popular[$i]});
            html("<tr><td bgcolor=\"$conf->{rankc}\"><b>$a</b>");
            html("<td bgcolor=\"$conf->{hicell}\">$popular</td>");
            html("<td bgcolor=\"$conf->{hicell}\">$wordcount</td>");
            html("<td bgcolor=\"$conf->{hicell}\">$lastused</td>");
            html("</tr>");
       }

       html("</table>");
   }

}

sub mostwordsperline
{
     # The person who got words the most

     my %wpl = ();
     my ($numlines,$avg,$numwords);
     foreach my $n (keys %words) {
         $wpl{$n} = sprintf("%.2f", eval("$words{$n}/$line{$n}"));
         $numlines += $line{$n};
         $numwords += $words{$n};
     }
     $avg = sprintf("%.2f", eval("$numwords/$numlines"));
     my @wpl = sort { $wpl{$b} <=> $wpl{$a} } keys %wpl;

     if (@wpl) {
         my %hash = (
             nick => $wpl[0],
             wpl => $wpl{$wpl[0]}
         );

         my $text = template_text('wpl1', %hash);
         html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

         %hash = (
             avg => $avg
         );

         $text = template_text('wpl2', %hash);
             html("<br><span class=\"small\">$text</span>");
         html("</td></tr>");
     } else {
         my $text = template_text('wpl3');
         html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
     }

}

sub mostreferencednicks
{
    my %usages;

    foreach my $word (sort keys %wordcount) {
        next unless exists $line{$word};
        $usages{$word} = $wordcount{$word};
    }

    my @popular = sort { $usages{$b} <=> $usages{$a} } keys %usages;

    if (@popular) {

        &headline(template_text('referencetopic'));

        html("<table border=\"0\" width=\"$conf->{tablewidth}\"><tr>");
        html("<td>&nbsp;</td><td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('nick') . "</b></td>");
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('numberuses') . "</b></td>");
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('lastused') . "</b></td>");

       for(my $i = 0; $i < 5; $i++) {
           last unless $i < $#popular;
           my $a = $i + 1;
           my $popular = $popular[$i];
           my $wordcount = $wordcount{$popular[$i]};
           my $lastused = $lastused{$popular[$i]};
           html("<tr><td bgcolor=\"$conf->{rankc}\"><b>$a</b>");
           html("<td bgcolor=\"$conf->{hicell}\">$popular</td>");
           html("<td bgcolor=\"$conf->{hicell}\">$wordcount</td>");
           html("<td bgcolor=\"$conf->{hicell}\">$lastused</td>");
           html("</tr>");
       }
   html("</table>");
   }

}

sub mosturls
{
    my %toll;
    my $k = 0;
    foreach(@urls) {
        if($_ eq $urls[$k]) {
            $toll{$_}++;
        }
        $k++;
    }
    my @sorturls = sort { $toll{$b} <=> $toll{$a} } keys %toll;

    if (@sorturls) {

        &headline(template_text('urlstopic'));

        html("<table border=\"0\" width=\"$conf->{tablewidth}\"><tr>");
        html("<td>&nbsp;</td><td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('url') . "</b></td>");
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('numberuses') . "</b></td>");
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('lastused') . "</b></td>");

       for(my $i = 0; $i < 5; $i++) {
           last unless $i < $#sorturls;
           my $a = $i + 1;
           my $sorturl = $sorturls[$i];
           my $urlcount = $toll{$sorturls[$i]};
           my $lastused = $urlnick{$sorturls[$i]};
           if (length($sorturl) > 60) {
               $sorturl = substr($sorturl, 0, 60);
           }
           html("<tr><td bgcolor=\"$conf->{rankc}\"><b>$a</b>");
           html("<td bgcolor=\"$conf->{hicell}\"><a href=\"$sorturls[$i]\">$sorturl</a></td>");
           html("<td bgcolor=\"$conf->{hicell}\">$urlcount</td>");
           html("<td bgcolor=\"$conf->{hicell}\">$lastused</td>");
           html("</tr>");
       }
   html("</table>");
   }

}

sub questions
{
    # Persons who asked the most questions
    my %qpercent;

    foreach my $nick (sort keys %question) {
        if ($line{$nick} > 100) {
            $qpercent{$nick} = eval("($question{$nick} / $line{$nick}) * 100");
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
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
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
        html("<tr><td bgcolor=\"$conf->{hicell}\">" . template_text('question3') . "</td></tr>");
    }
}

sub loudpeople
{
    # The ones who speak LOUDLY!
    my %lpercent;

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
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
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
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
    }

}

sub shoutpeople
{
    # The ones who speak SHOUTED!

    my %spercent;

    foreach my $nick (sort keys %shout) {
        if ($line{$nick} > 100) {
            $spercent{$nick} = eval("($shout{$nick} / $line{$nick}) * 100");
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @shout = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;

    if (@shout) {
        my %hash = (
            nick => $shout[0],
            per => $spercent{$shout[0]},
            line => htmlentities($shoutline{$shout[0]})
        );

        my $text = template_text('shout1', %hash);
        if($conf->{show_shoutline}) {
            my $exttext = template_text('shouttext', %hash);
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
        }
        if (@shout >= 2) {
            my %hash = (
                nick => $shout[1],
                per => $spercent{$shout[1]}
            );

            my $text = template_text('shout2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");

    } else {
        my $text = template_text('shout3');
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
    }

}

sub violent
{
    # They attacked others

    my @agressors;

    foreach my $nick (sort keys %violence) {
        @agressors = sort { $violence{$b} <=> $violence{$a} } keys %violence;
    }

    if(@agressors) {
        my %hash = (
            nick    => $agressors[0],
            attacks => $violence{$agressors[0]},
            line    => htmlentities($violenceline{$agressors[0]})
        );
        my $text = template_text('violent1', %hash);
        if($conf->{show_violentlines}) {
            my $exttext = template_text('violenttext', %hash);
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
        }
        if (@agressors >= 2) {
            my %hash = (
                nick    => $agressors[1],
                attacks => $violence{$agressors[1]}
            );

            my $text = template_text('violent2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");
    } else {
        my $text = template_text('violent3');
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
    }


    # They got attacked
    my @victims;
    foreach my $nick (sort keys %attacked) {
        @victims = sort { $attacked{$b} <=> $attacked{$a} } keys %attacked;
    }

    if(@victims) {
        my %hash = (
            nick    => $victims[0],
            attacks => $attacked{$victims[0]},
            line    => htmlentities($attackedline{$victims[0]})
        );
        my $text = template_text('attacked1', %hash);
        if($conf->{show_violentlines}) {
            my $exttext = template_text('attackedtext', %hash);
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
        }
        if (@victims >= 2) {
            my %hash = (
                nick    => $victims[1],
                attacks => $attacked{$victims[1]}
            );

            my $text = template_text('attacked2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");
    }
}

sub gotkicks
{
    # The persons who got kicked the most

    my @gotkick = sort { $gotkick{$b} <=> $gotkick{$a} } keys %gotkick;
    if (@gotkick) {
        my %hash = (
            nick => $gotkick[0],
            kicks => $gotkick{$gotkick[0]},
            line => $kickline{$gotkick[0]}
        );

        my $text = template_text('gotkick1', %hash);

        if ($conf->{show_kickline}) {
            my $exttext = template_text('kicktext', %hash);
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
        }

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

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
    }
}

sub mostwords
{
     # The person who got words the most

     my @words = sort { $words{$b} <=> $words{$a} } keys %words;

     if (@words) {
         my %hash = (
             nick => $words[0],
             words => $words{$words[0]}
         );

         my $text = template_text('words1', %hash);
         html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

         if (@words >= 2) {
         my %hash = (
             oldnick => $words[0],
             nick => $words[1],
             words => $words{$words[1]}
         );

         my $text = template_text('words2', %hash);
             html("<br><span class=\"small\">$text</span>");
         }
         html("</td></tr>");
     } else {
         my $text = template_text('kick3');
         html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
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
         html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

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
         html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
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

         html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
         if (@monologue >= 2) {
             my %hash = (
                 nick => $monologue[1],
                 monos => $monologue{$monologue[1]}
             );

             my $text = template_text('mono2', %hash);
             if ($monologue{$monologue[1]} == 1 && $conf->{lang} eq 'EN') {
                $text = substr $text, 0, -1;
             }
             html("<br><span class=\"small\">$text</span>");
         }
         html("</td></tr>");
     }
}

sub longlines
{
    # The person(s) who wrote the longest lines

    my %len;

    foreach my $nick (sort keys %length) {
        if ($line{$nick} > 100) {
            $len{$nick} = eval("$length{$nick} / $line{$nick}");
            $len{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @len = sort { $len{$b} <=> $len{$a} } keys %len;

    my $all_lines = $normals + $actions;

    my $totalaverage;

    if ($all_lines > 0) {
        $totalaverage = eval("$totallength / $all_lines");
        $totalaverage =~ s/(\.\d)\d+/$1/;
    }

    if (@len) {
        my %hash = (
            nick => $len[0],
            letters => $len{$len[0]}
        );

        my $text = template_text('long1', %hash);
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text<br>");

        if (@len >= 2) {
            %hash = (
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
            $len{$nick} = eval("$length{$nick} / $line{$nick}");
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
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text<br>");

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
            $spercent{$nick} = eval("($foul{$nick} / $line{$nick}) * 100");
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

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

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
        my $text = template_text('foul3');

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
    }
}


sub mostsad
{
    my %spercent;

    foreach my $nick (sort keys %sadface) {
        if ($line{$nick} > 100) {
            $spercent{$nick} = eval("($sadface{$nick} / $line{$nick}) * 100");
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
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

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
        my $text = template_text('sad3');
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
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

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

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
        my $text = template_text('mostop3');
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
    }
    if (@deops) {
        my %hash = (
            nick => $deops[0],
            deops => $tookop{$deops[0]}
        );
        my $text = template_text('mostdeop1', %hash);

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

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
        my $text = template_text('mostdeop3');
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
    }
}

sub mostactions
{

    # The person who did the most /me's

    my @actions = sort { $actions{$b} <=> $actions{$a} } keys %actions;

    if (@actions) {
        my %hash = (
            nick => $actions[0],
            actions => $actions{$actions[0]},
            line => htmlentities($actionline{$actions[0]})
        );
        my $text = template_text('action1', %hash);
        if($conf->{show_actionline}) {
            my $exttext = template_text('actiontext', %hash);
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");  
        } else {
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
        }

        if (@actions >= 2) {
            my %hash = (
                nick => $actions[1],
                actions => $actions{$actions[1]}
            );

            my $text = template_text('action2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");
    } else {
        my $text = template_text('action3');
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
    }

}


sub mostsmiles
{
    # The person(s) who smiled the most :-)

    my %spercent;

    foreach my $nick (sort keys %smile) {
        if ($line{$nick} > 100) {
            $spercent{$nick} = eval("($smile{$nick} / $line{$nick}) * 100");
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

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
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

        my $text = template_text('smiles3');
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
    }
}

sub lasttopics
{
    $debug->("Total number of topics: ". scalar @topics);

    my %hash = (
        total => scalar @topics
    );

    if (@topics) {
        my $ltopic = @topics - 1;
        my $tlimit = 0;

        $conf->{topichistory} -= 1;


        if ($ltopic > $conf->{topichistory}) { $tlimit = $ltopic - $conf->{topichistory}; }

        for (my $i = $ltopic; $i >= $tlimit; $i--) {
            $topics[$i]{"topic"} = htmlentities(strip_mirccodes($topics[$i]{"topic"}));
            my $topic = replace_links($topics[$i]{topic});
            # Strip off the quotes (')
            $topic =~ s/^\'(.*)\'$/$1/;

            my $nick = $topics[$i]{nick};
            my $hour = $topics[$i]{hour};
            my $min = $topics[$i]{min};
            html("<tr><td bgcolor=\"$conf->{hicell}\"><i>$topic</i></td>");
            html("<td bgcolor=\"$conf->{hicell}\">By <b>$nick</b> at <b>$hour:$min</b></td></tr>");
        }
    } else {
        html("<tr><td bgcolor=\"$conf->{hicell}\">" . template_text('notopic') ."</td></tr>");
    }
    if(@topics) {
        html("<tr><td align=\"center\" colspan=\"2\" class=\"asmall\">" . template_text('totaltopic', %hash) . "</td></tr>");
    }
}


# Some HTML subs
sub htmlheader
{
my $bgpic = "";
if ($conf->{bgpic}) {
    $bgpic = " background=\"$conf->{bgpic}\"";
}
print OUTPUT <<HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>$conf->{channel} @ $conf->{network} channel statistics</title>
<style type="text/css">
a { text-decoration: none }
a:link { color: $conf->{link}; }
a:visited { color: $conf->{vlink}; }
a:hover { text-decoration: underline; color: $conf->{hlink} }

body {
    background-color: $conf->{bgcolor};
    font-family: verdana, arial, sans-serif;
    font-size: 13px;
    color: $conf->{text};
}

td {
    font-family: verdana, arial, sans-serif;
    font-size: 13px;
    color: $conf->{tdcolor};
}

.title {
    font-family: tahoma, arial, sans-serif;
    font-size: 16px;
    font-weight: bold;
}

.headline { color: $conf->{hcolor}; }
.small { font-family: verdana, arial, sans-serif; font-size: 10px; }
.asmall { 
      font-family: arial narrow, sans-serif; 
      font-size: 10px;
      color: $conf->{text};
}
</style></head>
<body$bgpic>
<div align="center">
HTML
my %hash = (
    network => $conf->{network},
    maintainer => $conf->{maintainer},
    time => $time,
    days => $days,
    nicks => $nicks
);
print OUTPUT "<span class=\"title\">" . template_text('pagetitle1', %hash) . "</span><br>";
print OUTPUT "<br>";
print OUTPUT template_text('pagetitle2', %hash);

sub timefix {

    my ($timezone, $sec, $min, $hour, $mday, $mon, $year, $wday, $month, $day, $tday, $wdisplay, @month, @day, $timefixx, %hash);

    $month = template_text('month', %hash);
    $day = template_text('day', %hash);

    @month=split / /, $month;
    @day=split / /, $day;

    # Get the Date from the users computer
    $timezone = $conf->{timeoffset} * 3600;
    ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time+$timezone);

    $year += 1900;                    # Y2K Patch

    $min =~ s/^(.)$/0$1/;             # Fixes the display of mins/secs below
    $sec =~ s/^(.)$/0$1/;             # it displays 03 instead of 3

    if($hour > '23') {                 # Checks to see if it Midnight
        $hour = 12;                   # Makes it display the hour 12
        $tday = "AM";                 # Display AM
    }
    elsif($hour > '12') {              # Get rid of the Military time and
        $hour -= 12;                  # put it into normal time
        $tday = "PM";                 # If past Noon and before Midnight set
    }                                 # the time as PM
    else {
        $tday = "AM";                 # If it's past Midnight and before Noon
    }                                 # set the time as AM

    # Use 24 hours pr. day
    if($tday eq "PM" && $hour < '12') {
        $hour += 12;
    }

    print OUTPUT "$day[$wday] $mday $month[$mon] $year - $hour:$min:$sec\n";

}

timefix();

print OUTPUT "<br>" . template_text('pagetitle3', %hash) . "<br><br>";

}

sub htmlfooter
{
print OUTPUT <<HTML;
<span class="small">
Stats generated by <a href="http://pisg.sourceforge.net/" title="Go to the pisg homepage">pisg</a> $conf->{version}<br>
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
   <table width="$conf->{headwidth}" cellpadding="1" cellspacing="0" border="0">
    <tr>
     <td bgcolor="$conf->{headline}">
      <table width="100%" cellpadding="2" cellspacing="0" border="0" align="center">
       <tr>
        <td bgcolor="$conf->{hbgcolor}" class="text10">
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
    if ($conf->{pagehead} ne 'none') {
        open(PAGEHEAD, $conf->{pagehead}) or die("$0: Unable to open $conf->{pagehead} for reading: $!\n");
        while (<PAGEHEAD>) {
            html($_);
        }
    }
}

sub close_debug
{
    if ($conf->{debug}) {
        close(DEBUG) or print STDERR "$0: Cannot close debugfile($conf->{debugfile}): $!\n";
    }
}

sub get_cmdlineoptions
{
    my $tmp;
    # Commandline options
    my ($channel, $logfile, $format, $network, $maintainer, $outputfile, $logdir, $prefix, $configfile, $help);

my $usage = <<END_USAGE;
Usage: pisg.pl [-c channel] [-l logfile] [-o outputfile] [-m
maintainer]  [-f format] [-n network] [-d logdir] [-a aliasfile]
[-i ignorefile] [-h]

-ch --channel=xxx      : Set channel name
-l --logfile=xxx       : Log file to parse
-o --outfile=xxx       : Name of html file to create
-m --maintainer=xxx    : Channel/statistics maintainer
-f --format=xxx        : Logfile format [see FORMATS file]
-n --network=xxx       : IRC Network this channel is on.
-d --dir=xxx           : Analyze all files in this dir. Ignores logfile.
-p --prefix=xxx        : Analyse only files starting with xxx in dir.
                         Only works with --dir
-co --configfile=xxx   : Config file
-h --help              : Output this message and exit (-? also works).

Example:

 \$ pisg.pl -n IRCnet -f xchat -o suid.html -ch \\#channel -l logfile.log

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
                   'prefix=s'     => \$prefix,
                   'ignorefile=s' => \$tmp,
                   'aliasfile=s'  => \$tmp,
                   'configfile=s' => \$configfile,
                   'help|?'       => \$help
               ) == 0 or $help) {
                   die($usage);
               }

    if ($tmp) {
        die("The aliasfile and ignorefile has been obsoleted by the new
        pisg.cfg, please use that instead [look in pisg.cfg]\n");
    }

    if ($channel) {
        $conf->{channel} = $channel;
        $conf->{cmdl}{channel} = 1;
    }

    if ($logfile) {
        $conf->{logfile} = $logfile;
        $conf->{cmdl}{logfile} = 1;
    }

    if ($format) {
        $conf->{format} = $format;
        $conf->{cmdl}{format} = 1;
    }

    if ($network) {
        $conf->{network} = $network;
        $conf->{cmdl}{network} = 1;
    }

    if ($maintainer) {
        $conf->{maintainer} = $maintainer;
        $conf->{cmdl}{maintainer} = 1;
    }

    if ($outputfile) {
        $conf->{outputfile} = $outputfile;
        $conf->{cmdl}{outputfile} = 1;
    }

    if ($logdir) {
        $conf->{logdir} = $logdir;
        $conf->{cmdl}{logdir} = 1;
    }

    if ($prefix) {
        $conf->{prefix} = $prefix;
        $conf->{cmdl}{prefix} = 1;
    }

    if ($configfile) {
        $conf->{configfile} = $configfile;
        $conf->{cmdl}{configfile} = 1;
    }

}

sub get_language_templates
{

    open(FILE, $conf->{langfile}) or open (FILE, $FindBin::Bin . "/$conf->{langfile}") or die("$0: Unable to open language file($conf->{langfile}): $!\n");


    while (my $line = <FILE>)
    {
        next if ($line =~ /^#/);

        if ($line =~ /<lang name=\"([^"]+)\">/) {
            # Found start tag, setting the current language
            my $current_lang = $1;

            while (<FILE>) {
                last if ($_ =~ /<\/lang>/i);

                # Get 'template = "Text"' in language file:
                if ($_ =~ /(\w+)\s+=\s+"(.*)"\s*$/) {
                    $T{$current_lang}{$1} = $2;
                }
            }

        }

    }

    close(FILE);


}

&main();        # Run the script
