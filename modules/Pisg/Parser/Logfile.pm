package Pisg::Parser::Logfile;

# Copyright and license, as well as documentation(POD) for this module is
# found at the end of the file.

use strict;
$^W = 1;

# test for Text::Iconv
my $have_iconv = 1;
eval 'use Text::Iconv';
$have_iconv = 0 if $@;

sub new
{
    my $type = shift;
    my $self = shift; # get cfg and users

    # Import common functions in Pisg::Common
    require Pisg::Common;
    Pisg::Common->import();

    bless($self, $type);

    # Pick our parser.
    $self->{parser} = $self->_choose_format($self->{cfg}->{format});

    if($self->{cfg}->{logcharsetfallback} and not $self->{cfg}->{logcharset}) {
        print "LogCharset undefined, assuming LogCharset = LogCharsetFallback\n"
            unless ($self->{cfg}->{silent});
        $self->{cfg}->{logcharset} = $self->{cfg}->{logcharsetfallback};
    }

    if($self->{cfg}->{logcharset}) {
        if($have_iconv) {
            # use converter if charsets differ or there is a fallback charset
            # (in the latter case the converter is also used to test if the
            # line is in the proper charset)
            if(($self->{cfg}->{logcharset} ne $self->{cfg}->{charset}) or $self->{cfg}->{logcharsetfallback}) {
                $self->{iconv} = Text::Iconv->new($self->{cfg}->{logcharset}, $self->{cfg}->{charset});
            }
            if($self->{cfg}->{logcharsetfallback}) {
                $self->{iconvfallback} = Text::Iconv->new($self->{cfg}->{logcharsetfallback}, $self->{cfg}->{charset});
            }
        } else {
            print "Text::Iconv is not installed, skipping charset conversion of logfiles\n"
                unless ($self->{cfg}->{silent});
        }
    }

    # precompile the regexps used (we can't use /o since the config might be different per channel)
    $self->{foulwords_regexp} = qr/($self->{cfg}->{foulwords})/i if $self->{cfg}->{foulwords};
    $self->{ignorewords_regexp} = qr/$self->{cfg}->{ignorewords}/i if $self->{cfg}->{ignorewords};
    $self->{violentwords_regexp} = qr/^($self->{cfg}->{violentwords}) (\S+)(.*)/i if $self->{cfg}->{violentwords};

    return $self;
}

# The function to choose which module to use.
sub _choose_format
{
    my $self = shift;
    my $format = shift;
    $self->{parser} = undef;
    eval <<_END;
use lib '$self->{cfg}->{modules_dir}';
use Pisg::Parser::Format::$format;
\$self->{parser} = new Pisg::Parser::Format::$format(
    cfg => \$self->{cfg},
);
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

    unless (defined $self->{parser}) {
        print STDERR "Skipping channel '$self->{cfg}->{channel}' due to lack of parser.\n";
        return undef
    }

    my $starttime = time();

    # Just initialize these to 0
    $stats{days} = 0;
    $stats{parsedlines} = 0;
    $stats{totallines} = 0;

    my @logfiles = @{$self->{cfg}->{logfile}};
    # expand wildcards
    @logfiles = map { if(/[\[*?]/) { glob; } else { $_; } } @logfiles;

    if (scalar(@{$self->{cfg}->{logdir}}) > 0) {
        push @logfiles, $self->_parse_dir(); # get all files in dir
    }

    my $count = @logfiles;
    my $shift = 0;
    if($self->{cfg}->{nfiles} > 0) { # chop list to maximal length
        $shift = @logfiles - $self->{cfg}->{nfiles};
        splice(@logfiles, 0, $shift) if $shift > 0;
    }

    unless ($self->{cfg}->{silent}) {
        my $msg = "";
        $msg = ", parsing the last $self->{cfg}->{nfiles}" if ($shift > 0);
        print "$count logfile(s) found$msg, using $self->{cfg}->{format} format...\n\n"
    }

    my %state = (
        lastnick   => '',
        monocount  => 0,
        lastnormal => '',
        oldtime    => 24
    );

    foreach my $logfile (@logfiles) {
        # Run through the logfile
        $self->_parse_file(\%stats, \%lines, $logfile, \%state);
    }

    $self->_pick_random_lines(\%stats, \%lines);
    _uniquify_nicks(\%stats);

    my ($sec,$min,$hour) = gmtime(time() - $starttime);
    my $processtime = sprintf('%02d hours, %02d minutes and %02d seconds', $hour, $min, $sec);

    $stats{processtime}{hours} = sprintf('%02d', $hour);
    $stats{processtime}{mins} = sprintf('%02d', $min);
    $stats{processtime}{secs} = sprintf('%02d', $sec);

    print "Channel analyzed successfully in $processtime on ",
    scalar localtime(time()), "\n\n"
        unless ($self->{cfg}->{silent});

    return \%stats;
}

sub _parse_dir
{
    my $self = shift;

    # Loop through each logdir we were given
    foreach my $logdir (@{$self->{cfg}->{logdir}}) {
        # Add trailing slash when it's not there..
        $logdir =~ s/([^\/])$/$1\//;

        unless ($self->{cfg}->{silent}) {
            print "Looking for logfiles in $logdir...\n\n"
        }
        my @filesarray;
        opendir(LOGDIR, $logdir) or
        die("Can't opendir ${logdir}: $!");
        @filesarray = grep {
            /^[^\.]/ && /^$self->{cfg}->{logprefix}/ && -f "$logdir/$_"
        } readdir(LOGDIR) or
        die("No files in \"$logdir\" matched prefix \"$self->{cfg}->{logprefix}\"");
        closedir(LOGDIR);

        if ($self->{cfg}->{logsuffix} ne '') {
            my @temparray;
            my %months = (
                'jan' => '0',
                'feb' => '1',
                'mar' => '2',
                'apr' => '3',
                'may' => '4',
                'jun' => '5',
                'jul' => '6',
                'aug' => '7',
                'sep' => '8',
                'oct' => '9',
                'nov' => '10',
                'dec' => '11',
            );
            my ($mreg, $dreg, $yreg) = split(/\|\|/, $self->{cfg}->{logsuffix});
            my (@month, @day, @year);
            for my $file (@filesarray) {
                LOOPSTART:
                if ($file =~ /$mreg/) {
                    my $month = $1;
                    $month = lc $month;
                    $month = $months{$month}
                        if (defined $months{$month});
                    push @month, $month;
                } else {
                    splice(@filesarray,$#month + 1, 1);
                    if ($file = $filesarray[$#month + 1]) {
                        goto LOOPSTART;
                    } else {
                        last;
                    }
                }
                if ($file =~ /$dreg/) {
                    push @day, $1;
                } else {
                    splice(@filesarray,$#day + 1, 1);
                    splice(@month,$#day + 1);
                    if ($file = $filesarray[$#day + 1]) {
                        goto LOOPSTART;
                    } else {
                        last;
                    }
                }
                if ($file =~ /$yreg/) {
                    push @year, $1;
                } else {
                    splice(@filesarray,$#year + 1, 1);
                    splice(@month,$#year + 1);
                    splice(@day,$#year + 1);
                    if ($file = $filesarray[$#year + 1]) {
                        goto LOOPSTART;
                    } else {
                        last;
                    }
                }
            }
            @filesarray = @filesarray[ sort {
                                        $year[$a] <=> $year[$b]
                                                ||
                                        $month[$a] <=> $month[$b]
                                                ||
                                        $day[$a] <=> $day[$b]
                                    } 0..$#filesarray ];
        } else {
            @filesarray = sort {lc($a) cmp lc($b)} @filesarray;
        }

        return map { "$logdir$_" } @filesarray;
    }
}

# This parses the file...
sub _parse_file
{
    my $self = shift;
    my ($stats, $lines, $file, $state) = @_;

    print "Analyzing log $file... "
        unless ($self->{cfg}->{silent});

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

    my $lastnormal = '';

    while(my $line = <LOGFILE>) {
        $line = _strip_mirccodes($line);
        $line =~ s/\r+$//;       # Strip DOS Formatting

        if($self->{iconv}) { # iconv is defined only if LogCharset is set
            my $line2 = $self->{iconv}->convert($line);
            if(not $line2 and $self->{iconvfallback}) {
                $line2 = $self->{iconvfallback}->convert($line);
            }
            if($line2) {
                $line = $line2;
            } else {
                print "Charset conversion failed for '$line'\n"
                    unless ($self->{cfg}->{silent});
            }
        }

        my $hashref;

        # Match normal lines.
        if ($hashref = $self->{parser}->normalline($line, $.)) {

            my $repeated = 0;
            if (defined $hashref->{repeated}) {
                $repeated = $hashref->{repeated};
            }

            my ($hour, $nick, $saying, $i);

            for ($i = 0; $i <= $repeated; $i++) {

                if ($i > 0) {
                    $hashref = $self->{parser}->normalline($lastnormal, $.);
                    #Increment number of lines for repeated lines
                }

                $hour   = $self->_adjusttimeoffset($hashref->{hour});
                $nick   = find_alias($hashref->{nick});
                checkname($hashref->{nick}, $nick, $stats) if ($self->{cfg}->{showmostnicks});
                $saying = $hashref->{saying};

                if ($hour < $state->{oldtime}) {
                    $stats->{days}++;
                    $stats->{day_times}{$stats->{days}}[0] = 0;
                    $stats->{day_times}{$stats->{days}}[1] = 0;
                    $stats->{day_times}{$stats->{days}}[2] = 0;
                    $stats->{day_times}{$stats->{days}}[3] = 0;
                    $stats->{day_lines}{$stats->{days}} = 0;
                }
                $state->{oldtime} = $hour;

                if (!is_ignored($nick)) {
                    $stats->{parsedlines}++;

                    # Timestamp collecting
                    $stats->{times}{$hour}++;
                    $stats->{day_times}{$stats->{days}}[int($hour/6)]++;
                    $stats->{day_lines}{$stats->{days}}++;

                    $stats->{lines}{$nick}++;
                    $stats->{lastvisited}{$nick} = $stats->{days};
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
                    } elsif (!$lines->{sayings}{$nick}) {
                        # Just fill the users first saying in if he hasn't
                        # said anything yet, to get rid of empty quotes.
                        push @{ $lines->{sayings}{$nick} }, substr($saying, 0, $self->{cfg}->{maxquote});
                    }

                    $stats->{lengths}{$nick} += $len;

                    $stats->{questions}{$nick}++
                        if (index($saying, '?') > -1);

                    $stats->{shouts}{$nick}++
                        if (index($saying, '!') > -1);

                    if ($saying !~ /[a-z]/o && $saying =~ /[A-Z]/o) {
                        # Ignore single smileys on a line. eg. '<user> :P'
                        if ($saying !~ /^[8;:=][ ^-o]?[)pPD}\]>]$/o) {
                            $stats->{allcaps}{$nick}++;
                            push @{ $lines->{allcaplines}{$nick} }, $line;
                        }
                    }

                    if ($self->{foulwords_regexp} and my @foul = $saying =~ /$self->{foulwords_regexp}/) {
                        $stats->{foul}{$nick} += scalar @foul;
                        push @{ $lines->{foullines}{$nick} }, $line;
                    }


                    # Who smiles the most?
                    # A regex matching al lot of smilies
                    $stats->{smiles}{$nick}++
                        if ($saying =~ /[8;:=][ ^-o]?[)pPD}\]>]/o);

                    if ($saying =~ /[8;:=][ ^-]?[\(\[\\\/{]/o and
                        $saying !~ /\w+:\/\//o) {
                        $stats->{frowns}{$nick}++;
                    }

                    if ($self->{cfg}->{showkarma}) {
                        # require 2 chars (catches C++), nick must not end in [+=-]
                        if ($saying =~ /^(\S*\w\S*\w\S*(?<![+=-]))(\+\+|==|--)$/o) {
                            my $thing = lc $1;
                            my $k = $2 eq "++" ? 1 : ($2 eq "==" ? 0 : -1);
                            $stats->{karma}{$thing}{$nick} = $k
                                if !is_ignored($thing) and $thing ne lc($nick);
                        }
                    }

                    # Find URLs
                    if (my @urls = match_urls($saying)) {
                        foreach my $url (@urls) {
                            if(!url_is_ignored($url)) {
                                $stats->{urlcounts}{$url}++;
                                $stats->{urlnicks}{$url} = $nick;
                            }
                        }
                    }

                    if (my $s = $self->{users}->{sex}{$nick}) {
                        $stats->{sex_lines}{$s}++;
                        $stats->{sex_line_times}{$s}[int($hour/6)]++;
                    }

                    _parse_words($stats, $saying, $nick, $self->{ignorewords_regexp}, $hour);
                }
            }
            $lastnormal = $line;
            $repeated = 0;
        }

        # Match action lines.
        elsif ($hashref = $self->{parser}->actionline($line, $.)) {
            $stats->{parsedlines}++;

            my ($hour, $nick, $saying);

            $hour   = $self->_adjusttimeoffset($hashref->{hour});
            $nick   = find_alias($hashref->{nick});
            checkname($hashref->{nick}, $nick, $stats) if ($self->{cfg}->{showmostnicks});
            $saying = $hashref->{saying};

            if ($hour < $state->{oldtime}) {
                $stats->{days}++;
                $stats->{day_times}{$stats->{days}}[0] = 0;
                $stats->{day_times}{$stats->{days}}[1] = 0;
                $stats->{day_times}{$stats->{days}}[2] = 0;
                $stats->{day_times}{$stats->{days}}[3] = 0;
                $stats->{day_lines}{$stats->{days}} = 0;
            }

            $state->{oldtime} = $hour;

            if (!is_ignored($nick)) {
                # Timestamp collecting
                $stats->{times}{$hour}++;
                $stats->{day_times}{$stats->{days}}[int($hour/6)]++;
                $stats->{day_lines}{$stats->{days}}++;

                $stats->{actions}{$nick}++;
                push @{ $lines->{actionlines}{$nick} }, $line;
                $stats->{lines}{$nick}++;
                $stats->{lastvisited}{$nick} = $stats->{days};
                $stats->{line_times}{$nick}[int($hour/6)]++;

                if ($self->{violentwords_regexp} and $saying =~ /$self->{violentwords_regexp}/) {
                    my $victim;
                    unless ($victim = is_nick($2)) {
                        foreach my $trynick (split(/\s+/, $3)) {
                            last if ($victim = is_nick($trynick));
                        }
                        unless ($victim) {
                            $victim = $2;
                        }
                    }
                    if (!is_ignored($victim)) {
                        $stats->{violence}{$nick}++;
                        $stats->{attacked}{$victim}++;
                        push @{ $lines->{violencelines}{$nick} }, $line;
                        push @{ $lines->{attackedlines}{$victim} }, $line;
                    }
                }

                $stats->{lengths}{$nick} += length($saying);

                if (my $s = $self->{users}->{sex}{$nick}) {
                    $stats->{sex_lines}{$s}++;
                    $stats->{sex_line_times}{$s}[int($hour/6)]++;
                }

                _parse_words($stats, $saying, $nick, $self->{ignorewords_regexp}, $hour);
            }
        }

        # Match *** lines.
        elsif (($hashref = $self->{parser}->thirdline($line, $.)) and $hashref->{nick}) {
            $stats->{parsedlines}++;

            my ($hour, $min, $nick, $kicker, $newtopic, $newmode, $newjoin);
            my ($newnick);

            $hour     = $self->_adjusttimeoffset($hashref->{hour});
            $min      = $hashref->{min};
            $nick     = find_alias($hashref->{nick});
            checkname($hashref->{nick}, $nick, $stats) if ($self->{cfg}->{showmostnicks});
            $kicker   = find_alias($hashref->{kicker})
                if ($hashref->{kicker});
            $newtopic = $hashref->{newtopic};
            $newmode  = $hashref->{newmode};
            $newjoin  = $hashref->{newjoin};
            $newnick  = $hashref->{newnick};

            if ($hour < $state->{oldtime}) {
                $stats->{days}++;
                $stats->{day_times}{$stats->{days}}[0]=0;
                $stats->{day_times}{$stats->{days}}[1]=0;
                $stats->{day_times}{$stats->{days}}[2]=0;
                $stats->{day_times}{$stats->{days}}[3]=0;
                $stats->{day_lines}{$stats->{days}}=0;
            }

            $state->{oldtime} = $hour;

            if (!is_ignored($nick)) {
                # Timestamp collecting
                $stats->{times}{$hour}++;
                $stats->{day_times}{$stats->{days}}[int($hour/6)]++;
                $stats->{day_lines}{$stats->{days}}++;

                $stats->{lastvisited}{$nick} = $stats->{days};

                if (defined($kicker)) {
                    if (!is_ignored($kicker)) {
                        $stats->{kicked}{$kicker}++;
                        $stats->{gotkicked}{$nick}++;
                        push @{ $lines->{kicklines}{$nick} }, $line;
                    }

                } elsif (defined($newtopic) && $newtopic ne '') {
                    _topic_change($stats, $newtopic, $nick, $hour, $min);

                } elsif (defined($newmode)) {
                    _modechanges($stats, $newmode, $nick);

                } elsif (defined($newjoin)) {
                    $stats->{joins}{$nick}++;

                } elsif (defined($newnick) and ($self->{cfg}->{nicktracking} == 1)) {
                    # Resolve new nick to the correct alias (this will create a hard-alias if it is using a regex)
                    $newnick = find_alias($newnick);
                    add_alias($nick, $newnick);
                    checkname($nick, $newnick, $stats) if ($self->{cfg}->{showmostnicks});
                }
            }
        }
    }

    $stats->{totallines} = $.;

    close(LOGFILE);

    print "$stats->{days} days, $stats->{parsedlines} lines total\n"
        unless ($self->{cfg}->{silent});
}

sub _topic_change
{
    my $stats = shift;
    my $newtopic = shift;
    my $nick = shift;
    my $hour = shift;
    my $min = shift;

    my $tcount = 0;
    if (defined $stats->{topics}) {
        $tcount = @{ $stats->{topics} };
    }
    $stats->{topics}[$tcount]{topic} = $newtopic;
    $stats->{topics}[$tcount]{nick}  = $nick;
    $stats->{topics}[$tcount]{hour}  = $hour;
    $stats->{topics}[$tcount]{min}   = $min;
}

sub _modechanges
{
    my $stats = shift;
    my $newmode = shift;
    my $nick = shift;

    my (@voice, @halfops, @ops, $plus);
    foreach (split(//, $newmode)) {
        if ($_ eq 'o') {
            $ops[$plus]++;
        } elsif ($_ eq 'h') {
            $halfops[$plus]++;
        } elsif ($_ eq 'v') {
            $voice[$plus]++;
        } elsif ($_ eq '+') {
            $plus = 0;
        } elsif ($_ eq '-') {
            $plus = 1;
        }
    }
    $stats->{gaveops}{$nick} += $ops[0] if $ops[0];
    $stats->{tookops}{$nick} += $ops[1] if $ops[1];
    $stats->{gavehalfops}{$nick} += $halfops[0] if $halfops[0];
    $stats->{tookhalfops}{$nick} += $halfops[1] if $halfops[1];
    $stats->{gavevoice}{$nick} += $voice[0] if $voice[0];
    $stats->{tookvoice}{$nick} += $voice[1] if $voice[1];
}

sub _parse_words
{
    my ($stats, $saying, $nick, $ignorewords_regexp, $hour) = @_;
    # Cache time of day
    my $tod = int($hour/6);

    foreach my $word (split(/[\s,!?.:;)(\"]+/o, $saying)) {
        $stats->{words}{$nick}++;
        $stats->{word_times}{$nick}[$tod]++;
        # remove uninteresting words
        next if $ignorewords_regexp and $word =~ m/$ignorewords_regexp/i;

        # ignore contractions
        next if ($word =~ m/'.{1,2}$/o);

        # Also ignore stuff from URLs.
        next if ($word =~ m/^https?$|^\/\//o);

        my $lcword = lc $word;
        $stats->{wordcounts}{$lcword}++;
        $stats->{wordnicks}{$lcword} = $nick;
        $stats->{word_upcase}{$lcword} ||= $word; # remember first-seen case
    }
}

sub _pick_random_lines
{
    my ($self, $stats, $lines) = @_;

    foreach my $key (keys %{ $lines }) {
        foreach my $nick (keys %{ $lines->{$key} }) {
            $stats->{$key}{$nick} = $self->_random_line($stats, $lines, $key, $nick, 0);
        }
    }
}

sub _random_line
{
    my ($self, $stats, $lines, $key, $nick, $count) = @_;
    my $random = ${ $lines->{$key}{$nick} }[rand@{ $lines->{$key}{$nick} }];
    if ($self->{cfg}->{noignoredquotes} and $self->{ignorewords_regexp} and $random =~ /$self->{ignorewords_regexp}/i) {
        return '' if ($count > 20);
        return $self->_random_line($stats, $lines, $key, $nick, ++$count);
    } else {
        return $random;
    }
}

sub _uniquify_nicks {
    my ($stats) = @_;

    foreach my $word (keys %{ $stats->{wordcounts} }) {
        if (my $realnick = lc(is_nick($word))) {
            if ($realnick ne $word) { # word is always lc
                $stats->{wordcounts}{$realnick} += $stats->{wordcounts}{$word};
                $stats->{wordnicks}{$realnick} ||= $stats->{wordnicks}{$word};
                $stats->{word_upcase}{$realnick} ||= $stats->{word_upcase}{$word};
                delete $stats->{wordcounts}{$word};
                delete $stats->{wordnicks}{$word};
                delete $stats->{word_upcase}{$word};
            }
        }
    }
}

sub _strip_mirccodes
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

sub checkname {
    # This function tracks nickchanges and puts them all in a hash->array,
    # so we can show all nicks that I user had later (only works properly
    # when nicktracking is enabled)
    my ($nick, $newnick, $stats) = @_;

    $stats->{nicks}{$newnick}{lc($nick)} = $nick;
}

sub _adjusttimeoffset
{
    my ($self, $hour) = @_;

    if ($self->{cfg}{timeoffset} != 0) {
        # Adjust time
        $hour += $self->{cfg}{timeoffset};
        $hour = $hour % 24;
    }
     
    return sprintf('%02d', $hour);
}

1;

__END__

=head1 NAME

Pisg::Parser::Logfile - class to parse a normal logfile

=head1 DESCRIPTION

C<Pisg::Parser::Logfile> parses a logfile using the configuration variables set in the 'cfg' option passed to the constructor.

=head1 SYNOPSIS

    use Pisg::Parser::Logfile;

    $analyzer = new Pisg::Parser::Logfile(
        { cfg => $self->{cfg}, users => $self->{users} }
    );

=head1 CONSTRUCTOR

=over 4

=item new ( [ OPTIONS ] )

This is the constructor for a new Pisg::Parser::Logfile object.

The first option must be a reference to a hash containing the cfg and users structures.

=back

=head1 AUTHOR

Morten Brix Pedersen <morten@wtf.dk>

=head1 COPYRIGHT

Copyright (C) 2001 Morten Brix Pedersen. All rights resereved.
This program is free software; you can redistribute it and/or modify it
under the terms of the GPL, license is included with the distribution of
this file.

=cut
