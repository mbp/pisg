#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use FindBin;

# pisg - Perl IRC Statistics Generator
#
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

sub main
{
    my $cfg = get_cmdline_options();
    push(@INC, $cfg->{modules_dir});

    my $pisg;
    eval <<END;

use Pisg;

\$pisg = new Pisg(
    use_configfile => '0',
    override_cfg => \$cfg
);
\$pisg->run();
END
    if ($@) {
        print $@;
    }
    if ($@) {
        print STDERR "Could not load pisg! Reason:\n$@\n";
        return undef;
    }
}

sub get_cmdline_options
{
    my $cfg = {
        modules_dir => $FindBin::Bin . "/modules",     # Module search path
    };

    my $tmp;
    # Commandline options
    my ($moduledir, $channel, $logfile, $format, $network, $maintainer, $outputfile, $logdir, $prefix, $configfile, $help);

my $usage = <<END_USAGE;
Usage: pisg.pl [-ch channel] [-l logfile] [-o outputfile] [-ma maintainer]
[-f format] [-n network] [-d logdir] [-mo moduledir] [-h]

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

    if ($channel) { $cfg->{channel} = $channel; }

    if ($logfile) { $cfg->{logfile} = $logfile; }

    if ($format) { $cfg->{format} = $format; }

    if ($network) { $cfg->{network} = $network; }

    if ($maintainer) { $cfg->{maintainer} = $maintainer; }

    if ($outputfile) { $cfg->{outputfile} = $outputfile; }

    if ($logdir) { $cfg->{logdir} = $logdir; }

    if ($prefix) { $cfg->{prefix} = $prefix; }

    if ($moduledir) { $cfg->{modules_dir} = $moduledir; }

    if ($configfile) { $cfg->{configfile} = $configfile; }

    return $cfg;

}

main();        # Run the script
