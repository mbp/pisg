package Pisg::HTMLGenerator;

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
    my %args = @_;
    my $self = {
        cfg => $args{cfg},
        stats => $args{stats},
        users => $args{users},
        tmps => $args{tmps},
        topactive => {},
    };

    # Import common functions in Pisg::Common
    require Pisg::Common;
    Pisg::Common->import();

    my $lang_charset = $self->{tmps}->{lc($self->{cfg}->{lang})}{lang_charset};
    if($lang_charset and $lang_charset ne $self->{cfg}->{charset}) {
        if($have_iconv) {
            # convert from template charset to our
            $self->{iconv} = Text::Iconv->new($lang_charset, $self->{cfg}->{charset});
        } else {
            print STDERR "Text::Iconv is not available, skipping charset conversion for language templates\n";
        }
    }

    bless($self, $type);
    return $self;
}

sub create_output
{
    # This subroutine calls all the subroutines which create their
    # individual stats. The name of the functions is somewhat saying - if
    # you don't understand it, most subs have a better explanation in the
    # sub itself.

    my $self = shift;

    $self->_topactive();

    my $fname = $self->{cfg}->{outputfile};
    $fname =~ s/\%t/$self->{cfg}->{outputtag}/g;
    print "Now generating HTML($fname)...\n"
        unless ($self->{cfg}->{silent});

    open (OUTPUT, "> $fname") or
        die("$0: Unable to open outputfile($fname): $!\n");

    if ($self->{cfg}->{showtime}) {
        $self->{cfg}->{tablewidth} += 40;
    }
    if ($self->{cfg}->{showlinetime}) {
        $self->{cfg}->{tablewidth} += 100;
    }
    if ($self->{cfg}->{showwordtime}) {
        $self->{cfg}->{tablewidth} += 100;
    }
    if ($self->{cfg}->{showwords}) {
        $self->{cfg}->{tablewidth} += 40;
    }
    if ($self->{cfg}->{showwpl}) {
        $self->{cfg}->{tablewidth} += 40;
    }
    if ($self->{cfg}->{showcpl}) {
        $self->{cfg}->{tablewidth} += 40;
    }
    if ($self->{cfg}->{userpics}) {
        $self->{cfg}->{tablewidth} += $self->{cfg}->{userpics} * ($self->{cfg}->{picwidth} || 60);
    }
    $self->{cfg}->{headwidth} = $self->{cfg}->{tablewidth} - 4;
    $self->_htmlheader();
    $self->_pageheader()
        if ($self->{cfg}->{pagehead} ne 'none');

    if ($self->{cfg}->{dailyactivity}) {
	$self->_activedays();
    }

    if ($self->{cfg}->{showactivetimes}) {
        $self->_activetimes();
    }
    $self->_activenicks();

    if ($self->{cfg}->{showmostactivebyhour}) {
        $self->_mostactivebyhour();
    }

    if ($self->{cfg}->{showbignumbers}) {
        $self->_headline($self->_template_text('bignumtopic'));
        _html("<table width=\"$self->{cfg}->{tablewidth}\">\n"); # Needed for sections
        $self->_questions();
        $self->_shoutpeople();
        $self->_capspeople();
        $self->_violent();
        $self->_mostsmiles();
        $self->_mostsad();
        $self->_linelengths();
        $self->_mostwords();
        $self->_mostwordsperline();
        _html("</table>"); # Needed for sections
    }

    if ($self->{cfg}->{showmostnicks}) {
        $self->_mostnicks();
    }

    if ($self->{cfg}->{showmuw}) {
        $self->_mostusedword();
    }

    if ($self->{cfg}->{showmrn}) {
        $self->_mostreferencednicks();
    }

    if ($self->{cfg}->{showmru}) {
        $self->_mosturls();
    }

    if ($self->{cfg}->{showbignumbers}) {
        $self->_headline($self->_template_text('othernumtopic'));
        _html("<table width=\"$self->{cfg}->{tablewidth}\">\n"); # Needed for sections
        $self->_gotkicks();
        $self->_mostkicks();
        $self->_mostop() if $self->{cfg}->{showops};
        $self->_mosthalfop() if $self->{cfg}->{showhalfops};
        $self->_mostvoice() if $self->{cfg}->{showvoices};
        $self->_mostactions();
        $self->_mostmonologues();
        $self->_mostjoins();
        $self->_mostfoul();
        _html("</table>"); # Needed for sections
    }

    if ($self->{cfg}->{showtopics}) {
        $self->_headline($self->_template_text('latesttopic'));
        _html("<table width=\"$self->{cfg}->{tablewidth}\">\n"); # Needed for sections

        $self->_lasttopics();

        _html("</table>"); # Needed for sections
    }

    my %hash = ( lines => $self->{stats}->{parsedlines} );
    _html($self->_template_text('totallines', %hash) . "<br /><br />");

    $self->_pagefooter()
        if ($self->{cfg}->{pagefoot} ne 'none');

    $self->_htmlfooter();

    close(OUTPUT);
}

sub _htmlheader
{
    my $self = shift;
    my %hash = (
        network    => $self->{cfg}->{network},
        maintainer => $self->{cfg}->{maintainer},
        days       => $self->{stats}->{days},
        nicks      => scalar keys %{ $self->{stats}->{lines} }
    );

    my $css_file = $self->{cfg}->{cssdir} . $self->{cfg}->{colorscheme} . ".css";

    # Get the chosen CSS file
    open(FILE, $css_file) or open (FILE, $self->{cfg}->{search_path} . "/$css_file") or die("$0: Unable to open stylesheet($css_file): $!\n");

    my @CSS = <FILE>;

    my $title = $self->_template_text('pagetitle1', %hash);
    print OUTPUT <<HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=$self->{cfg}->{charset}" />
<title>$title</title>
<style type="text/css">
@CSS
</style></head>
<body>
<div align="center">
HTML
    _html("<span class=\"title\">$title</span><br />");
    _html("<br />");
    _html($self->_template_text('pagetitle2', %hash) . " " . $self->get_time());

    _html("<br />" . $self->_template_text('pagetitle3', %hash) . "<br /><br />");

}

sub get_time
{
    my $self = shift;
    my ($tday, %hash);

    my $month = $self->_template_text('month', %hash);
    my $day = $self->_template_text('day', %hash);

    my @month = split(" ", $month);
    my @day = split(" ", $day);

    # Get the Date from the users computer
    my $timezone = $self->{cfg}->{timeoffset} * 3600;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time+$timezone);

    $year += 1900;                    # Y2K Patch

    $min =~ s/^(.)$/0$1/;             # Fixes the display of mins/secs below
    $sec =~ s/^(.)$/0$1/;             # it displays 03 instead of 3

    if ($hour > '23') {               # Checks to see if it Midnight
        $hour = 12;                   # Makes it display the hour 12
        $tday = "AM";                 # Display AM
    } elsif($hour > '12') {           # Get rid of the Military time and
        $hour -= 12;                  # put it into normal time
        $tday = "PM";                 # If past Noon and before Midnight set
    } else {
        $tday = "AM";                 # If it's past Midnight and before Noon
    }                                 # set the time as AM

    # Use 24 hours pr. day
    if ($tday eq "PM" && $hour < '12') {
        $hour += 12;
    }

    return "$day[$wday] $mday $month[$mon] $year - $hour:$min:$sec";
}


sub _htmlfooter
{
    my $self = shift;

    my %hash;

    my $pisg_hp = $self->_template_text('pisghomepage');
    $hash{pisg_url} = "<a href=\"http://pisg.sourceforge.net/\" title=\"$pisg_hp\" class=\"background\">pisg</a>";

    my $author_hp = $self->_template_text('authorhomepage');
    $hash{author_url} = "<a href=\"http://mbrix.dk/\" title=\"$author_hp\" class=\"background\">Morten Brix Pedersen</a>";

    $hash{version} = $self->{cfg}->{version};

    my $hours = $self->_template_text('hours');
    my $mins = $self->_template_text('minutes');
    my $secs = $self->_template_text('seconds');
    my $and = $self->_template_text('and');

    my $h = $self->{stats}->{processtime}{hours};
    my $m = $self->{stats}->{processtime}{mins};
    my $s = $self->{stats}->{processtime}{secs};
    $hash{time} = "$h $hours $m $mins $and $s $secs";

    my $stats_gen = $self->_template_text('stats_gen_by', %hash);
    my $author_text = $self->_template_text('author', %hash);
    my $stats_text = $self->_template_text('stats_gen_in', %hash);

    print OUTPUT <<HTML;
<span class="small">
$stats_gen<br />
$author_text<br />
$stats_text
</span>
</div>
</body>
</html>
HTML
}

sub _headline
{
    my $self = shift;
    my ($title) = (@_);
    print OUTPUT <<HTML;
   <br />
   <table width="$self->{cfg}->{headwidth}" cellpadding="1" cellspacing="0" border="0">
    <tr>
     <td class="headlinebg">
      <table width="100%" cellpadding="2" cellspacing="0" border="0">
       <tr>
        <td class="headtext">$title</td>
       </tr>
      </table>
     </td>
    </tr>
   </table>
HTML
}

sub _pageheader
{
    my $self = shift;
    open(PAGEHEAD, $self->{cfg}->{pagehead}) or die("$0: Unable to open $self->{cfg}->{pagehead} for reading: $!\n");
    while (<PAGEHEAD>) {
        _html($_);
    }
    close(PAGEHEAD);
}

sub _pagefooter
{
    my $self = shift;
    open(PAGEFOOT, $self->{cfg}->{pagefoot}) or die("$0: Unable to open $self->{cfg}->{pagefoot} for reading: $!\n");
    while (<PAGEFOOT>) {
        _html($_);
    }
    close(PAGEFOOT);
}

sub _activedays
{
    # The most actives times on the channel
    my $self = shift;
    my $days = $self->{stats}->{days};
    my $ndays = $self->{cfg}->{dailyactivity};
    my $image;
    my $time;
    my $day;

    my (%output, $class);

    my $highest_value = 1;
    for ($day = $days; $day > $days - $ndays ; $day--) {
        if (defined($self->{stats}->{day_lines}{$day})) {
            if ($self->{stats}->{day_lines}{$day} > $highest_value) {
                $highest_value=$self->{stats}->{day_lines}{$day};
            }
        } else {
            #there are only $days - $day days :)
            $ndays = $days - $day;
        }
    }

    my %hash = (
        n => $ndays
    );
    $self->_headline($self->_template_text('dailyactivitytopic', %hash));

    _html("<table border=\"0\"><tr>\n");

    for ($day = $days - $ndays +1; $day <= $days ; $day++) {
        my $lines = $self->{stats}->{day_lines}{$day};
        _html("<td align=\"center\" valign=\"bottom\" class=\"asmall\">$lines<br />");
        for ($time = 4; $time >= 0; $time--) {
            if (defined($self->{stats}->{day_times}{$day}[$time])) {
                my $size = int(($self->{stats}->{day_times}{$day}[$time] / $highest_value) * 100);

                if ($size < 1) {
                    # Opera doesn't understand '0.xxxx' in the height="xx" attr,
                    # so we simply round up to 1 here.
                    $size = 1;
                }

                $image = "pic_v_".$time*6;
                $image = $self->{cfg}->{$image};
                _html("<img src=\"$self->{cfg}->{piclocation}/$image\" width=\"15\" height=\"$size\" alt=\"$lines\" /><br />");

            }
        }
        _html("</td>\n");
    }

    _html("</tr><tr>");

    for ($b = $ndays-1; $b >= 0 ; $b--) {
            $class = 'rankc10center';
        _html("<td class=\"$class\" align=\"center\">$b</td>");
}

    _html("</tr></table>");

    if($self->{cfg}->{showlegend} == 1) {
        $self->_legend();
    }
}

sub _activetimes
{
    # The most actives times on the channel
    my $self = shift;

    my (%output, $class);

    $self->_headline($self->_template_text('activetimestopic'));

    my @toptime = sort { $self->{stats}->{times}{$b} <=> $self->{stats}->{times}{$a} } keys %{ $self->{stats}->{times} };

    my $highest_value = $self->{stats}->{times}{$toptime[0]};

    my @now = localtime($self->{cfg}->{timestamp});

    my $image;

    for my $hour (sort keys %{ $self->{stats}->{times} }) {

        my $size = int(($self->{stats}->{times}{$hour} / $highest_value) * 100);
        my $percent = ($self->{stats}->{times}{$hour} / $self->{stats}->{parsedlines}) * 100;
        $percent =~ s/(\.\d)\d+/$1/;

        if ($size < 1) {
            # Opera doesn't understand '0.xxxx' in the height="xx" attr,
            # so we simply round up to 1 here.
            $size = 1;
        }

        $image = "pic_v_".(int($hour/6)*6);
        $image = $self->{cfg}->{$image};

        $output{$hour} = "<td align=\"center\" valign=\"bottom\" class=\"asmall\">$percent%<br /><img src=\"$self->{cfg}->{piclocation}/$image\" width=\"15\" height=\"$size\" alt=\"$percent\" /></td>\n";
    }

    _html("<table border=\"0\"><tr>\n");

    for ($b = 0; $b < 24; $b++) {
        $a = sprintf("%02d", $b);

        if (!defined($output{$a}) || $output{$a} eq "") {
            _html("<td align=\"center\" valign=\"bottom\" class=\"asmall\">0%</td>");
        } else {
            _html($output{$a});
        }
    }

    _html("</tr><tr>");

    # Remove leading zero
    $toptime[0] =~ s/0(\d)/$1/;

    for ($b = 0; $b < 24; $b++) {
        if ($toptime[0] == $b) {
            # Highlight the top time
            $class = 'hirankc10center';
        } else {
            $class = 'rankc10center';
        }
        _html("<td class=\"$class\" align=\"center\">$b</td>");
}

    _html("</tr></table>");

    if($self->{cfg}->{showlegend} == 1) {
        $self->_legend();
    }
}

sub _activenicks
{
    # The most active nicks (those who wrote most lines)
    my $self = shift;

    $self->_headline($self->_template_text('activenickstopic'));

    _html("<table border=\"0\" width=\"$self->{cfg}->{tablewidth}\"><tr>");
    _html("<td>&nbsp;</td>"
    . "<td class=\"tdtop\"><b>" . $self->_template_text('nick') . "</b></td>"
    . "<td class=\"tdtop\"><b>" . $self->_template_text('numberlines') . "</b></td>"
    . ($self->{cfg}->{showtime} ? "<td class=\"tdtop\"><b>".$self->_template_text('show_time')."</b></td>" : "")
    . ($self->{cfg}->{showwords} ? "<td class=\"tdtop\"><b>".$self->_template_text('show_words')."</b></td>" : "")
    . ($self->{cfg}->{showwpl} ? "<td class=\"tdtop\"><b>".$self->_template_text('show_wpl')."</b></td>" : "")
    . ($self->{cfg}->{showcpl} ? "<td class=\"tdtop\"><b>".$self->_template_text('show_cpl')."</b></td>" : "")
    . ($self->{cfg}->{showlastseen} ? "<td class=\"tdtop\"><b>".$self->_template_text('show_lastseen')."</b></td>" : "")
    . ($self->{cfg}->{showrandquote} ? "<td class=\"tdtop\"><b>".$self->_template_text('randquote')."</b></td>" : "")
    );

    my @active;
    my $nicks;
    if ($self->{cfg}->{sortbywords}) {
        @active = sort { $self->{stats}->{words}{$b} <=> $self->{stats}->{words}{$a} } keys %{ $self->{stats}->{words} };
        $nicks = scalar keys %{ $self->{stats}->{words} };
    } else {
        @active = sort { $self->{stats}->{lines}{$b} <=> $self->{stats}->{lines}{$a} } keys %{ $self->{stats}->{lines} };
        $nicks = scalar keys %{ $self->{stats}->{lines} };
    }

    if ($self->{cfg}->{activenicks} > $nicks) { $self->{cfg}->{activenicks} = $nicks; }

    for (my $c = 0; $c < $self->{cfg}->{activenicks}; $c++) {
        last unless $self->{cfg}->{userpics};
        my $nick = $active[$c];
        if ($self->{users}->{userpics}{$nick}) {
            _html("<td class=\"tdtop\"" .
                ($self->{cfg}->{userpics} > 1 ? " colspan=\"$self->{cfg}->{userpics}\"" : "") .
                "><b>" . $self->_template_text('userpic') ."</b></td>");
            last;
        }
    }
    _html("</tr>");

    for (my $i = 0; $i < $self->{cfg}->{activenicks}; $i++) {
        my $c = $i + 1;
        my $nick = $active[$i];
        my $visiblenick = $active[$i];

        my $randomline;
        if (not defined $self->{stats}->{sayings}{$nick}) {
            if ($self->{stats}->{actions}{$nick}) {
                $randomline = $self->{stats}->{actionlines}{$nick};
            } else {
                $randomline = "";
            }
        } else {
            $randomline = $self->{stats}->{sayings}{$nick};
        }

        if ($randomline) {
            $randomline = $self->_format_line($randomline);
        }

        # Add a link to the nick if there is any
        if ($self->{users}->{userlinks}{$nick}) {
            $visiblenick = $self->_replace_links($self->{users}->{userlinks}{$nick}, $nick);
        }

        my $color = $self->generate_colors($c);
        my $class = 'rankc';
        if ($c == 1) {
            $class = 'hirankc';
        }

        my $lastseen;

        if ($self->{cfg}->{showlastseen}) {
            $lastseen = $self->{stats}->{days} - $self->{stats}->{lastvisited}{$nick};
            if ($lastseen == 0) {
                $lastseen = $self->_template_text('today');
            } elsif ($lastseen == 1) {
                $lastseen = "$lastseen " .$self->_template_text('lastseen1');
            } else {
                $lastseen = "$lastseen " .$self->_template_text('lastseen2');
            }
        }

        _html("<tr><td class=\"$class\" align=\"left\">$c</td>");

        my $line = $self->{stats}->{lines}{$nick};
        my $w = $self->{stats}->{words}{$nick} ? $self->{stats}->{words}{$nick} : 0;
        my $ch   = $self->{stats}->{lengths}{$nick};
       my $sex = $self->{users}->{sex}{$nick};
       _html("<td style=\"background-color: $color\""
       . ($sex ? ($sex eq 'm' ? " class=\"male\">"
       : ($sex eq 'f' ? " class=\"female\">" : " class=\"bot\">")) : ">")
       ."$visiblenick</td>"
        . ($self->{cfg}->{showlinetime} ?
        "<td style=\"background-color: $color\" nowrap=\"nowrap\">".$self->_user_linetimes($nick,$active[0])."</td>"
        : "<td style=\"background-color: $color\">$line</td>")
        . ($self->{cfg}->{showtime} ?
        "<td style=\"background-color: $color\">".$self->_user_times($nick)."</td>"
        : "")
        . ($self->{cfg}->{showwords} ?
           ($self->{cfg}->{showwordtime} ?
           "<td style=\"background-color: $color\" nowrap=\"nowrap\">".$self->_user_wordtimes($nick,$active[0])."</td>"
           : "<td style=\"background-color: $color\">$w</td>")
        : "")
        . ($self->{cfg}->{showwpl} ?
        "<td style=\"background-color: $color\">".sprintf("%.1f",$w/$line)."</td>"
        : "")
        . ($self->{cfg}->{showcpl} ?
        "<td style=\"background-color: $color\">".sprintf("%.1f",$ch/$line)."</td>"
        : "")
        . ($self->{cfg}->{showlastseen} ?
        "<td style=\"background-color: $color\">$lastseen</td>"
        : "")
        . ($self->{cfg}->{showrandquote} ?
        "<td style=\"background-color: $color\">\"$randomline\"</td>"
        : "")
        );
        if ($self->{cfg}->{userpics} && $i % $self->{cfg}->{userpics} == 0) {
            for my $ii (0 .. $self->{cfg}->{userpics} - 1) {
                last if $i + $ii >= $self->{cfg}->{activenicks};
                $self->_user_pic($active[$i + $ii], $color);
            }
        }
        _html("</tr>");
    }

    _html("</table><br />");

    # Almost as active nicks ('These didn't make it to the top..')

    my $toshow = $self->{cfg}->{activenicks2} - $self->{cfg}->{activenicks};
    my $remain = $self->{cfg}->{activenicks} + $toshow;

    unless ($toshow > $nicks) {
        $remain = $self->{cfg}->{activenicks} + $self->{cfg}->{activenicks2};
        if ($remain > $nicks) {
            $remain = $nicks;
        }

        if ($self->{cfg}->{activenicks} <  $remain) {
            _html("<br /><b><i>" . $self->_template_text('nottop') . "</i></b><table><tr>");
            for (my $i = $self->{cfg}->{activenicks}; $i < $remain; $i++) {
                unless ($i % 5) { if ($i != $self->{cfg}->{activenicks}) { _html("</tr><tr>"); } }
                my $items;
                if ($self->{cfg}->{sortbywords}) {
                    $items = $self->{stats}->{words}{$active[$i]};
                } else {
                    $items = $self->{stats}->{lines}{$active[$i]};
                }
               my $sex = $self->{users}->{sex}{$active[$i]};
                _html("<td class=\"rankc10\">"
                . ($sex ? ($sex eq 'm' ? "<span class=\"male\">"
                : ($sex eq 'f' ? "<span class=\"female\">" : "<span class=\"bot\">")) : "")
                ."$active[$i] ($items)"
                . ($sex ? "</span>" : "")
                ."</td>");
            }
            _html("</tr></table>");
        }
    }

    my %hash;
    $hash{totalnicks} = $nicks - $remain;
    if ($hash{totalnicks} > 0) {
        _html("<br /><b>" . $self->_template_text('totalnicks', %hash) . "</b><br />");
    }
}

sub generate_colors
{
    my $self = shift;
    my $c = shift;

    my $h = $self->{cfg}->{hicell};
    $h =~ s/^#//;
    $h = hex $h;
    my $h2 = $self->{cfg}->{hicell2};
    $h2 =~ s/^#//;
    $h2 = hex $h2;
    my $f_b = $h & 0xff;
    my $f_g = ($h & 0xff00) >> 8;
    my $f_r = ($h & 0xff0000) >> 16;
    my $t_b = $h2 & 0xff;
    my $t_g = ($h2 & 0xff00) >> 8;
    my $t_r = ($h2 & 0xff0000) >> 16;
    my $blue  = sprintf "%0.2x", abs int(((($t_b - $f_b) / $self->{cfg}->{activenicks}) * +$c) + $f_b);
    my $green  = sprintf "%0.2x", abs int(((($t_g - $f_g) / $self->{cfg}->{activenicks}) * +$c) + $f_g);
    my $red  = sprintf "%0.2x", abs int(((($t_r - $f_r) / $self->{cfg}->{activenicks}) * +$c) + $f_r);

    return "#$red$green$blue";
}

sub _html
{
    my $html = shift;
    print OUTPUT "$html\n";
}

sub _questions
{
    # Persons who asked the most questions
    my $self = shift;

    my %qpercent;

    foreach my $nick (sort keys %{ $self->{stats}->{questions} }) {
        if ($self->{topactive}{$nick} || !$self->{cfg}->{showonlytop}) {
          if ($self->{stats}->{lines}{$nick} > 100) {
              $qpercent{$nick} = ($self->{stats}->{questions}{$nick} / $self->{stats}->{lines}{$nick}) * 100;
              $qpercent{$nick} =~ s/(\.\d)\d+/$1/;
          }
        }
    }

    my @question = sort { $qpercent{$b} <=> $qpercent{$a} } keys %qpercent;

    if (@question) {
        my %hash = (
            nick => $question[0],
            per  => $qpercent{$question[0]}
        );

        my $text = $self->_template_text('question1', %hash);
        _html("<tr><td class=\"hicell\">$text");
        if (@question >= 2) {
            my %hash = (
                nick => $question[1],
                per => $qpercent{$question[1]}
            );

            my $text = $self->_template_text('question2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");

    } else {
        _html("<tr><td class=\"hicell\">" . $self->_template_text('question3') . "</td></tr>");
    }
}

sub _shoutpeople
{
    # The ones who speak with exclamation marks!
    my $self = shift;

    my %spercent;

    foreach my $nick (sort keys %{ $self->{stats}->{shouts} }) {
        if ($self->{topactive}{$nick} || !$self->{cfg}->{showonlytop}) {
          if ($self->{stats}->{lines}{$nick} > 100) {
              $spercent{$nick} = ($self->{stats}->{shouts}{$nick} / $self->{stats}->{lines}{$nick}) * 100;
              $spercent{$nick} =~ s/(\.\d)\d+/$1/;
          }
        }
    }

    my @shout = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;

    if (@shout) {
        my %hash = (
            nick => $shout[0],
            per  => $spercent{$shout[0]}
        );

        my $text = $self->_template_text('shout1', %hash);
        _html("<tr><td class=\"hicell\">$text");
        if (@shout >= 2) {
            my %hash = (
                nick => $shout[1],
                per  => $spercent{$shout[1]}
            );

            my $text = $self->_template_text('shout2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");

    } else {
        my $text = $self->_template_text('shout3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }

}

sub _capspeople
{
    # The ones who speak ALL CAPS.
    my $self = shift;

    my %cpercent;

    foreach my $nick (sort keys %{ $self->{stats}->{allcaps} }) {
        if ($self->{topactive}{$nick} || !$self->{cfg}->{showonlytop}) {
          if ($self->{stats}->{lines}{$nick} > 100) {
              $cpercent{$nick} = $self->{stats}->{allcaps}{$nick} / $self->{stats}->{lines}{$nick} * 100;
              $cpercent{$nick} =~ s/(\.\d)\d+/$1/;
          }
        }
    }

    my @caps = sort { $cpercent{$b} <=> $cpercent{$a} } keys %cpercent;

    if (@caps) {
        my %hash = (
            nick => $caps[0],
            per  => $cpercent{$caps[0]},
            line => $self->_format_line($self->{stats}->{allcaplines}{$caps[0]})
        );

        my $text = $self->_template_text('allcaps1', %hash);
        if($self->{cfg}->{showshoutline}) {
            my $exttext = $self->_template_text('allcapstext', %hash);
            _html("<tr><td class=\"hicell\">$text<br /><span class=\"small\">$exttext</span>");
        } else {
            _html("<tr><td class=\"hicell\">$text");
        }
        if (@caps >= 2) {
            my %hash = (
                nick => $caps[1],
                per  => $cpercent{$caps[1]}
            );

            my $text = $self->_template_text('allcaps2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");

    } else {
        my $text = $self->_template_text('allcaps3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }
}

sub _violent
{
    # They attacked others (words defined by $self->{cfg}->{violent})
    my $self = shift;

    my @aggressors = sort { $self->{stats}->{violence}{$b} <=> $self->{stats}->{violence}{$a} }
                         keys %{ $self->{stats}->{violence} };

    @aggressors = $self->_istoponly(@aggressors);

    if(@aggressors) {
        my %hash = (
            nick    => $aggressors[0],
            attacks => $self->{stats}->{violence}{$aggressors[0]},
            line    => $self->_format_line($self->{stats}->{violencelines}{$aggressors[0]})
        );
        my $text = $self->_template_text('violent1', %hash);
        if($self->{cfg}->{showviolentlines}) {
            my $exttext = $self->_template_text('violenttext', %hash);
            _html("<tr><td class=\"hicell\">$text<br /><span class=\"small\">$exttext</span>");
        } else {
            _html("<tr><td class=\"hicell\">$text");
        }
        if (@aggressors >= 2) {
            my %hash = (
                nick    => $aggressors[1],
                attacks => $self->{stats}->{violence}{$aggressors[1]}
            );

            my $text = $self->_template_text('violent2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('violent3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }


    # They got attacked
    my @victims = sort { $self->{stats}->{attacked}{$b} <=> $self->{stats}->{attacked}{$a} }
                    keys %{ $self->{stats}->{attacked} };

    @victims = $self->_istoponly(@victims);

    if(@victims) {
        my %hash = (
            nick    => $victims[0],
            attacks => $self->{stats}->{attacked}{$victims[0]},
            line    => $self->_format_line($self->{stats}->{attackedlines}{$victims[0]})
        );
        my $text = $self->_template_text('attacked1', %hash);
        if($self->{cfg}->{showviolentlines}) {
            my $exttext = $self->_template_text('attackedtext', %hash);
            _html("<tr><td class=\"hicell\">$text<br /><span class=\"small\">$exttext</span>");
        } else {
            _html("<tr><td class=\"hicell\">$text");
        }
        if (@victims >= 2) {
            my %hash = (
                nick    => $victims[1],
                attacks => $self->{stats}->{attacked}{$victims[1]}
            );

            my $text = $self->_template_text('attacked2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    }
}

sub _gotkicks
{
    # The persons who got kicked the most
    my $self = shift;

    my @gotkick = sort { $self->{stats}->{gotkicked}{$b} <=> $self->{stats}->{gotkicked}{$a} }
                       keys %{ $self->{stats}->{gotkicked} };

    @gotkick = $self->_istoponly(@gotkick);

    if (@gotkick) {
        my %hash = (
            nick  => $gotkick[0],
            kicks => $self->{stats}->{gotkicked}{$gotkick[0]},
            line  => $self->_format_line($self->{stats}->{kicklines}{$gotkick[0]})
        );

        my $text = $self->_template_text('gotkick1', %hash);

        if ($self->{cfg}->{showkickline}) {
            my $exttext = $self->_template_text('kicktext', %hash);
            _html("<tr><td class=\"hicell\">$text<br /><span class=\"small\">$exttext</span>");
        } else {
            _html("<tr><td class=\"hicell\">$text");
        }

        if (@gotkick >= 2) {
            my %hash = (
                nick  => $gotkick[1],
                kicks => $self->{stats}->{gotkicked}{$gotkick[1]}
            );

            my $text = $self->_template_text('gotkick2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    }
}

sub _mostjoins
{
    my $self = shift;

    my @joins = sort { $self->{stats}->{joins}{$b} <=> $self->{stats}->{joins}{$a} }
                     keys %{ $self->{stats}->{joins} };

    @joins = $self->_istoponly(@joins);

    if (@joins) {
        my %hash = (
            nick  => $joins[0],
            joins => $self->{stats}->{joins}{$joins[0]}
        );

        my $text = $self->_template_text('joins', %hash);

        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }
}

sub _mostwords
{
    # The person who got words the most
    my $self = shift;

    my @words = sort { $self->{stats}->{words}{$b} <=> $self->{stats}->{words}{$a} }
                      keys %{ $self->{stats}->{words} };

    @words = $self->_istoponly(@words);

    if (@words) {
        my %hash = (
            nick  => $words[0],
            words => $self->{stats}->{words}{$words[0]}
        );

        my $text = $self->_template_text('words1', %hash);
        _html("<tr><td class=\"hicell\">$text");

        if (@words >= 2) {
            my %hash = (
                oldnick => $words[0],
                nick    => $words[1],
                words   => $self->{stats}->{words}{$words[1]}
            );

            my $text = $self->_template_text('words2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('kick3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }
}

sub _mostkicks
{
    # The person who kicked the most
    my $self = shift;

    my @kicked = sort { $self->{stats}->{kicked}{$b} <=> $self->{stats}->{kicked}{$a} }
                        keys %{ $self->{stats}->{kicked} };

    @kicked = $self->_istoponly(@kicked);

    if (@kicked) {
        my %hash = (
            nick   => $kicked[0],
            kicked => $self->{stats}->{kicked}{$kicked[0]}
        );

        my $text = $self->_template_text('kick1', %hash);
        _html("<tr><td class=\"hicell\">$text");

        if (@kicked >= 2) {
            my %hash = (
                oldnick => $kicked[0],
                nick    => $kicked[1],
                kicked  => $self->{stats}->{kicked}{$kicked[1]}
            );

            my $text = $self->_template_text('kick2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('kick3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }
}

sub _mostmonologues
{
    # The person who had the most monologues (speaking to himself)
    my $self = shift;

    my @monologue = sort { $self->{stats}->{monologues}{$b} <=> $self->{stats}->{monologues}{$a} } 
                           keys %{ $self->{stats}->{monologues} };

    @monologue = $self->_istoponly(@monologue);

    if (@monologue) {
        my %hash = (
            nick  => $monologue[0],
            monos => $self->{stats}->{monologues}{$monologue[0]}
        );

        my $text = $self->_template_text('mono1', %hash);

        _html("<tr><td class=\"hicell\">$text");
        if (@monologue >= 2) {
            my %hash = (
                nick  => $monologue[1],
                monos => $self->{stats}->{monologues}{$monologue[1]}
            );

            my $text = $self->_template_text('mono2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    }
}

sub _linelengths
{
    # The person(s) who wrote the longest lines
    my $self = shift;

    my %len;

    foreach my $nick (sort keys %{ $self->{stats}->{lengths} }) {
        if ($self->{topactive}{$nick} || !$self->{cfg}->{showonlytop}) {
          if ($self->{stats}->{lines}{$nick} > 100) {
              $len{$nick} = $self->{stats}->{lengths}{$nick} / $self->{stats}->{lines}{$nick};
              $len{$nick} =~ s/(\.\d)\d+/$1/;
          }
        }
    }

    my @len = sort { $len{$b} <=> $len{$a} } keys %len;

    my $all_lines = 0;
    my $totallength;
    foreach my $nick (keys %{ $self->{stats}->{lines} }) {
        $all_lines   += $self->{stats}->{lines}{$nick};
        $totallength += $self->{stats}->{lengths}{$nick};
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

        my $text = $self->_template_text('long1', %hash);
        _html("<tr><td class=\"hicell\">$text<br />");

        if (@len >= 2) {
            %hash = (
                avg => $totalaverage
            );

            $text = $self->_template_text('long2', %hash);
            _html("<span class=\"small\">$text</span></td></tr>");
        } else {
            _html("</td></tr>");
        }
    }

    # The person(s) who wrote the shortest lines

    if (@len) {
        my %hash = (
            nick => $len[$#len],
            letters => $len{$len[$#len]}
        );

        my $text = $self->_template_text('short1', %hash);
        _html("<tr><td class=\"hicell\">$text<br />");

        if (@len >= 2) {
            %hash = (
                nick => $len[$#len - 1],
                letters => $len{$len[$#len - 1]}
            );

            $text = $self->_template_text('short2', %hash);
            _html("<span class=\"small\">$text</span></td></tr>");
        } else {
            _html("</td></tr>");
        }
    }
}

sub _mostfoul
{
    my $self = shift;

    my %spercent;

    foreach my $nick (sort keys %{ $self->{stats}->{foul} }) {
        if ($self->{topactive}{$nick} || !$self->{cfg}->{showonlytop}) {
          if ($self->{stats}->{lines}{$nick} > 15) {
              $spercent{$nick} = $self->{stats}->{foul}{$nick} / $self->{stats}->{words}{$nick} * 100;
              $spercent{$nick} =~ s/(\.\d)\d+/$1/;
          }
        }
    }

    my @foul = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;

    if (@foul) {

        my %hash = (
            nick => $foul[0],
            per  => $spercent{$foul[0]},
            line => $self->_format_line($self->{stats}{foullines}{$foul[0]}),
        );

        my $text = $self->_template_text('foul1', %hash);

        if($self->{cfg}->{showfoulline}) {
            my $exttext = $self->_template_text('foultext', %hash);
            _html("<tr><td class=\"hicell\">$text<br /><span class=\"small\">$exttext</span>");
        } else {
            _html("<tr><td class=\"hicell\">$text");
        }

        if (@foul >= 2) {
            my %hash = (
                nick => $foul[1],
                per  => $spercent{$foul[1]}
            );

            my $text = $self->_template_text('foul2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }

        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('foul3');

        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }
}


sub _mostsad
{
    my $self = shift;

    my %spercent;

    foreach my $nick (sort keys %{ $self->{stats}->{frowns} }) {
        if ($self->{topactive}{$nick} || !$self->{cfg}->{showonlytop}) {
          if ($self->{stats}->{lines}{$nick} > 100) {
              $spercent{$nick} = $self->{stats}->{frowns}{$nick} / $self->{stats}->{lines}{$nick} * 100;
              $spercent{$nick} =~ s/(\.\d)\d+/$1/;
          }
        }
    }

    my @sadface = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@sadface) {
        my %hash = (
            nick => $sadface[0],
            per  => $spercent{$sadface[0]}
        );

        my $text = $self->_template_text('sad1', %hash);
        _html("<tr><td class=\"hicell\">$text");

        if (@sadface >= 2) {
            my %hash = (
                nick => $sadface[1],
                per  => $spercent{$sadface[1]}
            );

            my $text = $self->_template_text('sad2', %hash);

            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('sad3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }
}


sub _mostop
{
    my $self = shift;

    my @ops   = sort { $self->{stats}->{gaveops}{$b} <=> $self->{stats}->{gaveops}{$a} }
                     keys %{ $self->{stats}->{gaveops} };

    @ops = $self->_istoponly(@ops);

    my @deops = sort { $self->{stats}->{tookops}{$b} <=> $self->{stats}->{tookops}{$a} }
                     keys %{ $self->{stats}->{tookops} };

    @deops = $self->_istoponly(@deops);

    if (@ops) {
        my %hash = (
            nick => $ops[0],
            ops  => $self->{stats}->{gaveops}{$ops[0]}
        );

        my $text = $self->_template_text('mostop1', %hash);

        _html("<tr><td class=\"hicell\">$text");

        if (@ops >= 2) {
            my %hash = (
                nick => $ops[1],
                ops  => $self->{stats}->{gaveops}{$ops[1]}
            );

            my $text = $self->_template_text('mostop2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('mostop3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }

    if (@deops) {
        my %hash = (
            nick  => $deops[0],
            deops => $self->{stats}->{tookops}{$deops[0]}
        );
        my $text = $self->_template_text('mostdeop1', %hash);

        _html("<tr><td class=\"hicell\">$text");

        if (@deops >= 2) {
            my %hash = (
                nick  => $deops[1],
                deops => $self->{stats}->{tookops}{$deops[1]}
            );
            my $text = $self->_template_text('mostdeop2', %hash);

            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('mostdeop3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }
}

sub _mostvoice
{
    my $self = shift;

    my @voice   = sort { $self->{stats}->{gavevoice}{$b} <=> $self->{stats}->{gavevoice}{$a} }
                     keys %{ $self->{stats}->{gavevoice} };

    @voice = $self->_istoponly(@voice);

    my @devoice = sort { $self->{stats}->{tookvoice}{$b} <=> $self->{stats}->{tookvoice}{$a} }
                     keys %{ $self->{stats}->{tookvoice} };

    @devoice = $self->_istoponly(@devoice);

    if (@voice) {
        my %hash = (
            nick => $voice[0],
            voices  => $self->{stats}->{gavevoice}{$voice[0]}
        );

        my $text = $self->_template_text('mostvoice1', %hash);

        _html("<tr><td class=\"hicell\">$text");

        if (@voice >= 2) {
            my %hash = (
                nick => $voice[1],
                voices  => $self->{stats}->{gavevoice}{$voice[1]}
            );

            my $text = $self->_template_text('mostvoice2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('mostvoice3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }

    if (@devoice) {
        my %hash = (
            nick  => $devoice[0],
            devoices => $self->{stats}->{tookvoice}{$devoice[0]}
        );
        my $text = $self->_template_text('mostdevoice1', %hash);

        _html("<tr><td class=\"hicell\">$text");

        if (@devoice >= 2) {
            my %hash = (
                nick  => $devoice[1],
                devoices => $self->{stats}->{tookvoice}{$devoice[1]}
            );
            my $text = $self->_template_text('mostdevoice2', %hash);

            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('mostdevoice3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }

}

sub _mosthalfop
{
    my $self = shift;

    my @halfops   = sort { $self->{stats}->{gavehalfops}{$b} <=> $self->{stats}->{gavehalfops}{$a} }
                     keys %{ $self->{stats}->{gavehalfops} };

    @halfops = $self->_istoponly(@halfops);

    my @dehalfops = sort { $self->{stats}->{tookhalfops}{$b} <=> $self->{stats}->{tookhalfops}{$a} }
                     keys %{ $self->{stats}->{tookhalfops} };

    @dehalfops = $self->_istoponly(@dehalfops);

    if (@halfops) {
        my %hash = (
            nick => $halfops[0],
            halfops  => $self->{stats}->{gavehalfops}{$halfops[0]}
        );

        my $text = $self->_template_text('mosthalfop1', %hash);

        _html("<tr><td class=\"hicell\">$text");

        if (@halfops >= 2) {
            my %hash = (
                nick => $halfops[1],
                halfops  => $self->{stats}->{gavehalfops}{$halfops[1]}
            );

            my $text = $self->_template_text('mosthalfop2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('mosthalfop3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }

    if (@dehalfops) {
        my %hash = (
            nick  => $dehalfops[0],
            dehalfops => $self->{stats}->{tookhalfops}{$dehalfops[0]}
        );
        my $text = $self->_template_text('mostdehalfop1', %hash);

        _html("<tr><td class=\"hicell\">$text");

        if (@dehalfops >= 2) {
            my %hash = (
                nick  => $dehalfops[1],
                dehalfops => $self->{stats}->{tookhalfops}{$dehalfops[1]}
            );
            my $text = $self->_template_text('mostdehalfop2', %hash);

            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('mostdehalfop3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }
}

sub _mostactions
{
    # The person who did the most /me's
    my $self = shift;

    my @actions = sort { $self->{stats}->{actions}{$b} <=> $self->{stats}->{actions}{$a} }
                        keys %{ $self->{stats}->{actions} };

    @actions = $self->_istoponly(@actions);

    if (@actions) {
        my %linehash =
        my %hash = (
            nick    => $actions[0],
            actions => $self->{stats}->{actions}{$actions[0]},
            line    => $self->_format_line($self->{stats}->{actionlines}{$actions[0]})
        );
        my $text = $self->_template_text('action1', %hash);
        if($self->{cfg}->{showactionline}) {
            my $exttext = $self->_template_text('actiontext', %hash);
            _html("<tr><td class=\"hicell\">$text<br /><span class=\"small\">$exttext</span>");
        } else {
            _html("<tr><td class=\"hicell\">$text");
        }

        if (@actions >= 2) {
            my %hash = (
                nick    => $actions[1],
                actions => $self->{stats}->{actions}{$actions[1]}
            );

            my $text = $self->_template_text('action2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('action3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }
}


sub _mostsmiles
{
    # The person(s) who smiled the most :-)
    my $self = shift;

    my %spercent;

    foreach my $nick (sort keys %{ $self->{stats}->{smiles} }) {
        if ($self->{topactive}{$nick} || !$self->{cfg}->{showonlytop}) {
          if ($self->{stats}->{lines}{$nick} > 100) {
              $spercent{$nick} = $self->{stats}->{smiles}{$nick} / $self->{stats}->{lines}{$nick} * 100;
              $spercent{$nick} =~ s/(\.\d)\d+/$1/;
          }
        }
    }

    my @smiles = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@smiles) {
        my %hash = (
            nick => $smiles[0],
            per  => $spercent{$smiles[0]}
        );

        my $text = $self->_template_text('smiles1', %hash);

        _html("<tr><td class=\"hicell\">$text");
        if (@smiles >= 2) {
            my %hash = (
                nick => $smiles[1],
                per  => $spercent{$smiles[1]}
            );

            my $text = $self->_template_text('smiles2', %hash);
            _html("<br /><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");

    } else {

        my $text = $self->_template_text('smiles3');
        _html("<tr><td class=\"hicell\">$text</td></tr>");
    }
}

sub _lasttopics
{
    my $self = shift;

    if ($self->{stats}->{topics}) {

        my %topic_seen;

        my %hash = (
            total => scalar @{ $self->{stats}->{topics} }
        );

        my $ltopic = $#{ $self->{stats}->{topics} };
        my $tlimit = 0;

        $self->{cfg}->{topichistory} -= 1;

        if ($ltopic > $self->{cfg}->{topichistory}) {
            $tlimit = $ltopic - $self->{cfg}->{topichistory};
        }

        for (my $i = $ltopic; $i >= $tlimit; $i--) {
            my $topic = $self->{stats}->{topics}[$i]{topic};
            # This code makes sure that we don't see the same topic twice
            next if ($topic_seen{$topic});
            $topic_seen{$topic} = 1;

            # Strip off the quotes (')
            $topic =~ s/^\'(.*)\'$/$1/;

            my $nick = $self->{stats}->{topics}[$i]{nick};
            my $hour = $self->{stats}->{topics}[$i]{hour};
            my $min  = $self->{stats}->{topics}[$i]{min};

            $hash{nick} = $self->_format_word($nick);
            $hash{time} = "$hour:$min";
            _html('<tr><td class="hicell"><i>' . $self->_format_line($topic) . '</i></td>');
            _html('<td class="hicell"><b>' . $self->_template_text('bylinetopic', %hash) . '</b></td></tr>');
        }
        _html("<tr><td align=\"center\" colspan=\"2\" class=\"asmall\">" . $self->_template_text('totaltopic', %hash) . "</td></tr>");
    } else {
        _html("<tr><td class=\"hicell\">" . $self->_template_text('notopic') ."</td></tr>");
    }
}

sub _template_text
{
    # This function is for the homemade template system. It receives a name
    # of a template and a hash with the fields in the template to update to
    # its corresponding value
    my $self = shift;
    my $template = shift;
    my %hash = @_;

    my $text;

    unless ($text = $self->{tmps}->{lc($self->{cfg}->{lang})}{$template}) {
        # Fall back to English if the language template doesn't exist

        if ($text = $self->{tmps}->{en}{$template}) {
            print "Note: No translation in '$self->{cfg}->{lang}' for '$template' - falling back to English..\n"
                unless ($self->{cfg}->{silent});
        } else {
            die("No such template '$template' in language file.\n");
        }
    }
    if($self->{iconv}) {
        $text = $self->{iconv}->convert($text);
        die("Could not convert charset for template '$template'.\n") unless $text;
    }

    $hash{channel} = $self->{cfg}->{channel};

    foreach my $key (sort keys %hash) {
        $text =~ s/\[:$key\]/$hash{$key}/;
    }

    if ($text =~ /\[:[^:]*?:[^:]*?:[^:]*?:\]/o) {
        $text =~ s/\[:([^:]*?):([^:]*?):([^:]*?):\]/$self->_get_subst($1,$2,$3,\%hash)/geo;
    }
    if ($text =~ /\[:[^:]*?:[^:]*?:]/o) {
        $text =~ s/\[:([^:]*?):([^:]*?):]/$self->_get_subst($1,$2,undef,\%hash)/geo;
    }

    return $text;
}

sub _format_word
{
    # This function formats a word -- should ONLY be called on words used alone (EG: not whole line printed)
    my ($self, $word) = @_;

    $word = htmlentities($word, $self->{cfg}->{charset});
    $word = $self->_replace_links($word);
    return $word;
}

sub _format_line
{
    # This function formats a action/normal line to be more readable, and calls any other function
    # that should be executed on every line.
    my ($self, $line) = @_;
    my $hashref;
    if ($hashref = $self->{cfg}->{analyzer}->{parser}->normalline($line)) {
        $line = '<' . $hashref->{nick} . '> ' . $hashref->{saying};
    } elsif ($hashref = $self->{cfg}->{analyzer}->{parser}->actionline($line)) {
        $line = '* ' . $hashref->{nick} . ' ' . $hashref->{saying};
    } elsif ($hashref = $self->{cfg}->{analyzer}->{parser}->thirdline($line)) {
        if (defined($hashref->{kicker})) {
            $line = '*** ' . $hashref->{nick} . ' was kicked by ' . $hashref->{kicker};
            $line .= ' (' . $hashref->{kicktext} . ')' 
                if (defined($hashref->{kicktext}));
        } elsif (defined($hashref->{newtopic})) {
            $line = '*** ' . $hashref->{nick} . ' changes topic to \'' . $hashref->{newtopic} . '\'';
        } elsif (defined($hashref->{newmode})) {
            $line = '*** ' . $hashref->{nick} . ' sets mode ' . $hashref->{newmode};
            $line .= ' ' . $hashref->{modechanges}
                if (defined($hashref->{kicktext}));
        } elsif (defined($hashref->{newjoin})) {
            $line = '*** Joins: ' . $hashref->{nick};
        } elsif (defined($hashref->{newnick})) {
            $line = '*** ' . $hashref->{nick} . ' is now known as ' . $hashref->{newnick};
        } elsif (defined($hashref->{newtopic})) {
            $line = '*** ' . $hashref->{nick} . ' changes topic to: ' . $hashref->{newtopic};
        }
    }
    $line = htmlentities($line, $self->{cfg}->{charset});
    $line = $self->_replace_links($line);
    return $line;
}

sub _get_subst
{
    # This function looks at the user definition and see if there is sex
    # defined. If yes, return the appropriate value. If no, just return the
    # default he/she value.
    my $self = shift;
    my ($m,$f,$d,$hash) = @_;
    if ($hash->{nick} && $self->{users}->{sex}{$hash->{nick}}) {
        if ($self->{users}->{sex}{$hash->{nick}} eq 'm') {
            return $m;
        } elsif ($self->{users}->{sex}{$hash->{nick}} eq 'f') {
            return $f;
        }
    }
    return defined($d) ? $d : "$m/$f";
}

sub _mostusedword
{
    # Word usage statistics
    my $self = shift;

    my %usages;

    foreach my $word (keys %{ $self->{stats}->{wordcounts} }) {
        # Skip people's nicks.
        next if is_nick($word);
        next if (length($word) < $self->{cfg}->{wordlength});
        $usages{$word} = $self->{stats}->{wordcounts}{$word};
    }


    my @popular = sort { $usages{$b} <=> $usages{$a} } keys %usages;

    if (@popular) {
        $self->_headline($self->_template_text('mostwordstopic'));

        _html("<table border=\"0\" width=\"$self->{cfg}->{tablewidth}\"><tr>");
        _html("<td>&nbsp;</td><td class=\"tdtop\"><b>" . $self->_template_text('word') . "</b></td>");
        _html("<td class=\"tdtop\"><b>" . $self->_template_text('numberuses') . "</b></td>");
        _html("<td class=\"tdtop\"><b>" . $self->_template_text('lastused') . "</b></td></tr>");


        my $count = 0;
        for(my $i = 0; $count < $self->{cfg}->{wordhistory}; $i++) {
            last unless $i < $#popular;
            # Skip nicks.  It's far more efficient to do this here than when
            # @popular is created.
            next if is_ignored($popular[$i]);

            my $a = $count + 1;
            my $popular = $self->_format_word($popular[$i]);
            my $wordcount = $self->{stats}->{wordcounts}{$popular[$i]};
            my $lastused = $self->_format_word($self->{stats}->{wordnicks}{$popular[$i]});
            my $class;
            if ($a == 1) {
                $class = 'hirankc';
            } else {
                $class = 'rankc';
            }
            _html("<tr><td class=\"$class\">$a</td>");
            _html("<td class=\"hicell\">$popular</td>");
            _html("<td class=\"hicell\">$wordcount</td>");
            _html("<td class=\"hicell\">$lastused</td>");
            _html("</tr>");
            $count++;
        }

        _html("</table>");
    }
}

sub _mostwordsperline
{
    # The person who got the most words per line
    my $self = shift;

    my %wpl = ();
    my $numlines = 0;
    my ($avg, $numwords);
    foreach my $nick (keys %{ $self->{stats}->{words} }) {
        if ($self->{topactive}{$nick} || !$self->{cfg}->{showonlytop}) {
          $wpl{$nick} = sprintf("%.2f", $self->{stats}->{words}{$nick}/$self->{stats}->{lines}{$nick});
          $numlines += $self->{stats}->{lines}{$nick};
          $numwords += $self->{stats}->{words}{$nick};
        }
    }
    if ($numlines > 0) {
        $avg = sprintf("%.2f", $numwords/$numlines);
    }

    my @wpl = sort { $wpl{$b} <=> $wpl{$a} } keys %wpl;

    if (@wpl) {
        my %hash = (
            nick => $wpl[0],
            wpl  => $wpl{$wpl[0]}
        );

        my $text = $self->_template_text('wpl1', %hash);
        _html("<tr><td class=\"hicell\">$text");

        $hash{avg} = $avg;

        $text = $self->_template_text('wpl2', %hash);
        _html("<br /><span class=\"small\">$text</span>");
        _html("</td></tr>");
    }
}

sub _mostreferencednicks
{
    # List showing the most referenced nicks
    my $self = shift;

    my %usages;

    foreach my $word (sort keys %{ $self->{stats}->{wordcounts} }) {
        next if !exists $self->{stats}->{lines}{$word};
        next if is_ignored($word);
        $usages{$word} = $self->{stats}->{wordcounts}{$word};
    }

    my @popular = sort { $usages{$b} <=> $usages{$a} } keys %usages;

    if (@popular) {

        $self->_headline($self->_template_text('referencetopic'));

        _html("<table border=\"0\" width=\"$self->{cfg}->{tablewidth}\"><tr>");
        _html("<td>&nbsp;</td><td class=\"tdtop\"><b>" . $self->_template_text('nick') . "</b></td>");
        _html("<td class=\"tdtop\"><b>" . $self->_template_text('numberuses') . "</b></td>");
        _html("<td class=\"tdtop\"><b>" . $self->_template_text('lastused') . "</b></td></tr>");

        for(my $i = 0; $i < $self->{cfg}->{nickhistory}; $i++) {
            last unless $i <= $#popular;
            my $a = $i + 1;
            my $popular   = $popular[$i];
            my $wordcount = $self->{stats}->{wordcounts}{$popular[$i]};
            my $lastused  = $self->{stats}->{wordnicks}{$popular[$i]};

            my $class;
            if ($a == 1) {
                $class = 'hirankc';
            } else {
                $class = 'rankc';
            }
            _html("<tr><td class=\"$class\">$a</td>");
            _html("<td class=\"hicell\">$popular</td>");
            _html("<td class=\"hicell\">$wordcount</td>");
            _html("<td class=\"hicell\">$lastused</td>");
            _html("</tr>");
        }
        _html("</table>");
    }
}

sub _mosturls
{
    # List showing the most referenced URLs
    my $self = shift;

    my @sorturls = sort { $self->{stats}->{urlcounts}{$b} <=> $self->{stats}->{urlcounts}{$a} }
                        keys %{ $self->{stats}->{urlcounts} };

    if (@sorturls) {

        $self->_headline($self->_template_text('urlstopic'));

        _html("<table border=\"0\" width=\"$self->{cfg}->{tablewidth}\"><tr>");
        _html("<td>&nbsp;</td><td class=\"tdtop\"><b>" . $self->_template_text('url') . "</b></td>");
        _html("<td class=\"tdtop\"><b>" . $self->_template_text('numberuses') . "</b></td>");
        _html("<td class=\"tdtop\"><b>" . $self->_template_text('lastused') . "</b></td></tr>");

        for(my $i = 0; $i < $self->{cfg}->{urlhistory}; $i++) {
            last unless $i < @sorturls;
            my $a = $i + 1;
            my $sorturl  = $sorturls[$i];
            my $urlcount = $self->{stats}->{urlcounts}{$sorturls[$i]};
            my $lastused = $self->{stats}->{urlnicks}{$sorturls[$i]};
            if (length($sorturl) > 60) {
                $sorturl = substr($sorturl, 0, 60);
            }
            my $class;
            if ($a == 1) {
                $class = 'hirankc';
            } else {
                $class = 'rankc';
            }
            _html("<tr><td class=\"$class\">$a</td>");
            _html("<td class=\"hicell\"><a href=\"$sorturls[$i]\">$sorturl</a></td>");
            _html("<td class=\"hicell\">$urlcount</td>");
            _html("<td class=\"hicell\">$lastused</td>");
            _html("</tr>");
        }
        _html("</table>");
    }
}

sub _legend
{
    # A legend showing the timebars and their associated time.
    my $self = shift;
    _html("<table align=\"center\" border=\"0\" width=\"520\"><tr>");
    _html("<td align=\"center\" class=\"asmall\"><img src=\"$self->{cfg}->{piclocation}/$self->{cfg}->{pic_h_0}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"0-5\" /> = 0-5</td>");
    _html("<td align=\"center\" class=\"asmall\"><img src=\"$self->{cfg}->{piclocation}/$self->{cfg}->{pic_h_6}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"6-11\" /> = 6-11</td>");
    _html("<td align=\"center\" class=\"asmall\"><img src=\"$self->{cfg}->{piclocation}/$self->{cfg}->{pic_h_12}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"12-17\" /> = 12-17</td>");
    _html("<td align=\"center\" class=\"asmall\"><img src=\"$self->{cfg}->{piclocation}/$self->{cfg}->{pic_h_18}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"18-23\" /> = 18-23</td>");
    _html("</tr></table>\n");
}


sub _replace_links
{
    # Sub to replace urls and e-mail addys to links
    my ($self, $str, $nick) = @_;

    # Regular expressions are taken from match_urls() and match_email() in
    # Common.pm

    my $texturl = $self->_template_text("newwindow");
    my $textmail = $self->_template_text("mailto");
    my (@str) = split(/ /,$str);

    foreach (@str) {
        if (m/(http|https|ftp|telnet|news)(:\/\/[-a-zA-Z0-9_\/~:@]+\.[-a-zA-Z0-9.,_~=:&amp;@%?#\/+]+)/o) {
            my $nick = $nick || $1 . $2;
            $_ = "<a href=\"$1$2\" target=\"_blank\" title=\"$texturl $1$2\">" . $self->_split_long_text($nick) . '</a>';
        } elsif (m/(^|[^:])\b([-a-zA-Z0-9._]+@[-a-zA-Z0-9_]+\.[-a-zA-Z0-9._]+)/o) {
            my $nick = $nick || $1 . $2;
            $_ = "$1<a href=\"mailto:$2\" title=\"$textmail $nick\">" . $self->_split_long_text($nick) . "<\/a>";
        } else {
            $_ = $self->_split_long_text($_);
        }
     }

    return join(' ', @str);
}

sub _split_long_text
{
    my ($self, $str) = @_;
    $str =~ s/(\S{$self->{cfg}->{quotewidth}})(?!\s)/$1-<br \/>/og;

    return($str);
}

sub _user_linetimes
{
    my $self = shift;
    my $nick  = shift;
    my $top   = shift;

    my $bar      = "";
    my $len      = ($self->{stats}->{lines}{$nick} / $self->{stats}->{lines}{$top}) * 100;

    for (my $i = 0; $i <= 3; $i++) {
        next if not defined $self->{stats}->{line_times}{$nick}[$i];
        my $w = int(($self->{stats}->{line_times}{$nick}[$i] / $self->{stats}->{lines}{$nick}) * $len);
        if ($w) {
            my $pic = 'pic_h_'.(6*$i);
            $bar .= "<img src=\"$self->{cfg}->{piclocation}/$self->{cfg}->{$pic}\" border=\"0\" width=\"$w\" height=\"15\" align=\"middle\" alt=\"$self->{stats}->{line_times}{$nick}[$i]\" />";
        }
    }
    return "$bar&nbsp;$self->{stats}->{lines}{$nick}";
}

sub _user_wordtimes
{
    my $self = shift;
    my $nick  = shift;
    my $top   = shift;

    my $bar      = "";
    my $len      = ($self->{stats}->{words}{$nick} / $self->{stats}->{words}{$top}) * 100;

    for (my $i = 0; $i <= 3; $i++) {
        next if not defined $self->{stats}->{word_times}{$nick}[$i];
        my $w = int(($self->{stats}->{word_times}{$nick}[$i] / $self->{stats}->{words}{$nick}) * $len);
        if ($w) {
            my $pic = 'pic_h_'.(6*$i);
            $bar .= "<img src=\"$self->{cfg}->{piclocation}/$self->{cfg}->{$pic}\" border=\"0\" width=\"$w\" height=\"15\" align=\"middle\" alt=\"\" />";
        }
    }
    return "$bar&nbsp;$self->{stats}->{words}{$nick}";
}

sub _user_times
{
    my $self = shift;
    my ($nick) = @_;

    my $bar = "";
    
    my $itemstat = ($self->{cfg}->{sortbywords} ? 'words' : 'lines');
    my $timestat = ($self->{cfg}->{sortbywords} ? 'word_times' : 'line_times');
    
    for (my $i = 0; $i <= 3; $i++) {
        next if not defined $self->{stats}->{$timestat}{$nick}[$i];
        my $w = int(($self->{stats}->{$timestat}{$nick}[$i] / $self->{stats}->{$itemstat}{$nick}) * 40);
        if ($w) {
            my $pic = 'pic_h_'.(6*$i);
            $bar .= "<img src=\"$self->{cfg}->{piclocation}/$self->{cfg}->{$pic}\" border=\"0\" width=\"$w\" height=\"15\" alt=\"\" />";
        }
    }
    return $bar;
}

sub _user_pic
{
    my $self = shift;
    my $nick  = shift;
    my $color  = shift;

    return unless $self->{users}->{userpics}{$nick} or $self->{cfg}->{defaultpic};

    my $rowspan = $self->{cfg}->{userpics} ? " rowspan=\"$self->{cfg}->{userpics}\"" : "";
    _html("<td style=\"background-color: $color\" align=\"center\" valign=\"middle\"$rowspan>");

    my $biguserpic = $self->{users}->{biguserpics}{$nick};
    $biguserpic = $self->{cfg}->{imagepath} . randomglob($biguserpic, $self->{cfg}->{imageglobpath})
        if $biguserpic and $biguserpic !~ /^http:\/\//i;
    $biguserpic = "<a href=\"$biguserpic\">" if $biguserpic;
    _html($biguserpic) if $biguserpic;

    my $pic = $self->{users}->{userpics}{$nick} || $self->{cfg}->{defaultpic};
    $pic = $self->{cfg}->{imagepath} . randomglob($pic, $self->{cfg}->{imageglobpath})
        unless $pic =~ /^http:\/\//i;
    my $height = $self->{cfg}->{picheight} ? " height=\"$self->{cfg}->{picheight}\"" : "";
    my $width = $self->{cfg}->{picwidth} ? " width=\"$self->{cfg}->{picwidth}\"" : "";
    my $alt = $self->{users}->{userpics}{$nick} ? " alt=\"$nick\"" : "";
    _html("<img src=\"$pic\"$width$height$alt />");

    _html("</a>") if $biguserpic;
    _html("</td>");
}

sub _mostnicks
{
    # List showing the user with most used nicks
    my $self = shift;

    my @sortnicks = sort { keys %{ $self->{stats}->{nicks}->{$b} } <=> keys %{ $self->{stats}->{nicks}->{$a} } } 
                                keys %{ $self->{stats}->{nicks} };

    if (keys %{ $self->{stats}->{nicks}->{$sortnicks[0]} } > 1) {

        $self->_headline($self->_template_text('mostnickstopic'));

        my $names1 = $self->_template_text('names1');
        my $names2 = $self->_template_text('names2');
        my $nick_txt = $self->_template_text('nick');
        my $names_txt = $self->_template_text('names');
        _html("<table border=\"0\" width=\"$self->{cfg}->{tablewidth}\"><tr>");
        _html("<td>&nbsp;</td><td class=\"tdtop\"><b>$nick_txt</b></td>");
        _html("<td class=\"tdtop\"><b>$names_txt</b></td></tr>");

        for(my $i = 0; $i < $self->{cfg}->{mostnickshistory}; $i++) {
            next if is_ignored($sortnicks[$i]);
            last unless $i < @sortnicks;
            my $nickcount = keys %{ $self->{stats}->{nicks}->{$sortnicks[$i]} };
            my $nickused = join(", ", values %{ $self->{stats}->{nicks}->{$sortnicks[$i]} });

            next unless ($nickcount > 1);

            my $a = $i + 1;
            my $class = $a == 1 ? 'hirankc' : 'rankc';
            my $n = $nickcount > 1 ? $names1 : $names2;

            _html("<tr><td class=\"$class\">$a</td>");
            if ($self->{cfg}->{mostnicksverbose}) { 
                _html("<td class=\"hicell\">$sortnicks[$i] ($nickcount $n)</td>");
                _html("<td class=\"hicell\" valign='top'>$nickused</td>");
            } else {
                _html("<td class=\"hicell\">$sortnicks[$i]</td>");
                _html("<td class=\"hicell\" valign='top'>$nickcount $n</td>");
            }
            _html("</tr>");
        }
        _html("</table>");
    }
}

sub _mostactivebyhour
{
    # Charts for most active nicks by hour (0-5, 6-11, 12-17, 18-23)
    my $self = shift;

    my $sortnicks;

    my $lastline=-1;
    my $maxlines=0;

    foreach my $period (0,1,2,3) {
        my @sortnicks =
        sort
        {
              (defined $self->{stats}->{line_times}{$b}[$period]?$self->{stats}->{line_times}{$b}[$period]:0)
              <=>
              (defined $self->{stats}->{line_times}{$a}[$period]?$self->{stats}->{line_times}{$a}[$period]:0)
        }
        keys %{ $self->{stats}->{line_times} } ;

        for(my $i = 0; $i < $self->{cfg}->{activenicksbyhour}; $i++) {
            next if ! $sortnicks[$i];
            next if is_ignored($sortnicks[$i]);
            last unless $i < @sortnicks;

            my $nick=$sortnicks[$i];
            my $count=$self->{stats}->{line_times}{$nick}[$period] || 0;

            last unless $nick;
            last unless $count;

            $sortnicks->[$period][$i]=$nick;

            if ($lastline<$i) {
              $lastline=$i;
            }


            if ($maxlines<$count) {
              $maxlines=$count;
            }
        }
    }

    if ($lastline>=0) {

        $self->_headline($self->_template_text('activenickbyhourtopic'));

        _html("<table border=\"0\" width=\"$self->{cfg}->{tablewidth}\"><tr>");
        _html("<td>&nbsp;</td>");
        _html("<td class=\"tdtop\"><b>0-5</b></td>");
        _html("<td class=\"tdtop\"><b>6-11</b></td>");
        _html("<td class=\"tdtop\"><b>12-17</b></td>");
        _html("<td class=\"tdtop\"><b>18-23</b></td>");
        _html("</tr>");

        for(my $i = 0; $i <= $lastline; $i++) {

            my $a = $i + 1;
            my $class = $a == 1 ? 'hirankc' : 'rankc';

            _html("<tr><td class=\"$class\">$a</td>");
            foreach my $period (0,1,2,3) {
                my $nick=$sortnicks->[$period][$i];
                if ($nick) {
                    my $count=$self->{stats}->{line_times}{$nick}[$period];
                    if ($count) {
                        _html("<td class=\"hicell\">");
                        if ($self->{cfg}->{showmostactivebyhourgraph}) {
                            my $pic = 'pic_h_'.(6*$period);
                            my $w = int(($count / $maxlines) * 100) || 1;
                            _html("<img src=\"$self->{cfg}->{piclocation}/$self->{cfg}->{$pic}\" border=\"0\" width=\"$w\" height=\"15\" align=\"middle\" alt=\"\" />");
                        }
                        _html($nick." - ".$count);
                        _html("</td>");
                    } else {
                        _html("<td class=\"hicell\">&nbsp;</td>");
                    }
                } else {
                  _html("<td class=\"hicell\">&nbsp;</td>");
                }
            }
            _html("</tr>");
        }
        _html("</table>");
    }
}

sub _topactive {
    my $self = shift;
    my @top_active;
    my $top_nicks;

    if ($self->{cfg}->{sortbywords}) {
        @top_active = sort { $self->{stats}->{words}{$b} <=> $self->{stats}->{words}{$a} } 
                             keys %{ $self->{stats}->{words} };
        $top_nicks = scalar keys %{ $self->{stats}->{words} };
    } else {
        @top_active = sort { $self->{stats}->{lines}{$b} <=> $self->{stats}->{lines}{$a} } 
                             keys %{ $self->{stats}->{lines} };
        $top_nicks = scalar keys %{ $self->{stats}->{lines} };
    }   
            
    if ($self->{cfg}->{activenicks} > $top_nicks) {
        $self->{cfg}->{activenicks} = $top_nicks;
    } 
    if (($self->{cfg}->{activenicks}+$self->{cfg}->{activenicks2}) > $top_nicks) {
        $self->{cfg}->{activenicks2} = $top_nicks-$self->{cfg}->{activenicks};
    }
            
    (@top_active) = @top_active[0..($self->{cfg}->{activenicks}+$self->{cfg}->{activenicks2}-1)];
            
    foreach (@top_active) {
        $self->{topactive}{$_} = 1;
    }
} 


sub _istoponly {
    my $self = shift;
    my (@nicks_tmp) = @_;
    my @nicks;
    my $cnt=0;

    if ($self->{cfg}->{showonlytop}) {
        foreach my $nick (@nicks_tmp) {
            if ($self->{topactive}{$nick}) {
                push(@nicks, $nick);
            }
        }
        return(@nicks);
    } else {
        return(@nicks_tmp);
    }
}

1;

__END__

=head1 NAME

Pisg::HTMLGenerator - class to create a static HTML page out of data parsed

=head1 DESCRIPTION

C<Pisg::HTMLGenerator> uses the hash returned by Pisg::Parser::Logfile and turns it into a static HTML page.

=head1 SYNOPSIS

    use Pisg::HTMLGenerator;

    $generator = new Pisg::HTMLGenerator(
        cfg => $cfg,
        stats => $stats,
        users => $users,
        tmps => $tmps
    );

=head1 CONSTRUCTOR

=over 4

=item new ( [ OPTIONS ] )

This is the constructor for a new Pisg::HTMLGenerator object. C<OPTIONS> are passed in a hash like fashion using key and value pairs.

Possible options are:

B<cfg> - hashref containing configuration variables, created by the Pisg module.

B<stats> - reference to the hash returned by Pisg::Parser::Logfile containing all stats.

B<users> - reference to a hash containg user information

B<tmps> - reference to a hash containing the language templates.

=back

=head1 AUTHOR

Morten Brix Pedersen <morten@wtf.dk>

=head1 COPYRIGHT

Copyright (C) 2001-2002 Morten Brix Pedersen. All rights reserved.
This program is free software; you can redistribute it and/or modify it
under the terms of the GPL, license is included with the distribution of
this file.

=cut
