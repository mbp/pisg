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
    my $self = {
        chans => {},
        users => {},
        cfg => {},
        tmps => {},
    };
    my %args = @_;

    $self->{override_cfg} = $args{override_cfg};
    $self->{use_configfile} = $args{use_configfile};

    # FIXME - ugly hack to get the anonymous sub working, looks stupid to
    # put this in the new constructor:
    $self->{debug} = sub {
        if ($self->{cfg}->{debug} or not $self->{cfg}->{debugstarted}) {
            my $debugline = $_[0] . "\n";
            if ($self->{cfg}->{debugstarted}) {
                print DEBUG $debugline;
            } else {
                $self->{cfg}->{debugqueue} .= $debugline;
            }
        }
    };

    # Load the Common module from wherever it's configured to be.
    #push(@INC, $self->{cfg}->{modules_dir});
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

    print "pisg $self->{cfg}->{version} - Perl IRC Statistics Generator\n\n";

    # Init the configuration file (aliases, ignores, channels, etc)
    $self->init_config()
        if ($self->{use_configfile});

    # Init the debugging file.
    $self->init_debug()
        unless ($self->{cfg}->{debugstarted});

    # Get translations from langfile
    $self->get_language_templates();

    # Parse any channels in <channel> statements
    $self->parse_channels();

    # Optionaly parse the channel we were given in override_cfg.
    $self->do_channel()
        unless ($self->{cfg}->{chan_done}{$self->{cfg}->{channel}});

    # Close the debugging file.
    $self->close_debug();
}

sub get_default_config_settings
{
    my $self = shift;

    # This is all the default settings of pisg. They can be overriden by the
    # pisg.cfg file, or by stating the override_cfg argument to the new
    # constructor.

    $self->{cfg} = {
        channel => "",
        logtype => "Logfile",
        logfile => "",
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
        version => "v0.24-cvs",
    };

    # Parse the optional overriden configuration variables
    foreach my $key (keys %{$self->{override_cfg}}) {
        $self->{cfg}->{$key} = $self->{override_cfg}->{$key};
    }
}


sub get_language_templates
{
    my $self = shift;
    open(FILE, $self->{cfg}->{langfile}) or open (FILE, $FindBin::Bin . "/$self->{cfg}->{langfile}") or die("$0: Unable to open language file($self->{cfg}->{langfile}): $!\n");


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

sub init_debug
{
    my $self = shift;
    $self->{cfg}->{debugstarted} = 1;
    if ($self->{cfg}->{debug}) {
        print "[ Debugging => $self->{cfg}->{debugfile} ]\n";
        open(DEBUG,"> $self->{cfg}->{debugfile}") or print STDERR "$0: Unable to open debug
        file($self->{cfg}->{debugfile}): $!\n";
        $self->{debug}->("*** pisg debug file for $self->{cfg}->{logfile}\n");
        if ($self->{cfg}->{debugqueue}) {
            print DEBUG $self->{cfg}->{debugqueue};
            delete $self->{cfg}->{debugqueue};
        }
    } else {
        $self->{debug} = sub {};
    }
}

sub close_debug
{
    my $self = shift;
    if ($self->{cfg}->{debug}) {
        close(DEBUG) or print STDERR "$0: Cannot close debugfile($self->{cfg}->{debugfile}): $!\n";
    }
}

sub init_words
{
    my $self = shift;
    $self->{cfg}->{foul} =~ s/\s+/|/g;
    foreach (split /\s+/, $self->{cfg}->{ignorewords}) {
        $self->{cfg}->{ignoreword}{$_} = 1;
    }
    $self->{cfg}->{violent} =~ s/\s+/|/g;
}

sub init_config
{
    my $self = shift;


    if ((open(CONFIG, $self->{cfg}->{configfile}) or open(CONFIG, $FindBin::Bin . "/$self->{cfg}->{configfile}"))) {
        print "Using config file: $self->{cfg}->{configfile}\n";

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
                    print STDERR "Warning: no nick specified in $self->{cfg}->{configfile} on line $lineno\n";
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

            } elsif ($line =~ /<set(.*)>/) {

                my $settings = $1;
                while ($settings =~ s/[ \t]([^=]+)=["']([^"']*)["']//) {
                    my $var = lc($1); # Make the string lowercase
                    unless (($self->{cfg}->{$var} eq $2) || $self->{override_cfg}->{$var}) {
                        $self->{cfg}->{$var} = $2;
                    }
                    $self->{debug}->("cfg: $var = $2");
                }

            } elsif ($line =~ /<channel=['"]([^'"]+)['"](.*)>/i) {
                my ($channel, $settings) = ($1, $2);
                $self->{chans}->{$channel}->{channel} = $channel;
                $self->{cfg}->{chan_done}{$self->{cfg}->{channel}} = 1; # don't parse channel in $self->{cfg}->{channel} if a channel statement is present
                while ($settings =~ s/\s([^=]+)=["']([^"']*)["']//) {
                    my $var = lc($1);
                    $self->{chans}->{$channel}{$var} = $2;
                    $self->{debug}->("Channel cfg $channel: $var = $2");
                }
                while (<CONFIG>) {
                    last if ($_ =~ /<\/*channel>/i);
                    while ($_ =~ s/^\s*(\w+)\s*=\s*["']([^"']*)["']//) {
                        my $var = lc($1);
                        unless ($self->{override_cfg}->{$var}) {
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

    print "Using language template: $self->{cfg}->{lang}\n\n" if ($self->{cfg}->{lang} ne 'EN');

    print "Statistics for channel $self->{cfg}->{channel} \@ $self->{cfg}->{network} by $self->{cfg}->{maintainer}\n\n";

}

sub do_channel
{
    my $self = shift;
    if (!$self->{cfg}->{channel}) {
        print "No channels defined.\n";
    } elsif ((!$self->{cfg}->{logfile}) && (!$self->{cfg}->{logdir})) {
        print "No logfile or logdir defined for " . $self->{cfg}->{channel} . "\n";
    } else {

        $self->init_pisg();        # Init some general things
        $self->init_words();       # Init words. (Foulwords, ignorewords, etc.)


        # Pick our stats generator.
        my $analyzer;
        eval <<_END;
use Pisg::Parser::$self->{cfg}->{logtype};
\$analyzer = new Pisg::Parser::$self->{cfg}->{logtype}(\$self->{cfg}, \$self->{debug});
_END
        if ($@) {
            print STDERR "Could not load stats generator for '$self->{cfg}->{logtype}': $@\n";
            return undef;
        }

        my $stats = $analyzer->analyze();

        # Initialize HTMLGenerator object
        my $generator;
        eval <<_END;
use Pisg::HTMLGenerator;
\$generator = new Pisg::HTMLGenerator(
    cfg => \$self->{cfg},
    debug => \$self->{debug},
    stats => \$stats,
    users => \$self->{users},
    tmps => \$self->{tmps}
);
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

=back

=head1 AUTHOR

Morten Brix Pedersen <morten@wtf.dk>

=head1 COPYRIGHT

Copyright (C) 2001 Morten Brix Pedersen. All rights resereved.
This program is free software; you can redistribute it and/or modify it
under the terms of the GPL, license is included with the distribution of
this file.

=cut
