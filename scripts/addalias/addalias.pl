#!/usr/bin/perl -w


print "Content-Type: text/html\n\n";

my %oldnicks;
open(FILE, "<users.cfg") || die "File not found";
$i = 0;
while(<FILE>) {
	if($_ =~ /^<user/) {
		$users[$i] = $_;
		chomp $users[$i];
		$i++;
	}
}
close(FILE);
$i=0;
foreach(@users) {
	if($users[$i] =~ /nick=/) {
		if($users[$i] =~ /nick="(\S+)"(.*)/) {
			$nick[$i] = $1;
			$oldnicks{$nick[$i]}{'nick'} = $nick[$i];
		}
		if($users[$i] =~ /alias="(\S+)".*/ or $users[$i] =~ /alias="(.*)"\s.* / or $users[$i] =~ /alias="(.*)">/ ) {
			$alias = $1;
			$oldnicks{$nick[$i]}{'alias'} = $alias;
		}
        if($users[$i] =~ /link="(\S+)"(.*)/) {
            $link = $1;
			$oldnicks{$nick[$i]}{'link'} = $link;
        }
        if($users[$i] =~ /pic="(\S+)"(.*)/) {
            $pic = $1;
            $oldnicks{$nick[$i]}{'pic'} = $pic;
        }
        if($users[$i] =~ /ignore="(\S+)"(.*)/) {
            $ignore = $1;
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

if($ENV{'REQUEST_METHOD'} eq 'GET') {  
	$input = $ENV{'QUERY_STRING'} 
} else {
	read(STDIN, $input, $ENV{'CONTENT_LENGTH'}); 
}

@formfields = split(/&/, $input);
foreach $field (@formfields) {
	($name, $value) = split(/=/, $field);
	$value =~ tr/+/ /;
	$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
	$value =~ s/<!--(.|\n)*-->//g;
	$form{$name} = $value;
}
if($form{'ignore'} eq "on") { $form{'ignore'} = 1; }
if($search ne "1") {
	foreach (@nick) {
		if($oldnicks{$_}{'nick'} eq $form{'nick'}) {
			$found = 1;
		}
	}
	if($found eq "1") { 
		print "<p>The Nickname you've choosen is allready configured with the following settings:</p>\n";
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
			print "  <td>Userpic:</td>\n  <td valign=\"middel\"><a href=\"$oldnicks{$form{'nick'}}{'pic'}\"><img src=\"$oldnicks{$form{'nick'}}{'pic'}\" border=\"0\"></a></td>\n";
			print " </tr>\n";
		}
		if($oldnicks{$form{'nick'}}{'ignore'} eq "1") {
            print " <tr>\n";
            print "  <td>Ignore:</td>\n  <td>Yes</td>\n";
            print " </tr>\n";
		}
		print "</table>\n";
		print "<p>Please click <a href=\"javascript:history.back()\">here</a> to choose an other Nickname</p>\n";
		exit(0);
	}
}
if(!$form{'nick'}) { 
	print "You haven't entered a Nickname.. Your request will be ignored<br>";
	print "Please click <a href=\"javascript:history.back()\">here</a> to choose an other Nickname";
	exit(0);
}
if($form{'nick'} and !$form{'alias'} and !$form{'link'} and !$form{'pic'} and !$form{'ignore'}) {
	print "You've entered a Nickname but haven't configured any settings for that Nickname<br>\n";
	print "Please click <a href=\"javascript:history.back()\">here</a> to configure some settings for the nickname";
	exit(0);
}
$eintrag = "<user";
if($form{'nick'}) {
	$eintrag = $eintrag . " nick=\"$form{'nick'}\"";
}
if($form{'alias'}) {
	$eintrag = $eintrag . " alias=\"$form{'alias'}\"";
}
if($form{'link'}) {
	$eintrag = $eintrag . " link=\"$form{'link'}\"";
}
if($form{'pic'}) {
	$eintrag = $eintrag . " pic=\"$form{'pic'}\"";
}
if($form{'ignore'} eq "1") {
	$eintrag = $eintrag . " ignore=\"y\"";
}
$eintrag = $eintrag . ">";

print <<HTML
You Nickname was successfully added.:<br>\n
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
if($form{'ignore'} eq "1") {
    print " <tr>\n";
    print "  <td>Ignorieren:</td><td>Ja</td>\n";
    print " </tr>\n";
}
open(FILE, ">>users.cfg") || die "File not found";
print FILE "$eintrag\n";
close(FILE);
