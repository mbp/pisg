package Pisg;

# Copyright (C) 2001  <Morten Brix Pedersen> - morten@wtf.dk
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

=head1 NAME

Pisg - Perl IRC Statistics Generator main module

=cut

use strict;
$^W = 1;

sub new
{
    my $type = shift;
    my $self = {
        chans => {},
        users => {},
        conf => {},
        tmps => {},
        overriden_confs => $_[0],
    };

    # FIXME - ugly hack to get the anonymous sub working, looks stupid to
    # put this in the new constructor
    $self->{debug} = sub {
        if ($self->{conf}->{debug} or not $self->{conf}->{debugstarted}) {
            my $debugline = $_[0] . "\n";
            if ($self->{conf}->{debugstarted}) {
                print DEBUG $debugline;
            } else {
                $self->{conf}->{debugqueue} .= $debugline;
            }
        }
    };

    # Load the Common module from wherever it's configured to be.
    #push(@INC, $self->{conf}->{modules_dir});
    require Pisg::Common;
    Pisg::Common->import();

    bless($self, $type);
    return $self;
}

sub run
{
    my $self = shift;
    $self->get_default_config_settings();
    print "pisg $self->{conf}->{version} - Perl IRC Statistics Generator\n\n";
    $self->init_config();      # Init config. (Aliases, ignores, other options etc.)
    $self->init_debug()
        unless ($self->{conf}->{debugstarted});       # Init the debugging file
    $self->get_language_templates(); # Get translations from lang.txt
    $self->parse_channels();   # parse any channels in <channel> statements
    $self->do_channel()
        unless ($self->{conf}->{chan_done}{$self->{conf}->{channel}});

    $self->close_debug();      # Close the debugging file
}

sub get_default_config_settings
{
    my $self = shift;

    $self->{conf} = {
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
}


sub get_language_templates
{
    my $self = shift;
    open(FILE, $self->{conf}->{langfile}) or open (FILE, $FindBin::Bin . "/$self->{conf}->{langfile}") or die("$0: Unable to open language file($self->{conf}->{langfile}): $!\n");


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
                    $self->{tmps}->{$current_lang}{$1} = $2;
                }
            }

        }

    }

    close(FILE);
}


sub get_subst
{
    my $self = shift;
    my ($m,$f,$hash) = @_;
    if ($hash->{nick} && $self->{users}->{sex}{$hash->{nick}}) {
        if ($self->{users}->{sex}{$hash->{nick}} eq 'm') {
            return $m;
        } elsif ($self->{users}->{sex}{$hash->{nick}} eq 'f') {
            return $f;
        }
    }
    return "$m/$f";
}

sub init_debug
{
    my $self = shift;
    $self->{conf}->{debugstarted} = 1;
    if ($self->{conf}->{debug}) {
        print "[ Debugging => $self->{conf}->{debugfile} ]\n";
        open(DEBUG,"> $self->{conf}->{debugfile}") or print STDERR "$0: Unable to open debug
        file($self->{conf}->{debugfile}): $!\n";
        $self->{debug}->("*** pisg debug file for $self->{conf}->{logfile}\n");
        if ($self->{conf}->{debugqueue}) {
            print DEBUG $self->{conf}->{debugqueue};
            delete $self->{conf}->{debugqueue};
        }
    } else {
        $self->{debug} = sub {};
    }
}

sub close_debug
{
    my $self = shift;
    if ($self->{conf}->{debug}) {
        close(DEBUG) or print STDERR "$0: Cannot close debugfile($self->{conf}->{debugfile}): $!\n";
    }
}

sub init_words
{
    my $self = shift;
    $self->{conf}->{foul} =~ s/\s+/|/g;
    foreach (split /\s+/, $self->{conf}->{ignorewords}) {
        $self->{conf}->{ignoreword}{$_} = 1;
    }
    $self->{conf}->{violent} =~ s/\s+/|/g;
}

sub init_config
{
    my $self = shift;

    # Parse the optional overriden configuration variables
    foreach my $key (keys %{$self->{overriden_confs}}) {
        $self->{conf}->{$key} = $self->{overriden_confs}->{$key};
    }

    if ((open(CONFIG, $self->{conf}->{configfile}) or open(CONFIG, $FindBin::Bin . "/$self->{conf}->{configfile}"))) {
        print "Using config file: $self->{conf}->{configfile}\n";

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
                    print STDERR "Warning: no nick specified in $self->{conf}->{configfile} on line $lineno\n";
                    next;
                }

                if ($line =~ /alias="([^"]+)"/) {
                    my @thisalias = split(/\s+/, lc($1));
                    foreach (@thisalias) {
                        if ($self->{conf}->{regexp_aliases} and /[\|\[\]\{\}\(\)\?\+\.\*\^\\]/) {
                            add_aliaswild($nick, $_);
                        } elsif (not $self->{conf}->{regexp_aliases} and s/\*/\.\*/g) {
                            # quote it if it is a wildcard
                            s/([\|\[\]\{\}\(\)\?\+\^\\])/\\$1/g;
                            add_aliaswild($nick, $_);
                        } else {
                            add_alias($nick, $_);
                        }
                    }
                }

                if ($line =~ /pic="([^"]+)"/) {
                    $self->{users}->{userpics}{$nick} = $1;
                }

                if ($line =~ /link="([^"]+)"/) {
                    $self->{users}->{userlinks}{$nick} = $1;
                }

                if ($line =~ /ignore="Y"/i) {
                    add_ignore($nick);
                }

                if ($line =~ /sex="([MmFf])"/i) {
                    $self->{users}->{sex}{$nick} = lc($1);
                }

            } elsif ($line =~ /<set(.*)>/) {

                my $settings = $1;
                while ($settings =~ s/[ \t]([^=]+)=["']([^"']*)["']//) {
                    my $var = lc($1); # Make the string lowercase
                    unless (($self->{conf}->{$var} eq $2) || $self->{overriden_confs}->{$var}) {
                        $self->{conf}->{$var} = $2;
                    }
                    $self->{debug}->("Conf: $var = $2");
                }

            } elsif ($line =~ /<channel=['"]([^'"]+)['"](.*)>/i) {
                my ($channel, $settings) = ($1, $2);
                $self->{chans}->{$channel}->{channel} = $channel;
                $self->{conf}->{chan_done}{$self->{conf}->{channel}} = 1; # don't parse channel in $self->{conf}->{channel} if a channel statement is present
                while ($settings =~ s/\s([^=]+)=["']([^"']*)["']//) {
                    my $var = lc($1);
                    $self->{chans}->{$channel}{$var} = $2;
                    $self->{debug}->("Channel conf $channel: $var = $2");
                }
                while (<CONFIG>) {
                    last if ($_ =~ /<\/*channel>/i);
                    while ($_ =~ s/^\s*(\w+)\s*=\s*["']([^"']*)["']//) {
                        my $var = lc($1);
                        unless ($self->{overriden_confs}->{$var}) {
                            $self->{chans}->{$channel}{$var} = $2;
                        }
                        $self->{debug}->("Conf $channel: $var = $2");
                    }
                }
            }
        }

        close(CONFIG);
    }

}

sub init_pisg
{
    my $self = shift;

    my $timestamp = time();
    $self->{conf}->{start} = time();

    if ($self->{conf}->{timeoffset} =~ /\+(\d+)/) {
        # We must plus some hours to the time
        $timestamp += 3600 * $1; # 3600 seconds per hour

    } elsif ($self->{conf}->{timeoffset} =~ /-(\d+)/) {
        # We must remove some hours from the time
        $timestamp -= 3600 * $1; # 3600 seconds per hour
    }
    $self->{conf}->{timestamp} = $timestamp;

    # Add trailing slash when it's not there..
    $self->{conf}->{imagepath} =~ s/([^\/])$/$1\//;

    print "Using language template: $self->{conf}->{lang}\n\n" if ($self->{conf}->{lang} ne 'EN');

    print "Statistics for channel $self->{conf}->{channel} \@ $self->{conf}->{network} by $self->{conf}->{maintainer}\n\n";

}

sub do_channel
{
    my $self = shift;
    $self->init_pisg();        # Init commandline arguments and other things
    $self->init_words();       # Init words. (Foulwords etc)

    # Pick our stats generator.
    my $analyzer;
    eval <<_END;
use Pisg::Parser::$self->{conf}->{logtype};
\$analyzer = new Pisg::Parser::$self->{conf}->{logtype}(\$self->{conf}, \$self->{debug});
_END
    if ($@) {
        print STDERR "Could not load stats generator for '$self->{conf}->{logtype}': $@\n";
        return undef;
    }

    my $stats = $analyzer->analyze();

    my $generator;
    eval <<_END;
use Pisg::HTMLGenerator;
\$generator = new Pisg::HTMLGenerator(\$self->{conf}, \$self->{debug}, \$stats, \$self->{users}, \$self->{tmps});
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

    $self->{conf}->{chan_done}{$self->{conf}->{channel}} = 1;
}

sub parse_channels
{
    my $self = shift;
    my %origconf = %{ $self->{conf} };

    foreach my $channel (keys %{ $self->{chans} }) {
        foreach (keys %{ $self->{chans}->{$channel} }) {
            $self->{conf}->{$_} = $self->{chans}->{$channel}{$_};
        }
        $self->do_channel();
        $origconf{chan_done} = $self->{conf}->{chan_done};
        %{ $self->{conf} } = %origconf;
    }
}

1;
