#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use FindBin;

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
    logtype => "Logfile",
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
    nicktracking => 0,
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
    version => "v0.23-cvs",
};

my ($chans, $users);

my ($timestamp, $time, $nicks, $totallength, $oldtime, $actions, $normals, %T);

sub load_modules {
    push @INC, $conf->{modules_dir};
    require Pisg::Common;
    Pisg::Common->import();
    Pisg::Common::init_common($debug);
}

sub main {
    print "pisg $conf->{version} - Perl IRC Statistics Generator\n\n";
    get_cmdlineoptions();
    load_modules();     # Add modules, now that their location is known.
    init_config();      # Init config. (Aliases, ignores, other options etc.)
    init_debug()
        unless ($conf->{debugstarted});       # Init the debugging file
    get_language_templates(); # Get translations from lang.txt
    parse_channels();   # parse any channels in <channel> statements
    do_channel()
        unless ($conf->{chan_done}{$conf->{channel}});

    close_debug();      # Close the debugging file
}

sub do_channel
{
    init_pisg();        # Init commandline arguments and other things
    init_words();       # Init words. (Foulwords etc)

    # Pick our stats generator.
    my $analyzer;
    eval <<_END;
use Pisg::Parser::$conf->{logtype};
\$analyzer = new Pisg::Parser::$conf->{logtype}(\$conf, \$debug);
_END
    if ($@) {
        print STDERR "Could not load stats generator for '$conf->{logtype}': $@\n";
        return undef;
    }

    my $stats = $analyzer->analyze();
    create_html($stats)
        if (defined $stats and $stats->{lines} > 0);# Create the HTML
                                 # (look here if you want to remove some of the
                                 # stats which you don't care about)

    $conf->{chan_done}{$conf->{channel}} = 1;
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

    undef $totallength;

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
    $oldtime = "00";
    $actions = "0";
    $normals = "0";

    print "Using language template: $conf->{lang}\n\n" if ($conf->{lang} ne 'EN');

    print "Statistics for channel $conf->{channel} \@ $conf->{network} by $conf->{maintainer}\n\n";

}

sub init_config
{
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
                    $nick = $1;
                    add_alias($nick, $nick);
                } else {
                    print STDERR "Warning: no nick specified in $conf->{configfile} on line $lineno\n";
                    next;
                }

                if ($line =~ /alias="([^"]+)"/) {
                    my @thisalias = split(/\s+/, lc($1));
                    foreach (@thisalias) {
                        if ($conf->{regexp_aliases} and /[\|\[\]\{\}\(\)\?\+\.\*\^\\]/) {
                            add_aliaswild($nick, $_);
                        } elsif (not $conf->{regexp_aliases} and s/\*/\.\*/g) {
                            # quote it if it is a wildcard
                            s/([\|\[\]\{\}\(\)\?\+\^\\])/\\$1/g;
                            add_aliaswild($nick, $_);
                        } else {
                            add_alias($nick, $_);
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
                    add_ignore($nick);
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

sub replace_links {
    # Sub to replace urls and e-mail addys to links
    my $str = shift;
    my $nick = shift;
    my ($url, $email);

    if ($nick) {
        if ($url = match_url($str)) {
            $str =~ s/(\Q$url\E)/<a href="$1" target="_blank" title="Open in new window: $1">$nick<\/a>/g;
        }
        if ($email = match_email($str)) {
            $str =~ s/(\Q$email\E)/<a href="mailto:$1" title="Mail to $nick">$nick<\/a>/g;
        }
    } else {
        if ($url = match_url($str)) {
            $str =~ s/(\Q$url\E)/<a href="$1" target="_blank" title="Open in new window: $1">$1<\/a>/g;
        }
        if ($email = match_email($str)) {
            $str =~ s/(\Q$email\E)/<a href="mailto:$1" title="Mail to $1">$1<\/a>/g;
        }
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

sub create_html {
    # This is where all subroutines get executed, you can actually design
    # your own layout here, the lines should be self-explainable

    my ($stats) = @_;

    print "Now generating HTML($conf->{outputfile})...\n";

    open (OUTPUT, "> $conf->{outputfile}") or
        die("$0: Unable to open outputfile($conf->{outputfile}): $!\n");

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
    htmlheader($stats);
    pageheader($stats);
    activetimes($stats);
    activenicks($stats);

    headline(template_text('bignumtopic'));
    html("<table width=\"$conf->{tablewidth}\">\n"); # Needed for sections
    questions($stats);
    shoutpeople($stats);
    capspeople($stats);
    violent($stats);
    mostsmiles($stats);
    mostsad($stats);
    linelengths($stats);
    mostwords($stats);
    mostwordsperline($stats);
    html("</table>"); # Needed for sections

    mostusedword($stats);

    mostreferencednicks($stats);

    mosturls($stats);

    headline(template_text('othernumtopic'));
    html("<table width=\"$conf->{tablewidth}\">\n"); # Needed for sections
    gotkicks($stats);
    mostkicks($stats);
    mostop($stats);
    mostactions($stats);
    mostmonologues($stats);
    mostjoins($stats);
    mostfoul($stats);
    html("</table>"); # Needed for sections

    headline(template_text('latesttopic'));
    html("<table width=\"$conf->{tablewidth}\">\n"); # Needed for sections
    lasttopics($stats);
    html("</table>"); # Needed for sections

    my %hash = ( lines => $stats->{totallines} );
    html(template_text('totallines', %hash) . "<br><br>");

    htmlfooter($stats);

    close(OUTPUT);

}


sub activetimes {
    # The most actives times on the channel
    my ($stats) = @_;

    my (%output, $tbgcolor);

    &headline(template_text('activetimestopic'));

    my @toptime = sort { $stats->{times}{$b} <=> $stats->{times}{$a} } keys %{ $stats->{times} };

    my $highest_value = $stats->{times}{$toptime[0]};

    my @now = localtime($timestamp);

    my $image;

    for my $hour (sort keys %{ $stats->{times} }) {
        $debug->("Time: $hour => ". $stats->{times}{$hour});

        my $size = ($stats->{times}{$hour} / $highest_value) * 100;
        my $percent = ($stats->{times}{$hour} / $stats->{totallines}) * 100;
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
        $image = "pic_v_".(int($hour/6)*6);
        $image = $conf->{$image};
        $debug->("Image: $image");

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

sub activenicks {
    # The most active nicks (those who wrote most lines)
    my ($stats) = @_;

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

    my @active = sort { $stats->{lines}{$b} <=> $stats->{lines}{$a} } keys %{ $stats->{lines} };
    my $nicks = scalar keys %{ $stats->{lines} };

    if ($conf->{activenicks} > $nicks) {
        $conf->{activenicks} = $nicks;
        print "Note: There were fewer nicks in the logfile than your specificied there to be in most active nicks...\n";
    }

    my ($nick, $visiblenick, $randomline, %hash);
    my $i = 1;
    for (my $c = 0; $c < $conf->{activenicks}; $c++) {
        $nick = $active[$c];
        $visiblenick = $active[$c];

        if (not defined $stats->{sayings}{$nick}) {
            $randomline = "";
        } else {
            $randomline = htmlentities($stats->{sayings}{$nick});
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
        my $line = $stats->{lines}{$nick};
        my $w    = $stats->{words}{$nick};
        my $ch   = $stats->{lengths}{$nick};
        html("$i</td><td bgcolor=\"#$col_r$col_g$col_b\">$visiblenick</td>"
        . ($conf->{show_linetime} ?
        "<td bgcolor=\"$col_r$col_g$col_b\">".user_linetimes($stats,$nick,$active[0])."</td>"
        : "<td bgcolor=\"#$col_r$col_g$col_b\">$line</td>")
        . ($conf->{show_time} ?
        "<td bgcolor=\"$col_r$col_g$col_b\">".user_times($stats,$nick)."</td>"
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
            my $lines = $stats->{lines}{$nick};
            html("$nick ($lines)</td>");
        }

        html("</table>");
    }

    if($hash{totalnicks} > 0) {
        html("<br><b>" . template_text('totalnicks', %hash) . "</b><br>");
    }
}

sub user_linetimes {
    my $stats = shift;
    my $nick  = shift;
    my $top   = shift;

    my $bar      = "";
    my $len      = ($stats->{lines}{$nick} / $stats->{lines}{$top}) * 100;
    my $debuglen = 0;

    for (my $i = 0; $i <= 3; $i++) {
        next if not defined $stats->{line_times}{$nick}[$i];
        my $w = int(($stats->{line_times}{$nick}[$i] / $stats->{lines}{$nick}) * $len);
        $debuglen += $w;
        if ($w) {
            my $pic = 'pic_h_'.(6*$i);
            $bar .= "<img src=\"$conf->{$pic}\" border=\"0\" width=\"$w\" height=\"15\" align=\"middle\" alt=\"\">";
        }
    }
    $debug->("Length='$len', Sum='$debuglen'");
    return "$bar&nbsp;$stats->{lines}{$nick}";
}

sub user_times {
    my ($stats, $nick) = @_;

    my $bar = "";

    for (my $i = 0; $i <= 3; $i++) {
        next if not defined $stats->{line_times}{$nick}[$i];
        my $w = int(($stats->{line_times}{$nick}[$i] / $stats->{lines}{$nick}) * 40);
        if ($w) {
            my $pic = 'pic_h_'.(6*$i);
            $bar .= "<img src=\"$conf->{$pic}\" border=\"0\" width=\"$w\" height=\"15\" alt=\"\">";
        }
    }
    return $bar;
}

sub mostusedword {
    # Lao the infamous word usage statistics
    my ($stats) = @_;

    my %usages;

    foreach my $word (keys %{ $stats->{wordcounts} }) {
        # Skip people's nicks.
        next if exists $stats->{lines}{$word};
        $usages{$word} = $stats->{wordcounts}{$word};
    }


    my @popular = sort { $usages{$b} <=> $usages{$a} } keys %usages;

    if (@popular) {
        &headline(template_text('mostwordstopic'));

        html("<table border=\"0\" width=\"$conf->{tablewidth}\"><tr>");
        html("<td>&nbsp;</td><td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('word') . "</b></td>");
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('numberuses') . "</b></td>");
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('lastused') . "</b></td>");


        my $count = 0;
        for(my $i = 0; $count < 10; $i++) {
            last unless $i < $#popular;
            # Skip nicks.  It's far more efficient to do this here than when
            # @popular is created.
            next if is_ignored($popular[$i]);
            next if exists $stats->{lines}{find_alias($popular[$i])};
            my $a = $count + 1;
            my $popular = htmlentities($popular[$i]);
            my $wordcount = $stats->{wordcounts}{$popular[$i]};
            my $lastused = htmlentities($stats->{wordnicks}{$popular[$i]});
            html("<tr><td bgcolor=\"$conf->{rankc}\"><b>$a</b>");
            html("<td bgcolor=\"$conf->{hicell}\">$popular</td>");
            html("<td bgcolor=\"$conf->{hicell}\">$wordcount</td>");
            html("<td bgcolor=\"$conf->{hicell}\">$lastused</td>");
            html("</tr>");
            $count++;
        }

        html("</table>");
    }
}

sub mostwordsperline {
    # The person who got words the most
    my ($stats) = @_;

    my %wpl = ();
    my ($numlines,$avg,$numwords);
    foreach my $n (keys %{ $stats->{words} }) {
        $wpl{$n} = sprintf("%.2f", $stats->{words}{$n}/$stats->{lines}{$n});
        $numlines += $stats->{lines}{$n};
        $numwords += $stats->{words}{$n};
    }
    $avg = sprintf("%.2f", $numwords/$numlines);

    my @wpl = sort { $wpl{$b} <=> $wpl{$a} } keys %wpl;

    if (@wpl) {
        my %hash = (
            nick => $wpl[0],
            wpl  => $wpl{$wpl[0]}
        );

        my $text = template_text('wpl1', %hash);
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

        %hash = (
            avg => $avg
        );

        $text = template_text('wpl2', %hash);
        html("<br><span class=\"small\">$text</span>");
        html("</td></tr>");
    }
}

sub mostreferencednicks {
    my ($stats) = @_;

    my (%usages);

    foreach my $word (sort keys %{ $stats->{wordcounts} }) {
        next unless exists $stats->{lines}{$word};
        next if is_ignored($word);
        $usages{$word} = $stats->{wordcounts}{$word};
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
            my $popular   = $popular[$i];
            my $wordcount = $stats->{wordcounts}{$popular[$i]};
            my $lastused  = $stats->{wordnicks}{$popular[$i]};
            html("<tr><td bgcolor=\"$conf->{rankc}\"><b>$a</b>");
            html("<td bgcolor=\"$conf->{hicell}\">$popular</td>");
            html("<td bgcolor=\"$conf->{hicell}\">$wordcount</td>");
            html("<td bgcolor=\"$conf->{hicell}\">$lastused</td>");
            html("</tr>");
        }
        html("</table>");
    }
}

sub mosturls {
    my ($stats) = @_;

    my @sorturls = sort { $stats->{urlcounts}{$b} <=> $stats->{urlcounts}{$a} }
			keys %{ $stats->{urlcounts} };

    if (@sorturls) {

        &headline(template_text('urlstopic'));

        html("<table border=\"0\" width=\"$conf->{tablewidth}\"><tr>");
        html("<td>&nbsp;</td><td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('url') . "</b></td>");
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('numberuses') . "</b></td>");
        html("<td bgcolor=\"$conf->{tdtop}\"><b>" . template_text('lastused') . "</b></td>");

        for(my $i = 0; $i < 5; $i++) {
            last unless $i < $#sorturls;
            my $a = $i + 1;
            my $sorturl  = $sorturls[$i];
            my $urlcount = $stats->{urlcounts}{$sorturls[$i]};
            my $lastused = $stats->{urlnicks}{$sorturls[$i]};
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

sub questions {
    # Persons who asked the most questions
    my ($stats) = @_;

    my %qpercent;

    foreach my $nick (sort keys %{ $stats->{questions} }) {
        if ($stats->{lines}{$nick} > 100) {
            $qpercent{$nick} = ($stats->{questions}{$nick} / $stats->{lines}{$nick}) * 100;
            $qpercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @question = sort { $qpercent{$b} <=> $qpercent{$a} } keys %qpercent;

    if (@question) {
        my %hash = (
            nick => $question[0],
            per  => $qpercent{$question[0]}
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

sub shoutpeople {
    # The ones who speak with exclamation points!
    my ($stats) = @_;

    my %spercent;

    foreach my $nick (sort keys %{ $stats->{shouts} }) {
        if ($stats->{lines}{$nick} > 100) {
            $spercent{$nick} = ($stats->{shouts}{$nick} / $stats->{lines}{$nick}) * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @shout = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;

    if (@shout) {
        my %hash = (
            nick => $shout[0],
            per  => $spercent{$shout[0]}
        );

        my $text = template_text('shout1', %hash);
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
        if (@shout >= 2) {
            my %hash = (
                nick => $shout[1],
                per  => $spercent{$shout[1]}
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

sub capspeople {
    # The ones who speak ALL CAPS.
    my ($stats) = @_;

    my %cpercent;

    foreach my $nick (sort keys %{ $stats->{allcaps} }) {
        if ($stats->{lines}{$nick} > 100) {
            $cpercent{$nick} = $stats->{allcaps}{$nick} / $stats->{lines}{$nick} * 100;
            $cpercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @caps = sort { $cpercent{$b} <=> $cpercent{$a} } keys %cpercent;

    if (@caps) {
        my %hash = (
            nick => $caps[0],
            per  => $cpercent{$caps[0]},
            line => htmlentities($stats->{allcaplines}{$caps[0]})
        );

        my $text = template_text('allcaps1', %hash);
        if($conf->{show_shoutline}) {
            my $exttext = template_text('allcapstext', %hash);
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
        }
        if (@caps >= 2) {
            my %hash = (
                nick => $caps[1],
                per  => $cpercent{$caps[1]}
            );

            my $text = template_text('allcaps2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");

    } else {
        my $text = template_text('allcaps3');
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
    }

}

sub violent {
    # They attacked others
    my ($stats) = @_;

    my @aggressors;

    @aggressors = sort { $stats->{violence}{$b} <=> $stats->{violence}{$a} }
			 keys %{ $stats->{violence} };

    if(@aggressors) {
        my %hash = (
            nick    => $aggressors[0],
            attacks => $stats->{violence}{$aggressors[0]},
            line    => htmlentities($stats->{violencelines}{$aggressors[0]})
        );
        my $text = template_text('violent1', %hash);
        if($conf->{show_violentlines}) {
            my $exttext = template_text('violenttext', %hash);
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
        }
        if (@aggressors >= 2) {
            my %hash = (
                nick    => $aggressors[1],
                attacks => $stats->{violence}{$aggressors[1]}
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
    @victims = sort { $stats->{attacked}{$b} <=> $stats->{attacked}{$a} }
		    keys %{ $stats->{attacked} };

    if(@victims) {
        my %hash = (
            nick    => $victims[0],
            attacks => $stats->{attacked}{$victims[0]},
            line    => htmlentities($stats->{attackedlines}{$victims[0]})
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
                attacks => $stats->{attacked}{$victims[1]}
            );

            my $text = template_text('attacked2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");
    }
}

sub gotkicks {
    # The persons who got kicked the most
    my ($stats) = @_;

    my @gotkick = sort { $stats->{gotkicked}{$b} <=> $stats->{gotkicked}{$a} }
		       keys %{ $stats->{gotkicked} };
    if (@gotkick) {
        my %hash = (
            nick  => $gotkick[0],
            kicks => $stats->{gotkicked}{$gotkick[0]},
            line  => $stats->{kicklines}{$gotkick[0]}
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
                nick  => $gotkick[1],
                kicks => $stats->{gotkicked}{$gotkick[1]}
            );

            my $text = template_text('gotkick2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");
    }
}

sub mostjoins {
    my ($stats) = @_;

    my @joins = sort { $stats->{joins}{$b} <=> $stats->{joins}{$a} }
		     keys %{ $stats->{joins} };

    if (@joins) {
        my %hash = (
            nick  => $joins[0],
            joins => $stats->{joins}{$joins[0]}
        );

        my $text = template_text('joins', %hash);

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text</td></tr>");
    }
}

sub mostwords {
     # The person who got words the most
    my ($stats) = @_;

     my @words = sort { $stats->{words}{$b} <=> $stats->{words}{$a} }
		      keys %{ $stats->{words} };

    if (@words) {
        my %hash = (
            nick  => $words[0],
            words => $stats->{words}{$words[0]}
        );

        my $text = template_text('words1', %hash);
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

        if (@words >= 2) {
            my %hash = (
                oldnick => $words[0],
                nick    => $words[1],
                words   => $stats->{words}{$words[1]}
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

sub mostkicks {
     # The person who got kicked the most
    my ($stats) = @_;

     my @kicked = sort { $stats->{kicked}{$b} <=> $stats->{kicked}{$a} }
		       keys %{ $stats->{kicked} };

    if (@kicked) {
        my %hash = (
            nick   => $kicked[0],
            kicked => $stats->{kicked}{$kicked[0]}
        );

        my $text = template_text('kick1', %hash);
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

        if (@kicked >= 2) {
            my %hash = (
                oldnick => $kicked[0],
                nick    => $kicked[1],
                kicked  => $stats->{kicked}{$kicked[1]}
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

sub mostmonologues {
    # The person who had the most monologues (speaking to himself)
    my ($stats) = @_;

    my @monologue = sort { $stats->{monologues}{$b} <=> $stats->{monologues}{$a} } keys %{ $stats->{monologues} };

    if (@monologue) {
        my %hash = (
            nick  => $monologue[0],
            monos => $stats->{monologues}{$monologue[0]}
        );

        my $text = template_text('mono1', %hash);

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
        if (@monologue >= 2) {
            my %hash = (
                nick  => $monologue[1],
                monos => $stats->{monologues}{$monologue[1]}
            );

            my $text = template_text('mono2', %hash);
            html("<br><span class=\"small\">$text</span>");
        }
        html("</td></tr>");
    }
}

sub linelengths {
    # The person(s) who wrote the longest lines
    my ($stats) = @_;

    my %len;

    foreach my $nick (sort keys %{ $stats->{lengths} }) {
        if ($stats->{lines}{$nick} > 100) {
            $len{$nick} = $stats->{lengths}{$nick} / $stats->{lines}{$nick};
            $len{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @len = sort { $len{$b} <=> $len{$a} } keys %len;

    my $all_lines;
    my $totallength;
    foreach my $nick (keys %{ $stats->{lines} }) {
        $all_lines   += $stats->{lines}{$nick};
        $totallength += $stats->{lengths}{$nick};
    }

    my $totalaverage;

    if ($all_lines > 0) {
        $totalaverage = $totallength / $all_lines;
        $totalaverage =~ s/(\.\d)\d+/$1/;
    }

    if (@len) {
        my %hash = (
            nick    => $len[0],
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

    # The person(s) who wrote the shortest lines

    if (@len) {
        my %hash = (
            nick => $len[$#len],
            letters => $len{$len[$#len]}
        );

        my $text = template_text('short1', %hash);
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text<br>");

        if (@len >= 2) {
            %hash = (
                nick => $len[$#len - 1],
                letters => $len{$len[$#len - 1]}
            );

            $text = template_text('short2', %hash);
            html("<span class=\"small\">$text</span></td></tr>");
        }
    }
}

sub mostfoul {
    my ($stats) = @_;

    my %spercent;

    foreach my $nick (sort keys %{ $stats->{foul} }) {
        if ($stats->{lines}{$nick} > 15) {
            $spercent{$nick} = $stats->{foul}{$nick} / $stats->{lines}{$nick} * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @foul = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@foul) {

        my %hash = (
            nick => $foul[0],
            per  => $spercent{$foul[0]}
        );

        my $text = template_text('foul1', %hash);

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

        if (@foul >= 2) {
            my %hash = (
                nick => $foul[1],
                per  => $spercent{$foul[1]}
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


sub mostsad {
    my ($stats) = @_;

    my %spercent;

    foreach my $nick (sort keys %{ $stats->{frowns} }) {
        if ($stats->{lines}{$nick} > 100) {
            $spercent{$nick} = $stats->{frowns}{$nick} / $stats->{lines}{$nick} * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @sadface = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@sadface) {
        my %hash = (
            nick => $sadface[0],
            per  => $spercent{$sadface[0]}
        );

        my $text = template_text('sad1', %hash);
        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

        if (@sadface >= 2) {
            my %hash = (
                nick => $sadface[1],
                per  => $spercent{$sadface[1]}
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


sub mostop {
    my ($stats) = @_;

    my @ops   = sort { $stats->{gaveops}{$b} <=> $stats->{gaveops}{$a} }
		     keys %{ $stats->{gaveops} };
    my @deops = sort { $stats->{tookops}{$b} <=> $stats->{tookops}{$a} }
		     keys %{ $stats->{tookops} };

    if (@ops) {
        my %hash = (
            nick => $ops[0],
            ops  => $stats->{gaveops}{$ops[0]}
        );

        my $text = template_text('mostop1', %hash);

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

        if (@ops >= 2) {
            my %hash = (
                nick => $ops[1],
                ops  => $stats->{gaveops}{$ops[1]}
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
            nick  => $deops[0],
            deops => $stats->{tookops}{$deops[0]}
        );
        my $text = template_text('mostdeop1', %hash);

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");

        if (@deops >= 2) {
            my %hash = (
                nick  => $deops[1],
                deops => $stats->{tookops}{$deops[1]}
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

sub mostactions {
    # The person who did the most /me's
    my ($stats) = @_;

    my @actions = sort { $stats->{actions}{$b} <=> $stats->{actions}{$a} }
		       keys %{ $stats->{actions} };

    if (@actions) {
        my %hash = (
            nick    => $actions[0],
            actions => $stats->{actions}{$actions[0]},
            line    => htmlentities($stats->{actionlines}{$actions[0]})
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
                nick    => $actions[1],
                actions => $stats->{actions}{$actions[1]}
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


sub mostsmiles {
    # The person(s) who smiled the most :-)
    my ($stats) = @_;

    my %spercent;

    foreach my $nick (sort keys %{ $stats->{smiles} }) {
        if ($stats->{lines}{$nick} > 100) {
            $spercent{$nick} = $stats->{smiles}{$nick} / $stats->{lines}{$nick} * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @smiles = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@smiles) {
        my %hash = (
            nick => $smiles[0],
            per  => $spercent{$smiles[0]}
        );

        my $text = template_text('smiles1', %hash);

        html("<tr><td bgcolor=\"$conf->{hicell}\">$text");
        if (@smiles >= 2) {
            my %hash = (
                nick => $smiles[1],
                per  => $spercent{$smiles[1]}
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

sub lasttopics {
    my ($stats) = @_;

    if ($stats->{topics}) {
        $debug->("Total number of topics: " . scalar @{ $stats->{topics} });

        my %hash = (
            total => scalar @{ $stats->{topics} }
        );

        my $ltopic = $#{ $stats->{topics} };
        my $tlimit = 0;

        $conf->{topichistory} -= 1;

        if ($ltopic > $conf->{topichistory}) {
            $tlimit = $ltopic - $conf->{topichistory};
        }

        for (my $i = $ltopic; $i >= $tlimit; $i--) {
            my $topic = htmlentities($stats->{topics}[$i]{topic});
            $topic = replace_links($stats->{topics}[$i]{topic});
            # Strip off the quotes (')
            $topic =~ s/^\'(.*)\'$/$1/;

            my $nick = $stats->{topics}[$i]{nick};
            my $hour = $stats->{topics}[$i]{hour};
            my $min  = $stats->{topics}[$i]{min};
            html("<tr><td bgcolor=\"$conf->{hicell}\"><i>$topic</i></td>");
            html("<td bgcolor=\"$conf->{hicell}\">By <b>$nick</b> at <b>$hour:$min</b></td></tr>");
        }
        html("<tr><td align=\"center\" colspan=\"2\" class=\"asmall\">" . template_text('totaltopic', %hash) . "</td></tr>");
    } else {
        html("<tr><td bgcolor=\"$conf->{hicell}\">" . template_text('notopic') ."</td></tr>");
    }
}


# Some HTML subs
sub htmlheader {
my ($stats) = @_;
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
    network    => $conf->{network},
    maintainer => $conf->{maintainer},
    time       => $time,
    days       => $stats->{days},
    nicks      => scalar keys %{ $stats->{lines} }
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

sub htmlfooter {
my ($stats) = @_;
print OUTPUT <<HTML;
<span class="small">
Stats generated by <a href="http://pisg.sourceforge.net/" title="Go to the pisg homepage">pisg</a> $conf->{version}<br>
pisg by <a href="http://www.wtf.dk/hp/" title="Go to the authors homepage">Morten "LostStar" Brix Pedersen</a> and others<br>
Stats generated in $stats->{processtime}
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
    my ($moduledir, $channel, $logfile, $format, $network, $maintainer, $outputfile, $logdir, $prefix, $configfile, $help);

my $usage = <<END_USAGE;
Usage: pisg.pl [-ch channel] [-l logfile] [-o outputfile] [-ma
maintainer]  [-f format] [-n network] [-d logdir] [-mo moduledir] [-h]

-ch --channel=xxx      : Set channel name
-l  --logfile=xxx      : Log file to parse
-o  --outfile=xxx      : Name of html file to create
-ma --maintainer=xxx   : Channel/statistics maintainer
-f  --format=xxx       : Logfile format [see FORMATS file]
-n  --network=xxx      : IRC Network this channel is on.
-d  --dir=xxx          : Analyze all files in this dir. Ignores logfile.
-p  --prefix=xxx       : Analyse only files starting with xxx in dir.
                         Only works with --dir
-mo --moduledir=xxx    : Directory containing pisg's modules.
-co --configfile=xxx   : Config file
-h --help              : Output this message and exit (-? also works).

Example:

 \$ pisg.pl -n IRCnet -f xchat -o suid.html -ch \\#channel -l logfile.log

All options may also be defined by editing the configuration file and
calling pisg without arguments.

END_USAGE
#'
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
                   'moduledir=s'  => \$moduledir,
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

    if ($moduledir) {
        $conf->{modules_dir} = $moduledir;
        $conf->{cmdl}{modules_dir} = 1;
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
