package Pisg;

# Documentation(POD) for this module is found at the end of the file.

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
        tmps => {},
    };

    # Import common functions in Pisg::Common
    require Pisg::Common;
    Pisg::Common->import();

    bless($self, $type);
    return $self;
}

sub run
{
    my $self = shift;

    # Set the default configuration settings.
    $self->get_default_config_settings();

    print "pisg $self->{cfg}->{version} - Perl IRC Statistics Generator\n\n"
        unless ($self->{cfg}->{silent});

    # Init the configuration file (aliases, ignores, channels, etc)
    my $r = $self->init_config()
        if ($self->{use_configfile});

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
        default_pic => '',
        logdir => '',
        lang => 'EN',
        langfile => 'lang.txt',
        prefix => '',
        silent => 0,
        userpics => 'y',

        # Colors / Layout

        bgcolor => '#dedeee',
        bgpic => '',
        text => 'black',
        hbgcolor => '#666699',
        hcolor => 'white',
        hicell => '#BABADD',
        hicell2 => '#CCCCCC',
        tdcolor => 'black',
        tdtop => '#C8C8DD',
        link => '#0b407a',
        vlink => '#0b407a',
        hlink => '#0b407a',
        bg_link => '#0b407a',
        bg_vlink => '#0b407a',
        bg_hlink => '#0b407a',
        headline => '#000000',
        rankc => '#CCCCCC',
        hi_rankc => '#AAAAAA',

        pic_width => '',
        pic_height => '',

        pic_v_0 => 'blue-v.png',
        pic_v_6 => 'green-v.png',
        pic_v_12 => 'yellow-v.png',
        pic_v_18 => 'red-v.png',
        pic_h_0 => 'blue-h.png',
        pic_h_6 => 'green-h.png',
        pic_h_12 => 'yellow-h.png',
        pic_h_18 => 'red-h.png',
        pic_loc => '.',

        # Stats settings

        show_activetimes => 1,
        show_bignumbers => 1,
        show_topics => 1,
        show_linetime => 0,
        show_time => 1,
        show_words => 0,
        show_wpl => 0,
        show_cpl => 0,
        show_lastseen => 0,
        show_legend => 1,
        show_kickline => 1,
        show_actionline => 1,
        show_shoutline => 1,
        show_violentlines => 1,
        show_randquote => 1,
        show_muw => 1,
        show_mrn => 1,
        show_mru => 1,
        show_voices => 0,

        # Less important things

        timeoffset => '+0',
        use_activetime_alt => 0,
        minquote => 25,
        maxquote => 65,
        wordlength => 5,
        activenicks => 25,
        activenicks2 => 30,
        topichistory => 3,
        urlhistory => 5,
        wordhistory => 10,
        nicktracking => 0,
        charset => 'iso-8859-1',

        # Misc settings

        foul => 'ass fuck bitch shit scheisse scheiße kacke arsch ficker ficken schlampe',
        violent => 'slaps beats smacks',
        ignorewords => '',
        tablewidth => 614,
        regexp_aliases => 0,

        # Developer stuff

        version => "v0.34-cvs",
    };

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

sub init_words
{
    my $self = shift;
    $self->{cfg}->{foul} =~ s/(^\s+|\s+$)//g;
    $self->{cfg}->{foul} =~ s/\s+/|/g;
    foreach (split /\s+/, $self->{cfg}->{ignorewords}) {
        $self->{cfg}->{ignoreword}{$_} = 1;
    }
    $self->{cfg}->{violent} =~ s/(^\s+|\s+$)//g;
    $self->{cfg}->{violent} =~ s/\s+/|/g;
}

sub init_config
{
    my $self = shift;

    if ((open(CONFIG, $self->{cfg}->{configfile}) or open(CONFIG, $self->{search_path} . "/$self->{cfg}->{configfile}"))) {

        while (my $line = <CONFIG>)
        {
            next if ($line =~ /^#/);
            chomp $line;

            if ($line =~ /<user.*>/) {
                my $nick;

                if ($line =~ /nick="([^"]+)"/) {
                    $nick = $1;
                    add_alias($nick, $nick);
                } else {
                    print STDERR "Warning: $self->{cfg}->{configfile}, line $.: No nick specified\n";
                    next;
                }

                if ($line =~ /alias="([^"]+)"/) {
                    my @thisalias = split(/\s+/, lc($1));
                    foreach (@thisalias) {
                        if ($self->{cfg}->{regexp_aliases} and /[\|\[\]\{\}\(\)\?\+\.\*\^\\]/) {
                            add_aliaswild($nick, $_);
                        } elsif (not $self->{cfg}->{regexp_aliases} and s/\*/\.\*/g) {
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
            } elsif ($line =~ /<link(.*)>/) {
                my $url;

                if ($line =~ /url="([^"]+)"/) {
                    $url = $1;
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

                while ($settings =~ s/[ \t]([^=]+)=["']([^"']*)["']//) {
                    my $var = lc($1);
                    $var =~ s/ //; # Remove whitespace
                    if (!defined($self->{cfg}->{$var})) {
                        print STDERR "Warning: $self->{cfg}->{configfile}, line $.: No such configuration option: '$var'\n";
                        next;
                    }
                    unless (($self->{cfg}->{$var} eq $2) || $self->{override_cfg}->{$var}) {
                        $self->{cfg}->{$var} = $2;
                    }
                }

            } elsif ($line =~ /<channel=['"]([^'"]+)['"](.*)>/i) {
                my ($channel, $settings) = ($1, $2);
                $self->{chans}->{$channel}->{channel} = $channel;
                $self->{cfg}->{chan_done}{$self->{cfg}->{channel}} = 1; # don't parse channel in $self->{cfg}->{channel} if a channel statement is present
                while ($settings =~ s/\s([^=]+)=["']([^"']*)["']//) {
                    my $var = lc($1);
                    $self->{chans}->{$channel}{$var} = $2;
                }
                while (<CONFIG>) {
                    last if ($_ =~ /<\/*channel>/i);
                    if ($_ =~ /^\s*(\w+)\s*=\s*["']([^"']*)["']/) {
                        my $var = lc($1);
                        unless ($self->{override_cfg}->{$var}) {
                            $self->{chans}->{$channel}{$var} = $2;
                        }
                    } else {
                        print STDERR "Warning: $self->{cfg}->{configfile}, line $.: Unrecognized line\n";
                    }
                }
            } elsif ($line =~ /<(\w+)?.*[^>]$/) {
                print STDERR "Warning: $self->{cfg}->{configfile}, line $.: Missing end on element <$1 (probably multi-line?)\n";
            } elsif ($line =~ /\S/) {
                $line =~ s/\n//;
                print "Warning: $self->{cfg}->{configfile}, line $.: Unrecognized line\n";
            }
        }

        close(CONFIG);
    }
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
        if (defined $stats and $stats->{totallines} > 0) {
            $generator->create_html();
        } elsif ($stats->{totallines} == 0) {
            print STDERR "No lines found in logfile.. skipping.\n";
        }

        $self->{cfg}->{chan_done}{$self->{cfg}->{channel}} = 1;
    }
}

sub parse_channels
{
    my $self = shift;
    my %origcfg = %{ $self->{cfg} };

    foreach my $channel (keys %{ $self->{chans} }) {
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
