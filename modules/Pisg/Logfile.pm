package Pisg::Logfile;

use strict;
$^W = 1;

my ($conf, $debug, $parser);

sub new {
    # The sole argument is the config hash
    my $self = shift;
    $conf = shift;
    $debug = shift;

    # Load the Common module from wherever it's configured to be.
    push @INC, $conf->{modules_dir};
    require Pisg::Common;
    Pisg::Common->import();

    # Pick our parser.
    $parser = choose_log_format($conf->{format});

    return bless {};
}

# The function to choose which module to use.
sub choose_log_format {
    my $format = shift;
    my $parser = undef;
    $debug->("Loading module for log format $format");
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

sub analyze {
    my (%stats, %lines);

    if (defined $parser) {
        my $starttime = time();

        if ($conf->{logdir}) {
            # Run through all files in dir
            parse_dir(\%stats, \%lines);
        } else {
            # Run through the whole logfile
            my %state = (linecount  => 0,
            lastnick   => "",
            monocount  => 0,
            lastnormal => "",
            oldtime    => 24);
            parse_file(\%stats, \%lines, $conf->{logfile}, \%state);
        }

        pick_random_lines(\%stats, \%lines);

        my ($sec,$min,$hour) = gmtime(time() - $starttime);
        $stats{processtime} =
        sprintf("%02d hours, %02d minutes and %02d seconds", $hour, $min,
        $sec);
        print "Channel analyzed succesfully in $stats{processtime} on ",
        scalar localtime(time()), "\n";;

        return \%stats;

    } else {
        print STDERR "Skipping channel '$conf->{channel}' due to lack of parser.\n";
        return undef
    }

    # Shouldn't get here.
    return undef;
}

sub parse_dir {
    my ($stats, $lines) = @_;

    # Add trailing slash when it's not there..
    $conf->{logdir} =~ s/([^\/])$/$1\//;

    print "Going into $conf->{logdir} and parsing all files there...\n\n";
    my @filesarray;
    opendir(LOGDIR, $conf->{logdir}) or
    die("Can't opendir $conf->{logdir}: $!");
    @filesarray = grep {
        /^[^\.]/ && /^$conf->{prefix}/ && -f "$conf->{logdir}/$_"
    } readdir(LOGDIR) or
    die("No files in \"$conf->{logdir}\" matched prefix \"$conf->{prefix}\"");
    closedir(LOGDIR);

    my %state = (lastnick   => "",
    monocount  => 0,
    oldtime    => 24);
    foreach my $file (sort @filesarray) {
        $file = $conf->{logdir} . $file;
        parse_file($stats, $lines, $file, \%state);
    }
}

# This parses the file...
sub parse_file {
    my ($stats, $lines, $file, $state) = @_;

    print "Analyzing log($file) in '$conf->{format}' format...\n";

    if ($file =~ /.bz2?$/ && -f $file) {
        open (LOGFILE, "bunzip2 -c $file |") or
        die("$0: Unable to open logfile($file): $!\n");
    } elsif ($file =~ /.gz$/ && -f $file) {
        open (LOGFILE, "gunzip -c $file |") or
        die("$0: Unable to open logfile($file): $!\n");
    } else {
        open (LOGFILE, $file) or
        die("$0: Unable to open logfile($file): $!\n");
    }

    my $linecount = 0;
    my $lastnormal = "";
    my $repeated;

    while(my $line = <LOGFILE>) {
        $line = strip_mirccodes($line);
        $linecount++;

        my $hashref;

        # Match normal lines.
        if ($hashref = $parser->normalline($line, $linecount)) {

            if (defined $hashref->{repeated}) {
                $repeated = $hashref->{repeated};
            } else {
                $repeated = 0;
            }

            my ($hour, $nick, $saying, $i);

            for ($i = 0; $i <= $repeated; $i++) {

                if ($i > 0) {
                    $hashref = $parser->normalline($lastnormal, $linecount);
                    #Increment number of lines for repeated lines
                    $linecount++;
                }

                $hour   = $hashref->{hour};
                $nick   = find_alias($hashref->{nick});
                $saying = $hashref->{saying};

                if ($hour < $state->{oldtime}) { $stats->{days}++ }
                $state->{oldtime} = $hour;

                unless (is_ignored($nick)) {
                    $stats->{totallines}++;

                    # Timestamp collecting
                    $stats->{times}{$hour}++;

                    $stats->{lines}{$nick}++;
                    $stats->{line_times}{$nick}[int($hour/6)]++;

                    # Count up monologues
                    if ($state->{lastnick} eq $nick) {
                        $state->{monocount}++;

                        if ($state->{monocount} == 5) {
                            $stats->{monologues}{$nick}++;
                        }
                    } else {
                        $state->{monocount} = 0;
                    }
                    $state->{lastnick} = $nick;

                    my $len = length($saying);
                    if ($len > $conf->{minquote} && $len < $conf->{maxquote}) {
                        push @{ $lines->{sayings}{$nick} }, $saying;
                    }
                    $stats->{lengths}{$nick} += $len;

                    $stats->{questions}{$nick}++
                    if ($saying =~ /\?/);

                    $stats->{shouts}{$nick}++
                    if ($saying =~ /!/);

                    if ($saying !~ /[a-z]/ && $saying =~ /[A-Z]/) {
                        $stats->{allcaps}{$nick}++;
                        push @{ $lines->{allcaplines}{$nick} }, $line;
                    }

                    $stats->{foul}{$nick}++
                    if ($saying =~ /$conf->{foul}/i);

                    # Who smiles the most?
                    # A regex matching al lot of smilies
                    $stats->{smiles}{$nick}++
                    if ($saying =~ /[8;:=][ ^-o]?[)pPD}\]>]/);

                    if ($saying =~ /[8;:=][ ^-]?[\(\[\\\/{]/ and
                    $saying !~ /\w+:\/\//) {
                        $stats->{frowns}{$nick}++;
                    }

                    if (my $url = match_url($saying)) {
                        $stats->{urlcounts}{$url}++;
                        $stats->{urlnicks}{$url} = $nick;
                    }

                    parse_words($stats, $saying, $nick);
                }
            }
            $lastnormal = $line;
            $repeated = 0;
        }

        # Match action lines.
        elsif ($hashref = $parser->actionline($line, $linecount)) {
            $stats->{totallines}++;

            my ($hour, $nick, $saying);

            $hour   = $hashref->{hour};
            $nick   = find_alias($hashref->{nick});
            $saying = $hashref->{saying};

            if ($hour < $state->{oldtime}) { $stats->{days}++ }
            $state->{oldtime} = $hour;

            unless (is_ignored($nick)) {
                # Timestamp collecting
                $stats->{times}{$hour}++;

                $stats->{actions}{$nick}++;
                push @{ $lines->{actionlines}{$nick} }, $line;
                $stats->{lines}{$nick}++;
                $stats->{line_times}{$nick}[int($hour/6)]++;

                if ($saying =~ /^($conf->{violent}) (\S+)/) {
                    my $victim = find_alias($2);
                    $stats->{violence}{$nick}++;
                    $stats->{attacked}{$victim}++;
                    push @{ $lines->{violencelines}{$nick} }, $line;
                    push @{ $lines->{attackedlines}{$victim} }, $line;
                }


                my $len = length($saying);
                $stats->{lengths}{$nick} += $len;

                parse_words($stats, $saying, $nick);
            }
        }

        # Match *** lines.
        elsif (($hashref = $parser->thirdline($line, $linecount)) and
        $hashref->{nick}) {
            $stats->{totallines}++;

            my ($hour, $min, $nick, $kicker, $newtopic, $newmode, $newjoin);
            my ($newnick);

            $hour     = $hashref->{hour};
            $min      = $hashref->{min};
            $nick     = find_alias($hashref->{nick});
            $kicker   = find_alias($hashref->{kicker})
            if ($hashref->{kicker});
            $newtopic = $hashref->{newtopic};
            $newmode  = $hashref->{newmode};
            $newjoin  = $hashref->{newjoin};
            $newnick  = $hashref->{newnick};

            if ($hour < $state->{oldtime}) { $stats->{days}++ }
            $state->{oldtime} = $hour;

            unless (is_ignored($nick)) {
                # Timestamp collecting
                $stats->{times}{$hour}++;

                if (defined($kicker)) {
                    $stats->{kicked}{$kicker}++;
                    $stats->{gotkicked}{$nick}++;
                    push @{ $lines->{kicklines}{$nick} }, $line;

                } elsif (defined($newtopic)) {
                    unless ($newtopic eq '') {
                        my $tcount;
                        if (defined $stats->{topics}) {
                            $tcount = @{ $stats->{topics} };
                        } else {
                            $tcount = 0;
                        }
                        $stats->{topics}[$tcount]{topic} = $newtopic;
                        $stats->{topics}[$tcount]{nick}  = $nick;
                        $stats->{topics}[$tcount]{hour}  = $hour;
                        $stats->{topics}[$tcount]{min}   = $min;
                    }

                } elsif (defined($newmode)) {
                    my @opchange = opchanges($newmode);
                    $stats->{gaveops}{$nick} += $opchange[0] if $opchange[0];
                    $stats->{tookops}{$nick} += $opchange[1] if $opchange[1];

                } elsif (defined($newjoin)) {
                    $stats->{joins}{$nick}++;

                } elsif (defined($newnick) and ($conf->{nicktracking} == 1)) {
                    add_alias($nick, $newnick);
                }
            }
        }
    }

    close(LOGFILE);

    print "Finished analyzing log, $stats->{days} days total.\n";
}

sub opchanges {
    my (@ops, $plus);
    foreach (split(//, $_[0])) {
        if ($_ eq "o") {
            $ops[$plus]++;
        } elsif ($_ eq "+") {
            $plus = 0;
        } elsif ($_ eq "-") {
            $plus = 1;
        }
    }

    return @ops;
}

sub parse_words {
    my ($stats, $saying, $nick) = @_;

    foreach my $word (split(/[\s,!?.:;)(\"]+/, $saying)) {
        $stats->{words}{$nick}++;
        # remove uninteresting words
        next unless (length($word) >= $conf->{wordlength});
        next if ($conf->{ignoreword}{$word});

        # ignore contractions
        next if ($word =~ m/'..?$/);#'

        # Also ignore stuff from URLs.
        next if ($word =~ m{https?|^//});

        $stats->{wordcounts}{$word}++;
        $stats->{wordnicks}{$word} = $nick;
    }
}

sub pick_random_lines {
    my ($stats, $lines) = @_;

    foreach my $key (keys %{ $lines }) {
        foreach my $nick (keys %{ $lines->{$key} }) {
            $stats->{$key}{$nick} = 
            @{ $lines->{$key}{$nick} }[rand@{ $lines->{$key}{$nick} }];
        }
    }
}

sub strip_mirccodes {
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


1;
