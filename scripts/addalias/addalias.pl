#!/usr/bin/perl -w

use strict;
print "Content-Type: text/html\n\n";

my (%oldnicks, @users, @nick, %form);

sub htmlheader
{
    print <<HTML
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
 <head>
  <title>IRC statistics - user addition page</title>
 </head>
 <style type="text/css">
  body,td {
      font-family: verdana, arial, sans-serif;
      font-size: 12px;
  }
 </style>
 <body>
HTML

}

sub htmlfooter
{
    print <<HTML
</body>
</html>
HTML
}

sub read_config
{
    open(FILE, "<pisg.cfg") or die("Error opening file: $!");
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
    foreach(@users) {
        if($users[$i] =~ /nick=/) {
            if ($users[$i] =~ /nick="(\S+)"(.*)/) {
                $nick[$i] = $1;
                $oldnicks{$nick[$i]}{'nick'} = $nick[$i];
            }
            if ($users[$i] =~ /alias="(\S+)".*/ or $users[$i] =~ /alias="(.*)"\s.* / or $users[$i] =~ /alias="(.*)">/ ) {
                my $alias = $1;
                $oldnicks{$nick[$i]}{'alias'} = $alias;
            }
            if ($users[$i] =~ /link="(\S+)"(.*)/) {
                my $link = $1;
                $oldnicks{$nick[$i]}{'link'} = $link;
            }
            if ($users[$i] =~ /pic="(\S+)"(.*)/) {
                my $pic = $1;
                $oldnicks{$nick[$i]}{'pic'} = $pic;
            }
            if ($users[$i] =~ /sex="(\S+)"(.*)/) {
                my $sex = $1;
                $oldnicks{$nick[$i]}{'sex'} = $sex;
            }
            if($users[$i] =~ /ignore="(\S+)"(.*)/) {
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

sub get_request
{
    my $input;
    if ($ENV{'REQUEST_METHOD'} eq 'GET') {  
        $input = $ENV{'QUERY_STRING'} 
    } else {
        read(STDIN, $input, $ENV{'CONTENT_LENGTH'}); 
    }

    my @formfields = split(/&/, $input);
    foreach my $field (@formfields) {
        my ($name, $value) = split(/=/, $field);
        $value =~ tr/+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $value =~ s/<!--(.|\n)*-->//g;
        $form{$name} = $value;
    }
    if ($form{'ignore'} eq "on") { $form{'ignore'} = 1; }
}

sub check_if_found
{

    my $found = 0;
    foreach (@nick) {
        if ($oldnicks{$_}{'nick'} eq $form{'nick'}) {
            $found = 1;
        }
    }
    if ($found eq "1") { 
        print "<p>The nickname you've choosen is already configured with the following settings:</p>\n";
        print "<table>\n <tr>\n";
        print "  <td>Nickname:</td>\n  <td>$oldnicks{$form{'nick'}}{'nick'}</td>\n";
        print " </tr>\n";
        if($oldnicks{$form{'nick'}}{'alias'}) { 
            print " <tr>\n";
            print "  <td>Aliases:</td>\n  <td>$oldnicks{$form{'nick'}}{'alias'}</td>\n";
            print " </tr>\n";
        }
        if($oldnicks{$form{'nick'}}{'link'}) {
            print " <tr>\n"; 
            if($oldnicks{$form{'nick'}}{'link'} =~ /^http:|ftp:/) {
                print "  <td>Link:</td>\n  <td><a href=\"$oldnicks{$form{'nick'}}{'link'}\">$oldnicks{$form{'nick'}}{'link'}</a></td>\n";
            }
            elsif ($oldnicks{$form{'nick'}}{'link'} =~ /(.*)@(.*).(.*)/) {
                print "  <td>Link:</td>\n  <td><a href=\"mailto:$oldnicks{$form{'nick'}}{'link'}\">$oldnicks{$form{'nick'}}{'link'}</a></td>\n";
            } else {
                print "  <td>Link:</td>\n  <td>$oldnicks{$form{'nick'}}{'link'}</td>\n";
            }
            print " </tr>\n";
        }
        if($oldnicks{$form{'nick'}}{'pic'}) { 
            print " <tr>\n";
            print "  <td>Userpic:</td>\n  <td valign=\"middle\"><a href=\"$oldnicks{$form{'nick'}}{'pic'}\"><img src=\"$oldnicks{$form{'nick'}}{'pic'}\" border=\"0\"></a></td>\n";
            print " </tr>\n";
        }
        if($oldnicks{$form{'nick'}}{'sex'}) { 
            print " <tr>\n";
            print "  <td>Sex:</td>\n  <td valign=\"middle\">$oldnicks{$form{'nick'}}{'sex'}</td>\n";
            print " </tr>\n";
        }
        if($oldnicks{$form{'nick'}}{'ignore'} eq "1") {
            print " <tr>\n";
            print "  <td>Ignore:</td>\n  <td>Yes</td>\n";
            print " </tr>\n";
        }
        print "</table>\n";
        print "<p>Please click <a href=\"javascript:history.back()\">here</a> to choose an other nickname</p>\n";
        exit(0);
    }
}

sub checks
{
    if(!$form{'nick'}) { 
        print "You haven't entered a nickname.. Your request will be ignored<br>";
        print "Please click <a href=\"javascript:history.back()\">here</a> to choose an other nickname";
        exit(0);
    }

    if($form{'nick'} and !$form{'alias'} and !$form{'link'} and !$form{'pic'} and !$form{'ignore'} and !$form{'sex'}) {
        print "You've entered a nickname but haven't configured any settings for that nickname<br>\n";
        print "Please click <a href=\"javascript:history.back()\">here</a> to configure some settings for the nickname";
        exit(0);
    }
}

sub add_line
{
    my $line_to_add = "<user";
    if($form{'nick'}) {
        $line_to_add .= " nick=\"$form{'nick'}\"";
    }
    if($form{'alias'}) {
        $line_to_add .= " alias=\"$form{'alias'}\"";
    }
    if($form{'link'}) {
        $line_to_add .= " link=\"$form{'link'}\"";
    }
    if($form{'pic'}) {
        $line_to_add .= " pic=\"$form{'pic'}\"";
    }
    if($form{'sex'}) {
        $line_to_add .= " sex=\"$form{'sex'}\"";
    }
    if($form{'ignore'} eq "1") {
        $line_to_add .= " ignore=\"y\"";
    }

    $line_to_add .= ">";

    print <<HTML
You nickname was successfully added.:<br>\n
<table>
 <tr>
  <td>Nickname:</td><td>$form{'nick'}</td>
 </tr>
HTML
;
    if($form{'alias'}) { 
        print " <tr>\n";
        print "  <td>Aliases:</td><td>$form{'alias'}</td>\n";
        print " </tr>\n";
    }
    if($form{'link'}) {
        print " <tr>\n";
        print "  <td>Link:</td><td><a href=\"$form{'link'}\">$form{'link'}</a></td>\n";
        print " </tr>\n";
    }
    if($form{'pic'}) {
        print " <tr>\n";
        print "  <td>Userpic:</td><td><img src=\"$form{'pic'}\"></td>\n";
        print " </tr>\n";
    }
    if($form{'sex'}) {
        print " <tr>\n";
        print "  <td>Sex:</td><td>$form{'sex'}</td>\n";
        print " </tr>\n";
    }
    if($form{'ignore'} eq "1") {
        print " <tr>\n";
        print "  <td>Ignore:</td><td>Yes</td>\n";
        print " </tr>\n";
    }
    open(FILE, ">>pisg.cfg") or die("Error opening file: $!");
    print FILE "$line_to_add\n";
    close(FILE);
}

sub main
{
    htmlheader();

    my $search = read_config();
    get_request();
    if ($search ne "1") {
        check_if_found();
    }
    checks();
    add_line();
    htmlfooter();

}
main();
