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

my ($totallength, $oldtime, $actions, $normals, %T);

sub load_modules
{
    push(@INC, $conf->{modules_dir});
    require Pisg::Common;
    Pisg::Common->import();
    Pisg::Common::init_common($debug);
}

sub main
{
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

    my $generator;
    eval <<_END;
use Pisg::HTMLGenerator;
\$generator = new Pisg::HTMLGenerator(\$conf, \$debug, \$stats, \$users, \\%T);
_END

    if ($@) {
        print STDERR "Could not load stats html generator (Pisg::HTMLGenerator): $@\n";
        return undef;
    }

    # Create our HTML page if the logfile has any data.
    if (defined $stats and $stats->{totallines} > 0) {
        $generator->create_html();
    } elsif ($stats->{totallines} == 0) {
        print STDERR "No lines found in logfile.. skipping.\n";
    }
    
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

    my $timestamp = time();
    $conf->{start} = time();

    if ($conf->{timeoffset} =~ /\+(\d+)/) {
        # We must plus some hours to the time
        $timestamp += 3600 * $1; # 3600 seconds per hour

    } elsif ($conf->{timeoffset} =~ /-(\d+)/) {
        # We must remove some hours from the time
        $timestamp -= 3600 * $1; # 3600 seconds per hour
    }
    $conf->{timestamp} = $timestamp;

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

sub init_words
{
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


sub get_subst
{
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
