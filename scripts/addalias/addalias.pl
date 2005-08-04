#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser carpout);

###########################################################################
#                                                                         #
#  addalias version 2.2 by deadlock (deadlock@cheeseheadz.net)            #
#                                                                         #
#  This script can be used on a webpage for users to enter and edit their #
#  own info for the pisg ircstats program by mbrix.                       #
#                                                                         #
#  addalias v2+ is based on the original addalias program by Doomshammer  #
#                                                                         #
###########################################################################

#############################
### Configuration section ###
#############################

# File locations:

my $pisg_config = "/path/to/pisg.cfg";

# Server URL
# If your script resists in http://myserver/cgi-bin/addalias.pl you should
# set it to: "/cgi-bin"

my $url         = "/cgi-bin";

# Page layout:

my $c_bgcolor   = "#FFFFFF";
my $c_text      = "#000000";
my $c_link      = "blue";
my $c_vlink     = "#C0C0C0";
my $c_alink     = "#C0FFC0";
my $c_border    = "#FFFFFF";

my $title       = "IRC statistics - user addition page";

# Text on the main page

my $txthead1    = "In this form you can enter the settings (aliases, link and user picture) for your nickname in the IRC-stats.";
my $txthead2    = "Nicknames are allowed only once.";
my $txtnick     = "Nickname";
my $txtalias    = "Alias(es)";
my $txturl      = "URL/E-Mail";
my $txtpic      = "Userpic";
my $txtsex      = "Sex";
my $txtmale     = "M";
my $txtfemale   = "F";
my $txtbot      = "B";
my $txtignore   = "Ignore me";
my $btnsubmit   = "Submit";
my $btnupdate   = "Update";
my $txtfoot1    = "To update your settings, just enter your nickname and click Submit to retrieve your current settings.";
my $txthelp     = "For help on this form click <a href=\"$url/addalias.pl/help\" target=\"_blank\">here</a>.";
my $txtlist     = "For a complete list of known nicks please click <a href=\"$url/addalias.pl/list\">here</a>.";
my $txtupdate   = "These are your current settings. Edit them where needed and click Update to update your info.";
my $txtaddok    = "Your nickname was successfully added.";
my $txtignoreon = "You activated ignore and will not appear in the stats.";
my $txtupdateok = "Your info was successfully updated.";

# Helptext:

my $nickhelp    = "Enter the name you want to use in the stats here.";
my $aliashelp   = "Add all aliases you use here, seperated by spaces, so they will be joined in the stats. A * is allowed as a wildcard. For example: MyNick[Zzz], MyNick-afk and MyNick-work could be entered as 'MyNick[Zzz] MyNick-*' or just as 'MyNick*'";
my $urlhelp     = "You can enter a webpage or e-mail adress here to be linked to your nick in the stats.";
my $pichelp     = "If you enter a link to a picture here it will be added to your stats on the page.";
my $sexhelp     = "This setting is used to determine if lines in the stats should read 'his' or 'her' or 'bot' when referring to you.";
my $ignorehelp  = "If you don't want to be included in the stats, select this option.";


###################################
### End config section          ###
### do not edit below this line ###
###################################

# Main program

my $path = path_info();
$path =~ s!^/!!;
my (%oldnicks, @users, @nick);
my ($frm_nick, $frm_alias, $frm_link, $frm_pic, $frm_sex, $frm_ignore);
my ($old_nick, $old_alias, $old_link, $old_pic, $old_sex, $old_ignore);
my ($old_sexm, $old_sexf, $old_sexb, $old_ignr);
my ($cfg, $fnd);
my ($submitbtn, $frmaction);

htmlheader();
if (!$path) {
    $submitbtn = $btnsubmit;
    $frmaction="\"$url/addalias.pl/input\"";
    $txtupdate = "";
    mainpage();
} elsif ($path eq 'help') {
    helppage();
} elsif ($path eq 'list') {
    $submitbtn = $btnsubmit;
    $frmaction="\"$url/addalias.pl/input\"";
    $txtupdate = "";
    mainpage();
    list();

} elsif ($path eq 'input') {
    readparams();
    if ($frm_nick eq "") {
       no_nick();
       $submitbtn = $btnsubmit;
       $frmaction="\"$url/addalias.pl/input\"";
       $txtupdate = "";
       mainpage();
    } else {
       $cfg = read_config();
       if ($cfg ne "1") {
           $fnd = check_if_found();
           if ($fnd eq "1") {
               $submitbtn = $btnupdate;
               $frmaction="\"update\"";
               $txtfoot1="";
               mainpage();
           }
           else {
               $submitbtn = $btnupdate;
               $frmaction="\"update\"";
               addinfo();
               mainpage();
           }
       }
       else {
           $submitbtn = $btnupdate;
           $frmaction="\"update\"";
           addinfo();
           mainpage();
       }
    }
} elsif ($path eq 'update') {
    readparams();
    if ($frm_nick eq "") {
       no_nick();
       mainpage();
    } else {
       $cfg = read_config();
       $submitbtn = $btnupdate;
       $frmaction="\"update\"";
       updateinfo();
       mainpage();
    }
} else {
    print "Illegal calling of script<br>\n";
}

htmlfooter();


# Subs

sub htmlheader
{
print <<HTML
Content-Type: text/html


<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
 <head>
  <title>$title</title>
 </head>
 <body bgcolor="$c_bgcolor" text="$c_text" link="$c_link" vlink="$c_vlink" alink="$c_alink">
HTML

}


sub htmlfooter
{
print <<HTML
 </body>
</html>
HTML
}


sub mainpage
{
print <<HTML
  <p>$txthead1<br> $txthead2</p>
  $txtupdate<br>
  <form action=$frmaction method="POST">
   <table width="400" cellpadding="2" cellpadding="2" border="0" style="border: 1px
   ridge $c_border">
    <tr>
     <td><b>$txtnick</b></td>
     <td><input name="nick" type="text" width="30" value="$old_nick"></td>
    </tr>
    <tr>
     <td><b>$txtalias</b></td>
     <td><input name="alias" type="text" width="30" value="$old_alias"></td>
    </tr>
    <tr>
     <td><b>$txturl</b></td>
     <td><input name="link" type="text" width="30" value="$old_link"></td>
    </tr>
    <tr>
     <td><b>$txtpic</b></td>
     <td><input name="pic" type="text" width="30" value="$old_pic"></td>
    </tr>
    <tr>
     <td><b>$txtsex</b></td>
     <td>$txtmale<input type="radio" name="sex" value="m" $old_sexm>$txtfemale<input type="radio" name="sex" value="f" $old_sexf>$txtbot<input type="radio" name="sex" value="b" $old_sexb></td>
    </tr>
    <tr>
     <td><b>$txtignore</B></td>
     <td><input type="checkbox" name="ignore" $old_ignr></td>
    </tr>
    <tr>
     <td></td>
     <td>
      <input type="submit" value="$submitbtn">
      <input type="reset" value="Reset form">
     </td>
    </tr>
   </table>
  </form>
  $txtfoot1<br>
  $txthelp<br><br>
  $txtlist<br><br>
HTML
}


sub helppage
{
print <<HTML
  <b>$txtnick:</b><br>
  $nickhelp<br>
  <b>$txtalias:</b><br>
  $aliashelp<br>
  <b>$txturl:</b><br>
  $urlhelp<br>
  <b>$txtpic:</b><br>
  $pichelp<br>
  <b>$txtsex:</b><br>
  $sexhelp<br>
  <b>$txtignore:</b><br>
  $ignorehelp<br>
HTML
}

sub readparams
{
   $frm_nick = param('nick');
   $frm_alias = param('alias');
   $frm_link = param('link');
   $frm_pic = param('pic');
   $frm_sex = param('sex');
   $frm_ignore = param('ignore');
}

sub list
{
    open(FILE, "<$pisg_config") or die("Error opening pisg config file: $!");
    my $i = 0;
    my $nick;
    my $alias;
    while(<FILE>) {
        if($_ =~ /^<user/) {
            $users[$i] = $_;
            chomp $users[$i];
            $i++;
        }
    }
    close(FILE);
    $i = 0;

    print "<table width=\"800\" cellpadding=\"2\" cellpadding=\"2\" border=\"0\" style=\"border: 1px ridge $c_border\">\n <tr>\n  <td align=\"left\"><b>$txtnick</b></td><td align=\"left\"><b>$txtalias</b></td> </tr>\n";

    foreach (@users) {
        if ($users[$i] =~ /nick=.*/) {
            if ($users[$i] =~ /nick="(\S+)"(.*)/) {
                $nick = $1;
            }
            if ($users[$i] =~ /alias="(\S+)".*/ or $users[$i] =~ /alias="(.*)"\s.*/ or $users[$i] =~ /alias="(.*)">/ ) {
                $alias = $1;
            }
            print " <tr>\n  <td>$nick</td><td>$alias</td>\n <tr>\n";
        }
    $i++
    }
}

sub read_config
{
    open(FILE, "<$pisg_config") or die("Error opening pisg config file: $!");
    my $i = 0;
    while(<FILE>) {
        if($_ =~ /^<user/) {
            $users[$i] = $_;
            chomp $users[$i];
            $i++;
        }
    }
    close(FILE);

    my $search = 0;
    $i = 0;
    foreach (@users) {
        if ($users[$i] =~ /nick=/) {
            if ($users[$i] =~ /nick="(\S+)"(.*)/) {
                $nick[$i] = lc($1);
                $oldnicks{$nick[$i]}{'nick'} = $1;
            }
            if ($users[$i] =~ /alias="(\S+)".*/ or $users[$i] =~ /alias="(.*)"\s.* / or $users[$i] =~ /alias="(.*)">/ ) {
                $oldnicks{$nick[$i]}{'alias'} = $1;
            }
            if ($users[$i] =~ /link="(\S+)"(.*)/) {
                $oldnicks{$nick[$i]}{'link'} = $1;
            }
            if ($users[$i] =~ /pic="(\S+)"(.*)/) {
                $oldnicks{$nick[$i]}{'pic'} = $1;
            }
            if ($users[$i] =~ /sex="(\S+)"(.*)/) {
                $oldnicks{$nick[$i]}{'sex'} = $1;
            }
            if ($users[$i] =~ /ignore="(\S+)"(.*)/) {
                my $ignore = $1;
                if($ignore eq "y" or $ignore eq "Y") {
                    $ignore = 1;
                } else {
                    $ignore = 0;
                }
                $oldnicks{$nick[$i]}{'ignore'} = $ignore;
            }
        } else {
            $search = 1;
        }
        $i++;
    }
    return $search;
}


sub no_nick
{
    print <<HTML
<font color="red" size="+1"><b>Error:</b> No Nickname given!</font><br>
HTML
;
}

sub check_if_found
{

    my $found = 0;
    my $lcnick = lc($frm_nick);
    foreach (@nick) {
        if (lc($oldnicks{$_}{'nick'}) eq $lcnick) {
            $found = 1;
            last;
        }
    }
    if ($found eq "1") {
        $old_nick = $oldnicks{$lcnick}{'nick'};
        $old_alias = $oldnicks{$lcnick}{'alias'};
        $old_link = $oldnicks{$lcnick}{'link'};
        $old_pic = $oldnicks{$lcnick}{'pic'};
        $old_sex = $oldnicks{$lcnick}{'sex'};
        $old_ignore = $oldnicks{$lcnick}{'ignore'};
        if ($old_sex eq "m" or $old_sex eq "M"){
            $old_sexm = "checked";
        }
        elsif ($old_sex eq "f" or $old_sex eq "F"){
            $old_sexf = "checked";
        }
        elsif ($old_sex eq "b" or $old_sex eq "B"){
            $old_sexb = "checked";
        }
        if ($old_ignore eq "1"){
            $old_ignr = "checked";
        }
    }
    return $found;
}

sub addinfo
{
    my $line_to_add = "<user";
    if($frm_nick) {
        $line_to_add .= " nick=\"$frm_nick\"";
    }
    if($frm_alias) {
        $line_to_add .= " alias=\"$frm_alias\"";
    }
    if($frm_link) {
        $line_to_add .= " link=\"$frm_link\"";
    }
    if($frm_pic) {
        $line_to_add .= " pic=\"$frm_pic\"";
    }
    if($frm_sex) {
        $line_to_add .= " sex=\"$frm_sex\"";
    }
    if($frm_ignore eq "on") {
        $line_to_add .= " ignore=\"y\"";
    }

    $line_to_add .= ">";

    open(FILE, ">>$pisg_config") or die("Error writing to configfile: $!");
    print FILE "$line_to_add\n";
    close(FILE);

    $old_nick = $frm_nick;
    $old_alias = $frm_alias;
    $old_link = $frm_link;
    $old_pic = $frm_pic;
    $old_sex = $frm_sex;
    $old_ignore = $frm_ignore;
    if ($old_sex eq "m" or $old_sex eq "M"){
        $old_sexm = "checked";
    }
    elsif ($old_sex eq "f" or $old_sex eq "F"){
        $old_sexf = "checked";
    }
    elsif ($old_sex eq "b" or $old_sex eq "B"){
        $old_sexb = "checked";
    }
    if ($old_ignore eq "1"){
        $old_ignr = "checked";
    }
    print "<font color=\"green\">$txtaddok</font><p>\n";
}

sub updateinfo
{
    my $line;
    my $line_to_add = "<user";
    if ($frm_nick) {
        $line_to_add .= " nick=\"$frm_nick\"";
    }
    if ($frm_alias) {
        $line_to_add .= " alias=\"$frm_alias\"";
    }
    if ($frm_link) {
        $line_to_add .= " link=\"$frm_link\"";
    }
    if ($frm_pic) {
        $line_to_add .= " pic=\"$frm_pic\"";
    }
    if ($frm_sex) {
        $line_to_add .= " sex=\"$frm_sex\"";
    }
    if ($frm_ignore eq "on") {
        $line_to_add .= " ignore=\"y\"";
    }

    $line_to_add .= ">";

    open(OLDFILE, "$pisg_config") or die("Error reading configfile: $!");
    &lock_file(*OLDFILE);
    my @lines = <OLDFILE>;
    close(OLDFILE);
    open(NEWFILE, ">$pisg_config") or die("Error updating configfile: $!");
    &lock_file(*NEWFILE);
    foreach $line (@lines) {
       if ($line =~ /^<user.*nick=\"\Q$frm_nick\E\"/i) {
         print NEWFILE "$line_to_add\n"
       } else {
         print NEWFILE $line;
       }
    }
    close (NEWFILE);

    $old_nick = $frm_nick;
    $old_alias = $frm_alias;
    $old_link = $frm_link;
    $old_pic = $frm_pic;
    $old_sex = $frm_sex;
    $old_ignore = $frm_ignore;
    if ($old_sex eq "m" or $old_sex eq "M"){
        $old_sexm = "checked";
    }
    elsif ($old_sex eq "f" or $old_sex eq "F"){
        $old_sexf = "checked";
    }
    elsif ($old_sex eq "b" or $old_sex eq "B"){
        $old_sexb = "checked";
    }
    if ($old_ignore eq "1"){
        $old_ignr = "checked";
    }

    print "<font color=\"green\">$txtupdateok</font><p>\n";
}

sub lock_file {
    my $lock = 2;
    flock($_[0], $lock);
}
