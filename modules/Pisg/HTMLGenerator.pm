package Pisg::HTMLGenerator;

# Copyright and license, as well as documentation(POD) for this module is
# found at the end of the file.

use strict;
$^W = 1;

sub new
{
    my $type = shift;
    my %args = @_;
    my $self = {
        cfg => $args{cfg},
        debug => $args{debug},
        stats => $args{stats},
        users => $args{users},
        tmps => $args{tmps}
    };

    # Import common functions in Pisg::Common
    require Pisg::Common;
    Pisg::Common->import();

    bless($self, $type);
    return $self;
}

sub create_html
{
    # This subroutine calls all the subroutines which create their
    # individual stats. The name of the functions is somewhat saying - if
    # you don't understand it, most subs have a better explanation in the
    # sub itself.

    my $self = shift;

    print "Now generating HTML($self->{cfg}->{outputfile})...\n"
        unless ($self->{cfg}->{silent});

    open (OUTPUT, "> $self->{cfg}->{outputfile}") or
        die("$0: Unable to open outputfile($self->{cfg}->{outputfile}): $!\n");

    if ($self->{cfg}->{show_time}) {
        $self->{cfg}->{tablewidth} += 40;
    }
    if ($self->{cfg}->{show_words}) {
        $self->{cfg}->{tablewidth} += 40;
    }
    if ($self->{cfg}->{show_wpl}) {
        $self->{cfg}->{tablewidth} += 40;
    }
    if ($self->{cfg}->{show_cpl}) {
        $self->{cfg}->{tablewidth} += 40;
    }
    $self->{cfg}->{headwidth} = $self->{cfg}->{tablewidth} - 4;
    $self->_htmlheader();
    $self->_pageheader();
    if ($self->{cfg}->{show_activetimes}) {
        $self->_activetimes();
    }
    $self->_activenicks();

    if ($self->{cfg}->{show_bignumbers}) {
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

    if ($self->{cfg}->{show_muw}) {
        $self->_mostusedword();
    }

    if ($self->{cfg}->{show_mrn}) {
        $self->_mostreferencednicks();
    }

    if ($self->{cfg}->{show_mru}) {
        $self->_mosturls();
    }

    if ($self->{cfg}->{show_bignumbers}) {
        $self->_headline($self->_template_text('othernumtopic'));
        _html("<table width=\"$self->{cfg}->{tablewidth}\">\n"); # Needed for sections
        $self->_gotkicks();
        $self->_mostkicks();
        $self->_mostop();
        $self->_mostvoice() if $self->{cfg}->{show_voice};
        $self->_mostactions();
        $self->_mostmonologues();
        $self->_mostjoins();
        $self->_mostfoul();
        _html("</table>"); # Needed for sections
    }

    $self->_headline($self->_template_text('latesttopic'));
    _html("<table width=\"$self->{cfg}->{tablewidth}\">\n"); # Needed for sections
    $self->_lasttopics();
    _html("</table>"); # Needed for sections

    my %hash = ( lines => $self->{stats}->{totallines} );
    _html($self->_template_text('totallines', %hash) . "<br><br>");

    $self->_htmlfooter();

    close(OUTPUT);
}

sub _htmlheader
{
    my $self = shift;
    my $bgpic = "";
    my %hash = (
        network    => $self->{cfg}->{network},
        maintainer => $self->{cfg}->{maintainer},
        days       => $self->{stats}->{days},
        nicks      => scalar keys %{ $self->{stats}->{lines} }
    );
    my $title = $self->_template_text('pagetitle1', %hash);
    if ($self->{cfg}->{bgpic}) {
        $bgpic = " background=\"$self->{cfg}->{bgpic}\"";
    }
    print OUTPUT <<HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=$self->{cfg}->{charset}">
<title>$title</title>
<style type="text/css">
a { text-decoration: none }
a:link { color: $self->{cfg}->{link}; }
a:visited { color: $self->{cfg}->{vlink}; }
a:hover { text-decoration: underline; color: $self->{cfg}->{hlink} }

/* Colors for links not in td's */
a.background { text-decoration: none }
a.background:link { color: $self->{cfg}->{bg_link}; }
a.background:visited { color: $self->{cfg}->{bg_vlink}; }
a.background:hover { text-decoration: underline; color: $self->{cfg}->{bg_hlink} }

body {
    background-color: $self->{cfg}->{bgcolor};
    font-family: verdana, arial, sans-serif;
    font-size: 13px;
    color: $self->{cfg}->{text};
}

td {
    font-family: verdana, arial, sans-serif;
    font-size: 13px;
    color: $self->{cfg}->{tdcolor};
}

.title {
    font-family: tahoma, arial, sans-serif;
    font-size: 16px;
    font-weight: bold;
}

.headline { color: $self->{cfg}->{hcolor}; }
.small { font-family: verdana, arial, sans-serif; font-size: 10px; }
.asmall {
      font-family: arial narrow, sans-serif;
      font-size: 10px;
      color: $self->{cfg}->{text};
}
</style></head>
<body$bgpic>
<div align="center">
HTML
    print OUTPUT "<span class=\"title\">$title</span><br>";
    print OUTPUT "<br>";
    print OUTPUT $self->_template_text('pagetitle2', %hash);

    sub timefix
    {
        my $self = shift;
        my ($timezone, $sec, $min, $hour, $mday, $mon, $year, $wday, $month, $day, $tday, $wdisplay, @month, @day, $timefixx, %hash);

        $month = $self->_template_text('month', %hash);
        $day = $self->_template_text('day', %hash);

        @month = split(" ", $month);
        @day = split(" ", $day);

        # Get the Date from the users computer
        $timezone = $self->{cfg}->{timeoffset} * 3600;
        ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time+$timezone);

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

        print OUTPUT "$day[$wday] $mday $month[$mon] $year - $hour:$min:$sec\n";
    }

    $self->timefix();

    print OUTPUT "<br>" . $self->_template_text('pagetitle3', %hash) . "<br><br>";

}

sub _htmlfooter
{
    my $self = shift;
    print OUTPUT <<HTML;
<span class="small">
Stats generated by <a href="http://pisg.sourceforge.net/" title="Go to the pisg homepage" class="background">pisg</a> $self->{cfg}->{version}<br>
pisg by <a href="http://www.wtf.dk/hp/" title="Go to the authors homepage" class="background">Morten Brix Pedersen</a> and others<br>
Stats generated in $self->{stats}->{processtime}
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
   <br>
   <table width="$self->{cfg}->{headwidth}" cellpadding="1" cellspacing="0" border="0">
    <tr>
     <td bgcolor="$self->{cfg}->{headline}">
      <table width="100%" cellpadding="2" cellspacing="0" border="0" align="center">
       <tr>
        <td bgcolor="$self->{cfg}->{hbgcolor}" class="text10">
         <div align="center" class="headline"><b>$title</b></div>
        </td>
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
    if ($self->{cfg}->{pagehead} ne 'none') {
        open(PAGEHEAD, $self->{cfg}->{pagehead}) or die("$0: Unable to open $self->{cfg}->{pagehead} for reading: $!\n");
        while (<PAGEHEAD>) {
            _html($_);
        }
    }
}

sub _activetimes
{
    # The most actives times on the channel
    my $self = shift;

    my (%output, $tbgcolor);

    $self->_headline($self->_template_text('activetimestopic'));

    my @toptime = sort { $self->{stats}->{times}{$b} <=> $self->{stats}->{times}{$a} } keys %{ $self->{stats}->{times} };

    my $highest_value = $self->{stats}->{times}{$toptime[0]};

    my @now = localtime($self->{cfg}->{timestamp});

    my $image;

    for my $hour (sort keys %{ $self->{stats}->{times} }) {
        $self->{debug}->("Time: $hour => ". $self->{stats}->{times}{$hour});

        my $size = ($self->{stats}->{times}{$hour} / $highest_value) * 100;
        my $percent = ($self->{stats}->{times}{$hour} / $self->{stats}->{totallines}) * 100;
        $percent =~ s/(\.\d)\d+/$1/;

        if ($size < 1 && $size != 0) {
            # Opera doesn't understand '0.xxxx' in the height="xx" attr,
            # so we simply round up to 1.0 here.

            $size = 1.0;
        }

        if ($self->{cfg}->{timeoffset} =~ /\+(\d+)/) {
            # We must plus some hours to the time
            $hour += $1;
            $hour = $hour % 24;
            if ($hour < 10) { $hour = "0" . $hour; }

        } elsif ($self->{cfg}->{timeoffset} =~ /-(\d+)/) {
            # We must remove some hours from the time
            $hour -= $1;
            $hour = $hour % 24;
            if ($hour < 10) { $hour = "0" . $hour; }
        }
        $image = "pic_v_".(int($hour/6)*6);
        $image = $self->{cfg}->{$image};
        $self->{debug}->("Image: $image");

        $output{$hour} = "<td align=\"center\" valign=\"bottom\" class=\"asmall\">$percent%<br><img src=\"$self->{cfg}->{pic_loc}/$image\" width=\"15\" height=\"$size\" alt=\"$percent\"></td>\n";
    }

    _html("<table border=\"0\" width=\"$self->{cfg}->{tablewidth}\"><tr>\n");

    for ($b = 0; $b < 24; $b++) {
        if ($b < 10) { $a = "0" . $b; } else { $a = $b; }

        if (!defined($output{$a}) || $output{$a} eq "") {
            _html("<td align=\"center\" valign=\"bottom\" class=\"asmall\">0%</td>");
        } else {
            _html($output{$a});
        }
    }

    _html("</tr><tr>");

    for ($b = 0; $b < 24; $b++) {
        if ($now[2] == $b) { $tbgcolor = $self->{cfg}->{hi_rankc}; } else { $tbgcolor = $self->{cfg}->{rankc}; }
        _html("<td bgcolor=\"$tbgcolor\" align=\"center\" class=\"small\">$b</td>");
}

    _html("</tr></table>");

    if($self->{cfg}->{show_legend} == 1) {
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
    . "<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('nick') . "</b></td>"
    . "<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('numberlines') . "</b></td>"
    . ($self->{cfg}->{show_time} ? "<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>".$self->_template_text('show_time')."</b></td>" : "")
    . ($self->{cfg}->{show_words} ? "<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>".$self->_template_text('show_words')."</b></td>" : "")
    . ($self->{cfg}->{show_wpl} ? "<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>".$self->_template_text('show_wpl')."</b></td>" : "")
    . ($self->{cfg}->{show_cpl} ? "<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>".$self->_template_text('show_cpl')."</b></td>" : "")
    . ($self->{cfg}->{show_lastseen} ? "<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>".$self->_template_text('show_lastseen')."</b></td>" : "")
    . ($self->{cfg}->{show_randquote} ? "<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>".$self->_template_text('randquote')."</b></td>" : "")
    );

    my @active = sort { $self->{stats}->{lines}{$b} <=> $self->{stats}->{lines}{$a} } keys %{ $self->{stats}->{lines} };
    my $nicks = scalar keys %{ $self->{stats}->{lines} };

    if ($self->{cfg}->{activenicks} > $nicks) { $self->{cfg}->{activenicks} = $nicks; }

    my $have_userpics;
    for (my $c = 0; $c < $self->{cfg}->{activenicks}; $c++) {
        my $nick = $active[$c];
        if ($self->{users}->{userpics}{$nick} && $self->{cfg}->{userpics} !~ /n/i) {
            $have_userpics = 1;
            _html("<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('userpic') ."</b></td>");
            last;
        }
    }
    _html("</tr>");

    my ($nick, $visiblenick, $randomline, %hash);
    my $i = 1;
    for (my $c = 0; $c < $self->{cfg}->{activenicks}; $c++) {
        $nick = $active[$c];
        $visiblenick = $active[$c];

        if (not defined $self->{stats}->{sayings}{$nick}) {
            $randomline = "";
        } else {
            $randomline = htmlentities($self->{stats}->{sayings}{$nick});
        }

        # Convert URLs and e-mail addys to links
        $randomline = _replace_links($randomline);

        # Add a link to the nick if there is any
        if ($self->{users}->{userlinks}{$nick}) {
            $visiblenick = _replace_links($self->{users}->{userlinks}{$nick}, $nick);
        }

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
        my $col_b  = sprintf "%0.2x", abs int(((($t_b - $f_b) / $self->{cfg}->{activenicks}) * +$c) + $f_b);
        my $col_g  = sprintf "%0.2x", abs int(((($t_g - $f_g) / $self->{cfg}->{activenicks}) * +$c) + $f_g);
        my $col_r  = sprintf "%0.2x", abs int(((($t_r - $f_r) / $self->{cfg}->{activenicks}) * +$c) + $f_r);

        my $bgcolor = $self->{cfg}->{rankc};
        if ($i == 1) {
            $bgcolor = $self->{cfg}->{hi_rankc};
        } 

        my $lastseen = $self->{stats}->{days} - $self->{stats}->{lastvisited}{$nick};
        if ($lastseen == 0) {
            $lastseen = $self->_template_text('today');
        } elsif ($lastseen == 1) {
            $lastseen = "$lastseen " .$self->_template_text('lastseen1');
        } else {
            $lastseen = "$lastseen " .$self->_template_text('lastseen2');
        }
        
            
        _html("<tr><td bgcolor=\"$bgcolor\" align=\"left\">");

        my $line = $self->{stats}->{lines}{$nick};
        my $w    = $self->{stats}->{words}{$nick};
        my $ch   = $self->{stats}->{lengths}{$nick};
        _html("$i</td><td bgcolor=\"#$col_r$col_g$col_b\">$visiblenick</td>"
        . ($self->{cfg}->{show_linetime} ?
        "<td bgcolor=\"$col_r$col_g$col_b\">".$self->_user_linetimes($nick,$active[0])."</td>"
        : "<td bgcolor=\"#$col_r$col_g$col_b\">$line</td>")
        . ($self->{cfg}->{show_time} ?
        "<td bgcolor=\"$col_r$col_g$col_b\">".$self->_user_times($nick)."</td>"
        : "")
        . ($self->{cfg}->{show_words} ?
        "<td bgcolor=\"#$col_r$col_g$col_b\">$w</td>"
        : "")
        . ($self->{cfg}->{show_wpl} ?
        "<td bgcolor=\"#$col_r$col_g$col_b\">".sprintf("%.1f",$w/$line)."</td>"
        : "")
        . ($self->{cfg}->{show_cpl} ?
        "<td bgcolor=\"#$col_r$col_g$col_b\">".sprintf("%.1f",$ch/$line)."</td>"
        : "")
        . ($self->{cfg}->{show_lastseen} ?
        "<td bgcolor=\"#$col_r$col_g$col_b\">$lastseen</td>"
        : "")
        . ($self->{cfg}->{show_randquote} ?
        "<td bgcolor=\"#$col_r$col_g$col_b\">\"$randomline\"</td>"
        : "")
        );

        my $height = $self->{cfg}->{pic_height};
        my $width = $self->{cfg}->{pic_width};
        if ($self->{users}->{userpics}{$nick} && $self->{cfg}->{userpics} !~ /n/i) {
            if ($width ne '') {
                _html("<td bgcolor=\"#$col_r$col_g$col_b\" align=\"center\"><img valign=\"middle\" src=\"$self->{cfg}->{imagepath}$self->{users}->{userpics}{$nick}\" width=\"$width\" height=\"$height\"></td>");
            } else {
                _html("<td bgcolor=\"#$col_r$col_g$col_b\" align=\"center\"><img valign=\"middle\" src=\"$self->{cfg}->{imagepath}$self->{users}->{userpics}{$nick}\"></td>");
            }
        } elsif ($self->{cfg}->{default_pic} ne '' && $self->{cfg}->{userpics} !~ /n/i)  {
            _html("<td bgcolor=\"#$col_r$col_g$col_b\" align=\"center\"><img valign=\"middle\" src=\"$self->{cfg}->{imagepath}$self->{cfg}->{default_pic}\"></td>");
        }

        _html("</tr>");
        $i++;
    }

    _html("</table><br>");

    # Almost as active nicks ('These didn't make it to the top..')

    my $toshow = $self->{cfg}->{activenicks2} - $self->{cfg}->{activenicks};
    my $remain = $self->{cfg}->{activenicks} + $toshow;

    unless ($toshow > $nicks) {
        $remain = $self->{cfg}->{activenicks} + $self->{cfg}->{activenicks2};
        if ($remain > $nicks) {
            $remain = $nicks;
        }

        if ($self->{cfg}->{activenicks} <  $remain) {
            _html("<br><b><i>" . $self->_template_text('nottop') . "</i></b><table><tr>");
            for (my $c = $self->{cfg}->{activenicks}; $c < $remain; $c++) {
                unless ($c % 5) { unless ($c == $self->{cfg}->{activenicks}) { _html("</tr><tr>"); } }
                _html("<td bgcolor=\"$self->{cfg}->{rankc}\" class=\"small\">");
                my $nick = $active[$c];
                my $lines = $self->{stats}->{lines}{$nick};
                _html("$nick ($lines)</td>");
            }

            _html("</table>");
        }
    }

    $hash{totalnicks} = $nicks - $remain;
    if ($hash{totalnicks} > 0) {
        _html("<br><b>" . $self->_template_text('totalnicks', %hash) . "</b><br>");
    }
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
        if ($self->{stats}->{lines}{$nick} > 100) {
            $qpercent{$nick} = ($self->{stats}->{questions}{$nick} / $self->{stats}->{lines}{$nick}) * 100;
            $qpercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @question = sort { $qpercent{$b} <=> $qpercent{$a} } keys %qpercent;

    if (@question) {
        my %hash = (
            nick => $question[0],
            per  => $qpercent{$question[0]}
        );

        my $text = $self->_template_text('question1', %hash);
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
        if (@question >= 2) {
            my %hash = (
                nick => $question[1],
                per => $qpercent{$question[1]}
            );

            my $text = $self->_template_text('question2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");

    } else {
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">" . $self->_template_text('question3') . "</td></tr>");
    }
}

sub _shoutpeople
{
    # The ones who speak with exclamation marks!
    my $self = shift;

    my %spercent;

    foreach my $nick (sort keys %{ $self->{stats}->{shouts} }) {
        if ($self->{stats}->{lines}{$nick} > 100) {
            $spercent{$nick} = ($self->{stats}->{shouts}{$nick} / $self->{stats}->{lines}{$nick}) * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @shout = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;

    if (@shout) {
        my %hash = (
            nick => $shout[0],
            per  => $spercent{$shout[0]}
        );

        my $text = $self->_template_text('shout1', %hash);
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
        if (@shout >= 2) {
            my %hash = (
                nick => $shout[1],
                per  => $spercent{$shout[1]}
            );

            my $text = $self->_template_text('shout2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");

    } else {
        my $text = $self->_template_text('shout3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }

}

sub _capspeople
{
    # The ones who speak ALL CAPS.
    my $self = shift;

    my %cpercent;

    foreach my $nick (sort keys %{ $self->{stats}->{allcaps} }) {
        if ($self->{stats}->{lines}{$nick} > 100) {
            $cpercent{$nick} = $self->{stats}->{allcaps}{$nick} / $self->{stats}->{lines}{$nick} * 100;
            $cpercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @caps = sort { $cpercent{$b} <=> $cpercent{$a} } keys %cpercent;

    if (@caps) {
        my %hash = (
            nick => $caps[0],
            per  => $cpercent{$caps[0]},
            line => htmlentities($self->{stats}->{allcaplines}{$caps[0]})
        );

        my $text = $self->_template_text('allcaps1', %hash);
        if($self->{cfg}->{show_shoutline}) {
            my $exttext = $self->_template_text('allcapstext', %hash);
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
        }
        if (@caps >= 2) {
            my %hash = (
                nick => $caps[1],
                per  => $cpercent{$caps[1]}
            );

            my $text = $self->_template_text('allcaps2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");

    } else {
        my $text = $self->_template_text('allcaps3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }
}

sub _violent
{
    # They attacked others (words defined by $self->{cfg}->{violent})
    my $self = shift;

    my @aggressors;

    @aggressors = sort { $self->{stats}->{violence}{$b} <=> $self->{stats}->{violence}{$a} }
                         keys %{ $self->{stats}->{violence} };

    if(@aggressors) {
        my %hash = (
            nick    => $aggressors[0],
            attacks => $self->{stats}->{violence}{$aggressors[0]},
            line    => htmlentities($self->{stats}->{violencelines}{$aggressors[0]})
        );
        my $text = $self->_template_text('violent1', %hash);
        if($self->{cfg}->{show_violentlines}) {
            my $exttext = $self->_template_text('violenttext', %hash);
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
        }
        if (@aggressors >= 2) {
            my %hash = (
                nick    => $aggressors[1],
                attacks => $self->{stats}->{violence}{$aggressors[1]}
            );

            my $text = $self->_template_text('violent2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('violent3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }


    # They got attacked
    my @victims;
    @victims = sort { $self->{stats}->{attacked}{$b} <=> $self->{stats}->{attacked}{$a} }
		    keys %{ $self->{stats}->{attacked} };

    if(@victims) {
        my %hash = (
            nick    => $victims[0],
            attacks => $self->{stats}->{attacked}{$victims[0]},
            line    => htmlentities($self->{stats}->{attackedlines}{$victims[0]})
        );
        my $text = $self->_template_text('attacked1', %hash);
        if($self->{cfg}->{show_violentlines}) {
            my $exttext = $self->_template_text('attackedtext', %hash);
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
        }
        if (@victims >= 2) {
            my %hash = (
                nick    => $victims[1],
                attacks => $self->{stats}->{attacked}{$victims[1]}
            );

            my $text = $self->_template_text('attacked2', %hash);
            _html("<br><span class=\"small\">$text</span>");
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

    if (@gotkick) {
        my %hash = (
            nick  => $gotkick[0],
            kicks => $self->{stats}->{gotkicked}{$gotkick[0]},
            line  => $self->{stats}->{kicklines}{$gotkick[0]}
        );

        my $text = $self->_template_text('gotkick1', %hash);

        if ($self->{cfg}->{show_kickline}) {
            my $exttext = $self->_template_text('kicktext', %hash);
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
        }

        if (@gotkick >= 2) {
            my %hash = (
                nick  => $gotkick[1],
                kicks => $self->{stats}->{gotkicked}{$gotkick[1]}
            );

            my $text = $self->_template_text('gotkick2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    }
}

sub _mostjoins
{
    my $self = shift;

    my @joins = sort { $self->{stats}->{joins}{$b} <=> $self->{stats}->{joins}{$a} }
                     keys %{ $self->{stats}->{joins} };

    if (@joins) {
        my %hash = (
            nick  => $joins[0],
            joins => $self->{stats}->{joins}{$joins[0]}
        );

        my $text = $self->_template_text('joins', %hash);

        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }
}

sub _mostwords
{
    # The person who got words the most
    my $self = shift;

     my @words = sort { $self->{stats}->{words}{$b} <=> $self->{stats}->{words}{$a} }
                      keys %{ $self->{stats}->{words} };

    if (@words) {
        my %hash = (
            nick  => $words[0],
            words => $self->{stats}->{words}{$words[0]}
        );

        my $text = $self->_template_text('words1', %hash);
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");

        if (@words >= 2) {
            my %hash = (
                oldnick => $words[0],
                nick    => $words[1],
                words   => $self->{stats}->{words}{$words[1]}
            );

            my $text = $self->_template_text('words2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('kick3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }
}

sub _mostkicks
{
    # The person who kicked the most
    my $self = shift;

    my @kicked = sort { $self->{stats}->{kicked}{$b} <=> $self->{stats}->{kicked}{$a} }
                        keys %{ $self->{stats}->{kicked} };

    if (@kicked) {
        my %hash = (
            nick   => $kicked[0],
            kicked => $self->{stats}->{kicked}{$kicked[0]}
        );

        my $text = $self->_template_text('kick1', %hash);
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");

        if (@kicked >= 2) {
            my %hash = (
                oldnick => $kicked[0],
                nick    => $kicked[1],
                kicked  => $self->{stats}->{kicked}{$kicked[1]}
            );

            my $text = $self->_template_text('kick2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('kick3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }
}

sub _mostmonologues
{
    # The person who had the most monologues (speaking to himself)
    my $self = shift;

    my @monologue = sort { $self->{stats}->{monologues}{$b} <=> $self->{stats}->{monologues}{$a} } keys %{ $self->{stats}->{monologues} };

    if (@monologue) {
        my %hash = (
            nick  => $monologue[0],
            monos => $self->{stats}->{monologues}{$monologue[0]}
        );

        my $text = $self->_template_text('mono1', %hash);

        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
        if (@monologue >= 2) {
            my %hash = (
                nick  => $monologue[1],
                monos => $self->{stats}->{monologues}{$monologue[1]}
            );

            my $text = $self->_template_text('mono2', %hash);
            _html("<br><span class=\"small\">$text</span>");
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
        if ($self->{stats}->{lines}{$nick} > 100) {
            $len{$nick} = $self->{stats}->{lengths}{$nick} / $self->{stats}->{lines}{$nick};
            $len{$nick} =~ s/(\.\d)\d+/$1/;
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
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text<br>");

        if (@len >= 2) {
            %hash = (
                avg => $totalaverage
            );

            $text = $self->_template_text('long2', %hash);
            _html("<span class=\"small\">$text</span></td></tr>");
        }
    }

    # The person(s) who wrote the shortest lines

    if (@len) {
        my %hash = (
            nick => $len[$#len],
            letters => $len{$len[$#len]}
        );

        my $text = $self->_template_text('short1', %hash);
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text<br>");

        if (@len >= 2) {
            %hash = (
                nick => $len[$#len - 1],
                letters => $len{$len[$#len - 1]}
            );

            $text = $self->_template_text('short2', %hash);
            _html("<span class=\"small\">$text</span></td></tr>");
        }
    }
}

sub _mostfoul
{
    my $self = shift;

    my %spercent;

    foreach my $nick (sort keys %{ $self->{stats}->{foul} }) {
        if ($self->{stats}->{lines}{$nick} > 15) {
            $spercent{$nick} = $self->{stats}->{foul}{$nick} / $self->{stats}->{lines}{$nick} * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @foul = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@foul) {

        my %hash = (
            nick => $foul[0],
            per  => $spercent{$foul[0]}
        );

        my $text = $self->_template_text('foul1', %hash);

        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");

        if (@foul >= 2) {
            my %hash = (
                nick => $foul[1],
                per  => $spercent{$foul[1]}
            );

            my $text = $self->_template_text('foul2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }

        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('foul3');

        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }
}


sub _mostsad
{
    my $self = shift;

    my %spercent;

    foreach my $nick (sort keys %{ $self->{stats}->{frowns} }) {
        if ($self->{stats}->{lines}{$nick} > 100) {
            $spercent{$nick} = $self->{stats}->{frowns}{$nick} / $self->{stats}->{lines}{$nick} * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @sadface = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@sadface) {
        my %hash = (
            nick => $sadface[0],
            per  => $spercent{$sadface[0]}
        );

        my $text = $self->_template_text('sad1', %hash);
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");

        if (@sadface >= 2) {
            my %hash = (
                nick => $sadface[1],
                per  => $spercent{$sadface[1]}
            );

            my $text = $self->_template_text('sad2', %hash);

            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('sad3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }
}


sub _mostop
{
    my $self = shift;

    my @ops   = sort { $self->{stats}->{gaveops}{$b} <=> $self->{stats}->{gaveops}{$a} }
                     keys %{ $self->{stats}->{gaveops} };
    my @deops = sort { $self->{stats}->{tookops}{$b} <=> $self->{stats}->{tookops}{$a} }
                     keys %{ $self->{stats}->{tookops} };

    if (@ops) {
        my %hash = (
            nick => $ops[0],
            ops  => $self->{stats}->{gaveops}{$ops[0]}
        );

        my $text = $self->_template_text('mostop1', %hash);

        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");

        if (@ops >= 2) {
            my %hash = (
                nick => $ops[1],
                ops  => $self->{stats}->{gaveops}{$ops[1]}
            );

            my $text = $self->_template_text('mostop2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('mostop3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }

    if (@deops) {
        my %hash = (
            nick  => $deops[0],
            deops => $self->{stats}->{tookops}{$deops[0]}
        );
        my $text = $self->_template_text('mostdeop1', %hash);

        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");

        if (@deops >= 2) {
            my %hash = (
                nick  => $deops[1],
                deops => $self->{stats}->{tookops}{$deops[1]}
            );
            my $text = $self->_template_text('mostdeop2', %hash);

            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('mostdeop3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
    }
}

sub _mostvoice
{
    my $self = shift;

    my @voice   = sort { $self->{stats}->{gavevoice}{$b} <=> $self->{stats}->{gavevoice}{$a} }
                     keys %{ $self->{stats}->{gavevoice} };
    my @devoice = sort { $self->{stats}->{tookvoice}{$b} <=> $self->{stats}->{tookvoice}{$a} }
                     keys %{ $self->{stats}->{tookvoice} };

    if (@voice) {
        my %hash = (
            nick => $voice[0],
            voices  => $self->{stats}->{gavevoice}{$voice[0]}
        );

        my $text = $self->_template_text('mostvoice1', %hash);

        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");

        if (@voice >= 2) {
            my %hash = (
                nick => $voice[1],
                voices  => $self->{stats}->{gavevoice}{$voice[1]}
            );

            my $text = $self->_template_text('mostvoice2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('mostvoice3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }

    if (@devoice) {
        my %hash = (
            nick  => $devoice[0],
            devoices => $self->{stats}->{tookvoice}{$devoice[0]}
        );
        my $text = $self->_template_text('mostdevoice1', %hash);

        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");

        if (@devoice >= 2) {
            my %hash = (
                nick  => $devoice[1],
                devoices => $self->{stats}->{tookvoice}{$devoice[1]}
            );
            my $text = $self->_template_text('mostdevoice2', %hash);

            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('mostdevoice3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
    }

}

sub _mostactions
{
    # The person who did the most /me's
    my $self = shift;

    my @actions = sort { $self->{stats}->{actions}{$b} <=> $self->{stats}->{actions}{$a} }
                        keys %{ $self->{stats}->{actions} };

    if (@actions) {
        my %hash = (
            nick    => $actions[0],
            actions => $self->{stats}->{actions}{$actions[0]},
            line    => htmlentities($self->{stats}->{actionlines}{$actions[0]})
        );
        my $text = $self->_template_text('action1', %hash);
        if($self->{cfg}->{show_actionline}) {
            my $exttext = $self->_template_text('actiontext', %hash);
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text<br><span class=\"small\">$exttext</span><br>");
        } else {
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
        }

        if (@actions >= 2) {
            my %hash = (
                nick    => $actions[1],
                actions => $self->{stats}->{actions}{$actions[1]}
            );

            my $text = $self->_template_text('action2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");
    } else {
        my $text = $self->_template_text('action3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }
}


sub _mostsmiles
{
    # The person(s) who smiled the most :-)
    my $self = shift;

    my %spercent;

    foreach my $nick (sort keys %{ $self->{stats}->{smiles} }) {
        if ($self->{stats}->{lines}{$nick} > 100) {
            $spercent{$nick} = $self->{stats}->{smiles}{$nick} / $self->{stats}->{lines}{$nick} * 100;
            $spercent{$nick} =~ s/(\.\d)\d+/$1/;
        }
    }

    my @smiles = sort { $spercent{$b} <=> $spercent{$a} } keys %spercent;


    if (@smiles) {
        my %hash = (
            nick => $smiles[0],
            per  => $spercent{$smiles[0]}
        );

        my $text = $self->_template_text('smiles1', %hash);

        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");
        if (@smiles >= 2) {
            my %hash = (
                nick => $smiles[1],
                per  => $spercent{$smiles[1]}
            );

            my $text = $self->_template_text('smiles2', %hash);
            _html("<br><span class=\"small\">$text</span>");
        }
        _html("</td></tr>");

    } else {

        my $text = $self->_template_text('smiles3');
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text</td></tr>");
    }
}

sub _lasttopics
{
    my $self = shift;

    if ($self->{stats}->{topics}) {
        $self->{debug}->("Total number of topics: " . scalar @{ $self->{stats}->{topics} });

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
            my $topic = htmlentities($self->{stats}->{topics}[$i]{topic});
            $topic = _replace_links($topic);
            # Strip off the quotes (')
            $topic =~ s/^\'(.*)\'$/$1/;

            my $nick = $self->{stats}->{topics}[$i]{nick};
            my $hour = $self->{stats}->{topics}[$i]{hour};
            my $min  = $self->{stats}->{topics}[$i]{min};

            $hash{nick} = $nick;
            $hash{time} = "$hour:$min";
            _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\"><i>$topic</i></td>");
            _html("<td bgcolor=\"$self->{cfg}->{hicell}\"><b>" . $self->_template_text('bylinetopic', %hash) ."</b></td></tr>");
        }
        _html("<tr><td align=\"center\" colspan=\"2\" class=\"asmall\">" . $self->_template_text('totaltopic', %hash) . "</td></tr>");
    } else {
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">" . $self->_template_text('notopic') ."</td></tr>");
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

    unless ($text = $self->{tmps}->{$self->{cfg}->{lang}}{$template}) {
        # Fall back to English if the language template doesn't exist

        if ($text = $self->{tmps}->{EN}{$template}) {
            print "Note: No translation in '$self->{cfg}->{lang}' for '$template' - falling back to English..\n"
                unless ($self->{cfg}->{silent});
        } else {
            die("No such template '$template' in language file.\n");
        }

    }

    $hash{channel} = $self->{cfg}->{channel};

    foreach my $key (sort keys %hash) {
        $text =~ s/\[:$key\]/$hash{$key}/;
        $text =~ s/ü/&uuml;/go;
        $text =~ s/ö/&ouml;/go;
        $text =~ s/ä/&auml;/go;
        $text =~ s/ß/&szlig;/go;
        $text =~ s/å/&aring;/go;
        $text =~ s/æ/&aelig;/go;
        $text =~ s/ø/&oslash;/go;
        $text =~ s/Å/&Aring;/go;
        $text =~ s/Æ/&AElig;/go;
        $text =~ s/Ø/&Oslash;/go;
    }

    if ($text =~ /\[:.*?:.*?:\]/o) {
        $text =~ s/\[:(.*?):(.*?):\]/$self->_get_subst($1,$2,\%hash)/geo;
    }
    return $text;
}

sub _get_subst
{
    # This function looks at the user definition and see if there is sex
    # defined. If yes, return the appropriate value. If no, just return the
    # default he/she value.
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

sub _mostusedword
{
    # Word usage statistics
    my $self = shift;

    my %usages;

    foreach my $word (keys %{ $self->{stats}->{wordcounts} }) {
        # Skip people's nicks.
        next if exists $self->{stats}->{lines}{$word};
        next if (length($word) < $self->{cfg}->{wordlength});
        $usages{$word} = $self->{stats}->{wordcounts}{$word};
    }


    my @popular = sort { $usages{$b} <=> $usages{$a} } keys %usages;

    if (@popular) {
        $self->_headline($self->_template_text('mostwordstopic'));

        _html("<table border=\"0\" width=\"$self->{cfg}->{tablewidth}\"><tr>");
        _html("<td>&nbsp;</td><td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('word') . "</b></td>");
        _html("<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('numberuses') . "</b></td>");
        _html("<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('lastused') . "</b></td>");


        my $count = 0;
        for(my $i = 0; $count < 10; $i++) {
            last unless $i < $#popular;
            # Skip nicks.  It's far more efficient to do this here than when
            # @popular is created.
            next if is_ignored($popular[$i]);
            next if exists $self->{stats}->{lines}{find_alias($popular[$i])};
            my $a = $count + 1;
            my $popular = htmlentities($popular[$i]);
            my $wordcount = $self->{stats}->{wordcounts}{$popular[$i]};
            my $lastused = htmlentities($self->{stats}->{wordnicks}{$popular[$i]});
            my $bgcolor;
            if ($a == 1) {
                $bgcolor = $self->{cfg}->{hi_rankc};
            } else {
                $bgcolor = $self->{cfg}->{rankc};
            }
            _html("<tr><td bgcolor=\"$bgcolor\"><b>$a</b>");
            _html("<td bgcolor=\"$self->{cfg}->{hicell}\">$popular</td>");
            _html("<td bgcolor=\"$self->{cfg}->{hicell}\">$wordcount</td>");
            _html("<td bgcolor=\"$self->{cfg}->{hicell}\">$lastused</td>");
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
    foreach my $n (keys %{ $self->{stats}->{words} }) {
        $wpl{$n} = sprintf("%.2f", $self->{stats}->{words}{$n}/$self->{stats}->{lines}{$n});
        $numlines += $self->{stats}->{lines}{$n};
        $numwords += $self->{stats}->{words}{$n};
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
        _html("<tr><td bgcolor=\"$self->{cfg}->{hicell}\">$text");

        %hash = (
            avg => $avg
        );

        $text = $self->_template_text('wpl2', %hash);
        _html("<br><span class=\"small\">$text</span>");
        _html("</td></tr>");
    }
}

sub _mostreferencednicks
{
    # List showing the most referenced nicks
    my $self = shift;

    my %usages;

    foreach my $word (sort keys %{ $self->{stats}->{wordcounts} }) {
        next unless exists $self->{stats}->{lines}{$word};
        next if is_ignored($word);
        $usages{$word} = $self->{stats}->{wordcounts}{$word};
    }

    my @popular = sort { $usages{$b} <=> $usages{$a} } keys %usages;

    if (@popular) {

        $self->_headline($self->_template_text('referencetopic'));

        _html("<table border=\"0\" width=\"$self->{cfg}->{tablewidth}\"><tr>");
        _html("<td>&nbsp;</td><td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('nick') . "</b></td>");
        _html("<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('numberuses') . "</b></td>");
        _html("<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('lastused') . "</b></td>");

        for(my $i = 0; $i < 5; $i++) {
            last unless $i < $#popular;
            my $a = $i + 1;
            my $popular   = $popular[$i];
            my $wordcount = $self->{stats}->{wordcounts}{$popular[$i]};
            my $lastused  = $self->{stats}->{wordnicks}{$popular[$i]};

            my $bgcolor;
            if ($a == 1) {
                $bgcolor = $self->{cfg}->{hi_rankc};
            } else {
                $bgcolor = $self->{cfg}->{rankc};
            }
            _html("<tr><td bgcolor=\"$bgcolor\"><b>$a</b>");
            _html("<td bgcolor=\"$self->{cfg}->{hicell}\">$popular</td>");
            _html("<td bgcolor=\"$self->{cfg}->{hicell}\">$wordcount</td>");
            _html("<td bgcolor=\"$self->{cfg}->{hicell}\">$lastused</td>");
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
        _html("<td>&nbsp;</td><td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('url') . "</b></td>");
        _html("<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('numberuses') . "</b></td>");
        _html("<td bgcolor=\"$self->{cfg}->{tdtop}\"><b>" . $self->_template_text('lastused') . "</b></td>");

        for(my $i = 0; $i < $self->{cfg}->{urlhistory}; $i++) {
            last unless $i < @sorturls;
            my $a = $i + 1;
            my $sorturl  = $sorturls[$i];
            my $urlcount = $self->{stats}->{urlcounts}{$sorturls[$i]};
            my $lastused = $self->{stats}->{urlnicks}{$sorturls[$i]};
            if (length($sorturl) > 60) {
                $sorturl = substr($sorturl, 0, 60);
            }
            my $bgcolor;
            if ($a == 1) {
                $bgcolor = $self->{cfg}->{hi_rankc};
            } else {
                $bgcolor = $self->{cfg}->{rankc};
            }
            _html("<tr><td bgcolor=\"$bgcolor\"><b>$a</b>");
            _html("<td bgcolor=\"$self->{cfg}->{hicell}\"><a href=\"$sorturls[$i]\">$sorturl</a></td>");
            _html("<td bgcolor=\"$self->{cfg}->{hicell}\">$urlcount</td>");
            _html("<td bgcolor=\"$self->{cfg}->{hicell}\">$lastused</td>");
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
    _html("<td align=\"center\" class=\"asmall\"><img src=\"$self->{cfg}->{pic_loc}/$self->{cfg}->{pic_h_0}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"\"> = 0-5</td>");
    _html("<td align=\"center\" class=\"asmall\"><img src=\"$self->{cfg}->{pic_loc}/$self->{cfg}->{pic_h_6}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"\"> = 6-11</td>");
    _html("<td align=\"center\" class=\"asmall\"><img src=\"$self->{cfg}->{pic_loc}/$self->{cfg}->{pic_h_12}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"\"> = 12-17</td>");
    _html("<td align=\"center\" class=\"asmall\"><img src=\"$self->{cfg}->{pic_loc}/$self->{cfg}->{pic_h_18}\" width=\"40\" height=\"15\" align=\"middle\" alt=\"\"> = 18-23</td>");
    _html("</tr></table>\n");
}

sub _replace_links
{
    # Sub to replace urls and e-mail addys to links
    my $str = shift;
    my $nick = shift;
    my ($url, $email, $replaced, $return_str);


    $str =~ s/(http:\/\/)?www\./http:\/\/www\./ig;
    $return_str = $str;
    $replaced = 0;
     if ($nick) {
        if ($url = match_url($str)) {
            $return_str =~ s/(\Q$url\E)/<a href="$1" target="_blank" title="Open in new window: $1">$nick<\/a>/g;
        }
        if ($email = match_email($str)) {
            $return_str =~ s/(\Q$email\E)/<a href="mailto:$1" title="Mail to $nick">$nick<\/a>/g;
        }
    } else {
        while ($replaced < 1) {
            $replaced = 1;
            if ($url = match_url($str)) {
                $return_str =~ s/(?<!(<a href="))(\Q$url\E)(?![-a-zA-Z0-9.,_~=:;&@%?#\/+]+)/<a href="$2" target="_blank" title="Open in new window: $2">$2<\/a>/g;
                $str =~ s/(\Q$url\E)//g;
                $replaced--;
            }
            if ($email = match_email($str)) {
                $return_str =~ s/(\Q$email\E)/<a href="mailto:$1" title="Mail to $1">$1<\/a>/g;
                $str =~ s/(\Q$email\E)//g;
                $replaced--;
            }
        }
    }
    return $return_str;
}

sub _user_linetimes
{
    my $self = shift;
    my $nick  = shift;
    my $top   = shift;

    my $bar      = "";
    my $len      = ($self->{stats}->{lines}{$nick} / $self->{stats}->{lines}{$top}) * 100;
    my $debuglen = 0;

    for (my $i = 0; $i <= 3; $i++) {
        next if not defined $self->{stats}->{line_times}{$nick}[$i];
        my $w = int(($self->{stats}->{line_times}{$nick}[$i] / $self->{stats}->{lines}{$nick}) * $len);
        $debuglen += $w;
        if ($w) {
            my $pic = 'pic_h_'.(6*$i);
            $bar .= "<img src=\"$self->{cfg}->{pic_loc}/$self->{cfg}->{$pic}\" border=\"0\" width=\"$w\" height=\"15\" align=\"middle\" alt=\"\">";
        }
    }
    $self->{debug}->("Length='$len', Sum='$debuglen'");
    return "$bar&nbsp;$self->{stats}->{lines}{$nick}";
}

sub _user_times
{
    my $self = shift;
    my ($nick) = @_;

    my $bar = "";

    for (my $i = 0; $i <= 3; $i++) {
        next if not defined $self->{stats}->{line_times}{$nick}[$i];
        my $w = int(($self->{stats}->{line_times}{$nick}[$i] / $self->{stats}->{lines}{$nick}) * 40);
        if ($w) {
            my $pic = 'pic_h_'.(6*$i);
            $bar .= "<img src=\"$self->{cfg}->{pic_loc}/$self->{cfg}->{$pic}\" border=\"0\" width=\"$w\" height=\"15\" alt=\"\">";
        }
    }
    return $bar;
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
        debug => $debug,
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

B<debug> - reference to a sub routine to send the debug information.

B<stats> - reference to the hash returned by Pisg::Parser::Logfile containing all stats.

B<users> - reference to a hash containg user information

B<tmps> - reference to a hash containing the language templates.

=back

=head1 AUTHOR

Morten Brix Pedersen <morten@wtf.dk>

=head1 COPYRIGHT

Copyright (C) 2001 Morten Brix Pedersen. All rights resereved.
This program is free software; you can redistribute it and/or modify it
under the terms of the GPL, license is included with the distribution of
this file.

=cut
