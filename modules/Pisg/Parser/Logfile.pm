package Pisg::Parser::Logfile;

=head1 NAME

Pisg::Parser::Logfile - class to parse a normal logfile

=cut

use strict;
$^W = 1;

sub new
{
    my $type = shift;
    my $self = {
        cfg => $_[0],
        debug => $_[1],
        parser => undef,
    };

    # Load the Common module from wherever it's configured to be.
    push(@INC, $self->{cfg}->{modules_dir});
    require Pisg::Common;
    Pisg::Common->import();

    bless($self, $type);

    # Pick our parser.
    $self->{parser} = $self->choose_log_format($self->{cfg}->{format});

    return $self;
}

# The function to choose which module to use.
sub choose_log_format
{
    my $self = shift;
    my $format = shift;
    $self->{parser} = undef;
    $self->{debug}->("Loading module for log format $format");
    eval <<_END;
use lib '$self->{cfg}->{modules_dir}';
use Pisg::Parser::Format::$format;
\$self->{parser} = new Pisg::Parser::Format::$format(\$self->{debug});
_END
    if ($@) {
        print STDERR "Could not load parser for '$format': $@\n";
        return undef;
    }
    return $self->{parser};
}

sub analyze
{
    my $self = shift;
    my (%stats, %lines);

    if (defined $self->{parser}) {
        my $starttime = time();

        if ($self->{cfg}->{logdir}) {
            # Run through all files in dir
            $self->parse_dir(\%stats, \%lines);
        } else {
            # Run through the whole logfile
            my %state = (
                linecount  => 0,
                lastnick   => "",
                monocount  => 0,
                lastnormal => "",
                oldtime    => 24
            );
            $self->parse_file(\%stats, \%lines, $self->{cfg}->{logfile}, \%state);
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
        print STDERR "Skipping channel '$self->{cfg}->{channel}' due to lack of parser.\n";
        return undef
    }

    # Shouldn't get here.
    return undef;
}

sub parse_dir
{
    my $self = shift;
    my ($stats, $lines) = @_;

    # Add trailing slash when it's not there..
    $self->{cfg}->{logdir} =~ s/([^\/])$/$1\//;

    print "Going into $self->{cfg}->{logdir} and parsing all files there...\n\n";
    my @filesarray;
    opendir(LOGDIR, $self->{cfg}->{logdir}) or
    die("Can't opendir $self->{cfg}->{logdir}: $!");
    @filesarray = grep {
        /^[^\.]/ && /^$self->{cfg}->{prefix}/ && -f "$self->{cfg}->{logdir}/$_"
    } readdir(LOGDIR) or
    die("No files in \"$self->{cfg}->{logdir}\" matched prefix \"$self->{cfg}->{prefix}\"");
    closedir(LOGDIR);

    my %state = (
        lastnick   => "",
        monocount  => 0,
        oldtime    => 24
    );
    foreach my $file (sort @filesarray) {
        $file = $self->{cfg}->{logdir} . $file;
        $self->parse_file($stats, $lines, $file, \%state);
    }
}

# This parses the file...
sub parse_file
{
    my $self = shift;
    my ($stats, $lines, $file, $state) = @_;

    print "Analyzing log($file) in '$self->{cfg}->{format}' format...\n";

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

    $stats->{days} = 0;
    $stats->{totallines} = 0;

    while(my $line = <LOGFILE>) {
        $line = strip_mirccodes($line);
        $linecount++;

        my $hashref;

        # Match normal lines.
        if ($hashref = $self->{parser}->normalline($line, $linecount)) {

            if (defined $hashref->{repeated}) {
                $repeated = $hashref->{repeated};
            } else {
                $repeated = 0;
            }

            my ($hour, $nick, $saying, $i);

            for ($i = 0; $i <= $repeated; $i++) {

                if ($i > 0) {
                    $hashref = $self->{parser}->normalline($lastnormal, $linecount);
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
                    if ($len > $self->{cfg}->{minquote} && $len < $self->{cfg}->{maxquote}) {
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
                    if ($saying =~ /$self->{cfg}->{foul}/i);

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

                    $self->parse_words($stats, $saying, $nick);
                }
            }
            $lastnormal = $line;
            $repeated = 0;
        }

        # Match action lines.
        elsif ($hashref = $self->{parser}->actionline($line, $linecount)) {
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

                if ($saying =~ /^($self->{cfg}->{violent}) (\S+)/) {
                    my $victim = find_alias($2);
                    $stats->{violence}{$nick}++;
                    $stats->{attacked}{$victim}++;
                    push @{ $lines->{violencelines}{$nick} }, $line;
                    push @{ $lines->{attackedlines}{$victim} }, $line;
                }


                my $len = length($saying);
                $stats->{lengths}{$nick} += $len;

                $self->parse_words($stats, $saying, $nick);
            }
        }

        # Match *** lines.
        elsif (($hashref = $self->{parser}->thirdline($line, $linecount)) and
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

                } elsif (defined($newnick) and ($self->{cfg}->{nicktracking} == 1)) {
                    add_alias($nick, $newnick);
                }
            }
        }
    }

    close(LOGFILE);

    print "Finished analyzing log, $stats->{days} days total.\n";
}

sub opchanges
{
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

sub parse_words
{
    my $self = shift;
    my ($stats, $saying, $nick) = @_;

    foreach my $word (split(/[\s,!?.:;)(\"]+/, $saying)) {
        $stats->{words}{$nick}++;
        # remove uninteresting words
        next unless (length($word) >= $self->{cfg}->{wordlength});
        next if ($self->{cfg}->{ignoreword}{$word});

        # ignore contractions
        next if ($word =~ m/'..?$/);#'

        # Also ignore stuff from URLs.
        next if ($word =~ m{https?|^//});

        $stats->{wordcounts}{$word}++;
        $stats->{wordnicks}{$word} = $nick;
    }
}

sub pick_random_lines
{
    my ($stats, $lines) = @_;

    foreach my $key (keys %{ $lines }) {
        foreach my $nick (keys %{ $lines->{$key} }) {
            $stats->{$key}{$nick} = 
            @{ $lines->{$key}{$nick} }[rand@{ $lines->{$key}{$nick} }];
        }
    }
}

sub strip_mirccodes
{
    my $line = shift;

    # boldcode = chr(2) = oct 001
    # colorcode = chr(3) = oct 003
    # plaincode = chr(15) = oct 017
    # reversecode = chr(22) = oct 026
    # underlinecode = chr(31) = oct 037

    # Strip mIRC color codes
    $line =~ s/\003\d{1,2},\d{1,2}//go;
    $line =~ s/\003\d{0,2}//go;
    # Strip mIRC bold, plain, reverse and underline codes
    $line =~ s/[\002\017\026\037]//go;

    return $line;
}


1;
