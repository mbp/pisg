package Pisg;

# Documentation(POD) for this module is found at the end of the file.

# Copyright (C) 2001-2002  <Morten Brix Pedersen> - morten@wtf.dk
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

use strict;
$^W = 1;

sub new
{
    my $type = shift;
    my %args = @_;
    my $self = {
        override_cfg => $args{override_cfg},
        use_configfile => $args{use_configfile},
        search_path => $args{search_path},
        chans => {},
        users => {},
        cfg => {},
        bwd => {},
        tmps => {},
    };

    # Set the default configuration settings.
    get_default_config_settings($self);

    # Import common functions in Pisg::Common
    require Pisg::Common;
    Pisg::Common->import();

    bless($self, $type);
    return $self;
}

sub run
{
    my $self = shift;

    print "pisg v$self->{cfg}->{version} - Perl IRC Statistics Generator\n\n"
        unless ($self->{cfg}->{silent});

    # Init the configuration file (aliases, ignores, channels, etc)
    my $r;
    if ($self->{use_configfile}) {
        if ((open(CONFIG, $self->{cfg}->{configfile}) 
            or open(CONFIG, $self->{search_path} . "/$self->{cfg}->{configfile}"))) {
            $r = $self->init_config(\*CONFIG)
        }
    }

    print "Using config file: $self->{cfg}->{configfile}\n\n"
        if ($r && !$self->{cfg}->{silent});

    $self->init_words()       # Init words. (Foulwords, ignorewords, etc.)
        if ($self->{use_configfile});

    # Get translations from langfile
    $self->get_language_templates();

    # Parse any channels in <channel> statements
    $self->parse_channels();

    # Optionaly parse the channel we were given in override_cfg.
    $self->do_channel()
        if (!$self->{cfg}->{chan_done}{$self->{cfg}->{channel}});

}

sub get_default_config_settings
{
    my $self = shift;

    # This is all the default settings of pisg. They can be overriden by the
    # pisg.cfg file, or by using the override_cfg argument to the new
    # constructor.

    $self->{cfg} = {
        channel => '',
        logtype => 'Logfile',
        logfile => '',
        format => 'mIRC',
        network => 'SomeIRCNet',
        outputfile => 'index.html',
        maintainer => 'MAINTAINER',
        pagehead => 'none',
        pagefoot => 'none',
        configfile => 'pisg.cfg',
        imagepath => '',
        defaultpic => '',
        logdir => '',
        lang => 'en',
        langfile => 'lang.txt',
        cssdir => 'layout/',
        colorscheme => 'default',
        logprefix => '',
        logsuffix => '',
        silent => 0,
        userpics => 'y',

        # Colors / Layout

        hicell => '#BABADD', # FIXME 
        hicell2 => '#CCCCCC', # FIXME

        picwidth => '',
        picheight => '',

        pic_v_0 => 'blue-v.png',
        pic_v_6 => 'green-v.png',
        pic_v_12 => 'yellow-v.png',
        pic_v_18 => 'red-v.png',
        pic_h_0 => 'blue-h.png',
        pic_h_6 => 'green-h.png',
        pic_h_12 => 'yellow-h.png',
        pic_h_18 => 'red-h.png',
        piclocation => '.',

        # Stats settings

        showactivetimes => 1,
        showbignumbers => 1,
        showtopics => 1,
        showlinetime => 0,
        showwordtime => 0,
        showtime => 1,
        showwords => 0,
        showwpl => 0,
        showcpl => 0,
        showlastseen => 0,
        showlegend => 1,
        showkickline => 1,
        showactionline => 1,
        showfoulline => 0,
        showshoutline => 1,
        showviolentlines => 1,
        showrandquote => 1,
        showmuw => 1,
        showmrn => 1,
        showmru => 1,
        showops => 1,
        showvoices => 0,
        showhalfops => 0,
        showmostnicks => 0,
        showmostactivebyhour => 0,
        showmostactivebyhourgraph => 0,
        showonlytop => 0,

        # Less important things

        timeoffset => '+0',
        minquote => 25,
        maxquote => 65,
        quotewidth => 80,
        wordlength => 5,
        activenicks => 25,
        activenicks2 => 30,
        activenicksbyhour => 10,
        topichistory => 3,
        urlhistory => 5,
        nickhistory => 5,
        wordhistory => 10,
        mostnickshistory => 5,
        nicktracking => 0,
        charset => 'iso-8859-1',
        irciinick => 'maintainer',

        # sorting
        sortbywords => 0,

        # Misc settings

        foulwords => 'ass fuck bitch shit scheisse scheiße kacke arsch ficker ficken schlampe',
        violentwords => 'slaps beats smacks',
        ignorewords => '',
        noignoredquotes => 0,
        tablewidth => 614,
        regexpaliases => 0,

        botnicks => '',            # Needed for DCpp format (non-irc)

        version => "0.46",
    };

    # Backwards compatibility with old option names:
    $self->{bwd} = {
        default_pic => 'DefaultPic',
        prefix => 'LogPrefix',
        show_activetimes => 'ShowActiveTimes',
        show_bignumbers => 'ShowBigNumbers',
        show_topics => 'ShowTopics',
        show_linetime => 'ShowLineTime',
        show_time => 'ShowTime',
        show_words => 'ShowWords',
        show_wpl => 'ShowWpl',
        show_cpl => 'ShowCpl',
        show_lastseen => 'ShowLastSeen',
        show_legend => 'ShowLegend',
        show_kickline => 'ShowKickLine',
        show_actionline => 'ShowActionLine',
        show_shoutline => 'ShowShoutLine',
        show_violentlines => 'ShowViolentLines',
        show_randquote => 'ShowRandQuote',
        show_muw => 'ShowMuw',
        show_mrn => 'ShowMrn',
        show_mru => 'ShowMru',
        show_voices => 'ShowVoices',
        show_mostnicks => 'ShowMostNicks',
        foul => 'FoulWords',
        violent => 'ViolentWords',
        regexp_aliases => 'RegexpAliases',
        pic_loc => 'PicLocation',
        pic_width => 'PicWidth',
        pic_height => 'PicHeight'
    };

    # This enables us to use the search_path in other modules
    $self->{cfg}->{search_path} = $self->{search_path};

    # Parse the optional overriden configuration variables
    foreach my $key (keys %{$self->{override_cfg}}) {
        if ($self->{override_cfg}->{$key}) {
            $self->{cfg}->{$key} = $self->{override_cfg}->{$key};
        }
    }
}

sub get_language_templates
{
    my $self = shift;

    open(FILE, $self->{cfg}->{langfile}) or open (FILE, $self->{search_path} . "/$self->{cfg}->{langfile}") or die("$0: Unable to open language file($self->{cfg}->{langfile}): $!\n");

    while (my $line = <FILE>)
    {
        next if ($line =~ /^#/);

        if ($line =~ /<lang name=\"([^"]+)\">/i) {
            # Found start tag, setting the current language
            my $current_lang = lc($1);

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

sub init_words
{
    my $self = shift;
    $self->{cfg}->{foulwords} =~ s/(^\s+|\s+$)//g;
    my @foulwords = split(/\s+/, $self->{cfg}->{foulwords});
    $self->{cfg}->{foulwords} = '\b' . join('|\b', @foulwords) . '|' . join('\b|', @foulwords) . '\b';
    $self->{cfg}->{ignorewords} =~ s/(^\s+|\s+$)//g;
    foreach (split(/\s+/, $self->{cfg}->{ignorewords})) {
        $self->{cfg}->{ignoreword}{$_} = 1;
    }
    if ($self->{cfg}->{noignoredquotes}) {
        my $igntmp = $self->{cfg}->{ignorewords};
        $igntmp =~ s/(\[|\]|\(|\)|\/|\\)/\\$1/g;
        my @ignorewords = split(/\s+/, $igntmp);
        $self->{cfg}->{ignorewordsregex} = '\b' . join('|\b', @ignorewords) . '|' . join('\b|', @ignorewords) . '\b';
    }
    $self->{cfg}->{violentwords} =~ s/(^\s+|\s+$)//g;
    $self->{cfg}->{violentwords} =~ s/\s+/|/g;
}

sub init_config
{
    my $self = shift;
    my $fh   = shift;
    while (my $line = <$fh>)
    {
        next if ($line =~ /^#/);
        chomp $line;

        if ($line =~ /<user.*>/) {
            my $nick;

            if ($line =~ /nick=(["'])(.+?)\1/) {
                $nick = $2;
                add_alias($nick, $nick);
            } else {
                print STDERR "Warning: $self->{cfg}->{configfile}, line $.: No nick specified\n";
                next;
            }

            if ($line =~ /alias=(["'])(.+?)\1/) {
                my @thisalias = split(/\s+/, lc($2));
                foreach (@thisalias) {
                    if ($self->{cfg}->{regexpaliases} and /[\|\[\]\{\}\(\)\?\+\.\*\^\\]/) {
                        add_aliaswild($nick, $_);
                    } elsif (not $self->{cfg}->{regexpaliases} and s/\*/\.\*/g) {
                        # quote it if it is a wildcard
                        s/([\|\[\]\{\}\(\)\?\+\^\\])/\\$1/g;
                        add_aliaswild($nick, $_);
                    } else {
                        add_alias($nick, $_);
                    }
                }
            }

            if ($line =~ /pic=(["'])(.+?)\1/) {
                $self->{users}->{userpics}{$nick} = $2;
            }

            if ($line =~ /bigpic=(["'])(.+?)\1/) {
                $self->{users}->{biguserpics}{$nick} = $2;
            }

            if ($line =~ /link=(["'])(.+?)\1/) {
                $self->{users}->{userlinks}{$nick} = $2;
            }

            if ($line =~ /ignore=(["'])Y\1/i) {
                add_ignore($nick);
            }

            if ($line =~ /sex=(["'])([MmFf])\1/) {
                $self->{users}->{sex}{$nick} = lc($2);
            }
        } elsif ($line =~ /<link(.*)>/) {

            if ($line =~ /url=(["'])(.+?)\1/) {
                my $url = $2;
                if ($line =~ /ignore="Y"/i) {
                    add_url_ignore($url);
                }
            } else {
                print STDERR "Warning: $self->{cfg}->{configfile}, line $.: No URL specified\n";
            }


        } elsif ($line =~ /<set(.*)>/) {

            my $settings = $1;
            if ($settings !~ /=["'](.*)["']/ || $settings =~ /(\w)>/ ) {
                print STDERR "Warning: $self->{cfg}->{configfile}, line $.: Missing or wrong quotes near $1\n";
            }

            while ($settings =~ s/[ \t]([^=]+?)=(["'])(.*?)\2//) {
                my $var = lc($1);
                $var =~ s/ //; # Remove whitespace
                if (!defined($self->{cfg}->{$var})) {
                    if (defined($self->{bwd}->{$var})) {
                        print "Using backwards compatibility option '$var'; you should change it to '$self->{bwd}->{$var}'\n";
                        unless (($self->{cfg}->{lc($self->{bwd}->{$var})} eq $3) || $self->{override_cfg}->{lc($self->{bwd}->{$var})}) {
                            $self->{cfg}->{$self->{bwd}->{$var}} = $3;
                        }
                        next;
                    } else {
                        print STDERR "Warning: $self->{cfg}->{configfile}, line $.: No such configuration option: '$var'\n";
                        next;
                    }
                }
                unless (($self->{cfg}->{$var} eq $3) || $self->{override_cfg}->{$var}) {
                    $self->{cfg}->{$var} = $3;
                }
            }

        } elsif ($line =~ /<channel=(['"])(.+?)\1(.*)>/i) {
            my ($channel, $settings) = ($2, $3);
            $self->{chans}->{$channel}->{channel} = $channel;
            $self->{cfg}->{chan_done}{$self->{cfg}->{channel}} = 1; # don't parse channel in $self->{cfg}->{channel} if a channel statement is present
            while ($settings =~ s/\s([^=]+)=(["'])(.+?)\2//) {
                my $var = lc($1);
                if (defined($self->{bwd}->{$var})) {
                    print "Using backwards compatibility option '$var'; you should change it to '$self->{bwd}->{$var}'\n";
                    $self->{chans}->{$channel}{lc($self->{bwd}->{$var})} = $3;
                } else {
                    $self->{chans}->{$channel}{$var} = $3;
                }
            }
            while (<$fh>) {
                last if ($_ =~ /<\/*channel>/i);
                if ($_ =~ /^\s*(\w+)\s*=\s*(["'])(.+?)\2/) {
                    my $var = lc($1);
                    unless ($self->{override_cfg}->{$var}) {
                        if (defined($self->{bwd}->{$var})) {
                            print "Using backwards compatibility option '$var'; you should change it to '$self->{bwd}->{$var}'\n";
                            $self->{chans}->{$channel}{lc($self->{bwd}->{$var})} = $3;
                        } else {
                            $self->{chans}->{$channel}{$var} = $3;
                        }
                    }
                } elsif ($_ !~ /^$/) {
                    print STDERR "Warning: $self->{cfg}->{configfile}, line $.: Unrecognized line\n";
                }
            }
        } elsif ($line =~ /<include\s*=\s*(["'])(.+?)\1\s*>/) {
            my $include_cfg = $2;
            my $backup_cfg = $self->{cfg}->{configfile};
            $self->{cfg}->{configfile} = $include_cfg;
            my $r;
            if ((open(INCLUDE, $self->{cfg}->{configfile}) 
                or open(INCLUDE, $self->{search_path} . "/$self->{cfg}->{configfile}"))) {
                $r = $self->init_config(\*INCLUDE);
            }
            print "Included config file: $self->{cfg}->{configfile}\n\n"
                if ($r && !$self->{cfg}->{silent});
            $self->{cfg}->{configfile} = $backup_cfg;
        } elsif ($line =~ /<(\w+)?.*[^>]$/) {
            print STDERR "Warning: $self->{cfg}->{configfile}, line $.: Missing end on element <$1 (probably multi-line?)\n";
        } elsif ($line =~ /\S/) {
            $line =~ s/\n//;
            print "Warning: $self->{cfg}->{configfile}, line $.: Unrecognized line\n";
        }
    }

    close($fh);
}

sub init_pisg
{
    my $self = shift;

    my $timestamp = time();
    $self->{cfg}->{start} = time();

    if ($self->{cfg}->{timeoffset} =~ /\+(\d+)/) {
        # We must plus some hours to the time
        $timestamp += 3600 * $1; # 3600 seconds per hour

    } elsif ($self->{cfg}->{timeoffset} =~ /-(\d+)/) {
        # We must remove some hours from the time
        $timestamp -= 3600 * $1; # 3600 seconds per hour
    }
    $self->{cfg}->{timestamp} = $timestamp;

    # Add trailing slash when it's not there..
    $self->{cfg}->{imagepath} =~ s/([^\/])$/$1\//;

    print "Using language template: $self->{cfg}->{lang}\n\n" if ($self->{cfg}->{lang} ne 'EN' && !$self->{cfg}->{silent});

    print "Statistics for channel $self->{cfg}->{channel} \@ $self->{cfg}->{network} by $self->{cfg}->{maintainer}\n\n"
        unless ($self->{cfg}->{silent});
}

sub do_channel
{
    my $self = shift;
    if (!$self->{cfg}->{channel}) {
        print STDERR "No channels defined.\n";
    } elsif ((!$self->{cfg}->{logfile}) && (!$self->{cfg}->{logdir})) {
        print STDERR "No logfile or logdir defined for " . $self->{cfg}->{channel} . "\n";
    } else {
        $self->init_pisg();        # Init some general things

        store_aliases();           # Save the aliases so we can restore them
                                   # later, we don't want to add the aliases
                                   # for this channel to the next channel

        # Pick our stats generator.
        my $analyzer;
        eval <<_END;
use Pisg::Parser::$self->{cfg}->{logtype};
\$analyzer = new Pisg::Parser::$self->{cfg}->{logtype}(
    cfg => \$self->{cfg}
);
_END
        if ($@) {
            print STDERR "Could not load stats analyzer for '$self->{cfg}->{logtype}': $@\n";
            return undef;
        }

        my $stats = $analyzer->analyze();
        $self->{cfg}->{analyzer} = $analyzer;

        # Initialize HTMLGenerator object
        my $generator;
        eval <<_END;
use Pisg::HTMLGenerator;
\$generator = new Pisg::HTMLGenerator(
    cfg => \$self->{cfg},
    stats => \$stats,
    users => \$self->{users},
    tmps => \$self->{tmps}
);
_END

        if ($@) {
            print STDERR "Could not load stats generator (Pisg::HTMLGenerator): $@\n";
            return undef;
        }

        # Create our HTML page if the logfile has any data.
        if (defined $stats and $stats->{parsedlines} > 0) {
            $generator->create_html();
        } elsif ($stats->{parsedlines} == 0) {
            print STDERR "No parseable lines found in logfile ($stats->{totallines} total lines). Skipping.\nYou might be using the wrong format.\n";
        }

        restore_aliases();

        $self->{cfg}->{chan_done}{$self->{cfg}->{channel}} = 1;
    }
}

sub parse_channels
{
    my $self = shift;
    my %origcfg = %{ $self->{cfg} };
    
    # make a list of channels to do
    my @chanlist;
    if (scalar @ {$self->{cfg}->{cchannels} } > 0) {
        @chanlist = @{ $self->{cfg}->{cchannels} };
    } else {
        @chanlist = keys %{ $self->{chans} };
    }

    foreach my $channel (@chanlist) {
        if (!defined $self->{chans}->{$channel}) {
            print STDERR "Channel $channel not in config file, ignoring\n";
            next;
        }
        foreach (keys %{ $self->{chans}->{$channel} }) {
            $self->{cfg}->{$_} = $self->{chans}->{$channel}{$_};
        }
        $self->do_channel();
        $origcfg{chan_done} = $self->{cfg}->{chan_done};
        %{ $self->{cfg} } = %origcfg;
    }
}

1;

__END__

=head1 NAME

Pisg - Perl IRC Statistics Generator main module

=head1 SYNOPSIS

    use Pisg;

    $pisg = new Pisg(
        use_configfile => '1',
        override_cfg => { network => 'MyNetwork', format => 'eggdrop' }
    );

    $pisg->run();

=head1 DESCRIPTION

C<Pisg> is a statistic generator for IRC logfiles or the like, delivering
the results in a HTML page.

=head1 CONSTRUCTOR

=over 4

=item new ( [ OPTIONS ] )

This is the constructor for a new Pisg object. C<OPTIONS> are passed in a hash like fashion, using key and value pairs.

Possible options are:

B<use_configfile> - When set to 1, pisg will look up it's channels in it's
configuration file, defined by the configuration option 'configfile'.

B<override_cfg> - This defines whichever configuration variables you want to
override from the configuration file. If you set use_configfile to 0, then
you'll have to set at least channel and logfile here.

B<search_path> - This defines an optional search path. It's used when you want to hardcode an alternative path where pisg should look after its language and config file.

=back

=head1 AUTHOR

Morten Brix Pedersen <morten@wtf.dk>

=head1 COPYRIGHT

Copyright (C) 2001 Morten Brix Pedersen. All rights resereved.
This program is free software; you can redistribute it and/or modify it
under the terms of the GPL, license is included with the distribution of
this file.

=cut
