#!/usr/bin/perl

# Drop Egg
#
# This script takes a heap of daily eggdrop logs and changes them around
# to look a little more mIRC-like. (So that they can be fed through PISG
# and whatnot)
#
# Copyright 2001, Emil Mikulic. <darkmoon7@optushome.com.au>

use Time::Local;

$logdir = "/home/darkmoon/eggdrop/logs";
$logname = "gencorp.log";
$outfile = "gencorp.out";
$channel = "#gencorp";

open(OUTFILE, ">$outfile");

foreach (`ls $logdir/$logname.*`)
{
 chomp( $current_log = $_ );
 print "Sanitizing $current_log...";

 ($year,$mon,$day) = $current_log =~ /$logdir\/$logname\.(\d\d\d\d)(\d\d)(\d\d)/;
 $time = timelocal(1,0,0,$day,$mon,$year);
 print OUTFILE "\nSession Start: " . localtime($time) . "\n";
 print OUTFILE "[00:00] *** Now talking in $channel\n";

 foreach (`cat $current_log`)
 {
  chomp( $line = $_ );

  $line =~ s/\cB//g;
  $line =~ s/\c_//g;
  $line =~ s/\cO//g;
  $line =~ s/\cC\d+//g;

  # [02:25] DTails (~Dtails@co3033554-a.mckinn1.vic.optushome.com.au) joined #gencorp.
  # [14:48] *** shai (cmot_dblah@a1-46.melbpc.org.au) has joined #breakfastclub

  if (($line =~ /joined/) && !($line =~ /\</))
  {
   ($timestamp,$nick,$hostmask) = $line =~ /(\[\d\d\:\d\d\]) (\S+) \(([^)]+)\) joined/;
   $line = "$timestamp *** $nick ($hostmask) has joined $channel";
  }

  # [02:26] DTails (~Dtails@co3033554-a.mckinn1.vic.optushome.com.au) left irc: We're the
  # [14:46] *** alice (noidea@dialup-33.ap1-nas7.unite.mel.dav.net.au) Quit

  if (($line =~ /left irc/) && !($line =~ /\[\d\d\:\d\d\] \</))
  {
   ($timestamp,$nick,$hostmask) = $line =~ /(\[\d\d\:\d\d\]) (\S+) \(([^)]+)\) left irc/;
   $line = "$timestamp *** $nick ($hostmask) Quit";
  }

  if (($line =~ /got netsplit/) && !($line =~ /\[\d\d\:\d\d\] \</))
  {
   ($timestamp,$nick,$hostmask) = $line =~ /(\[\d\d\:\d\d\]) (\S+) \(([^)]+)\) got netsplit/;
   $line = "$timestamp *** $nick ($hostmask) Quit";
  }

  # [19:42] Action: G..... wipes away tear
  # [19:42] * G..... is a SED KENT

  if ($line =~ /\[\d\d\:\d\d\] Action/)
  {
   $line =~ s/Action\:/\*/;
  }

  # [12:06] Nick change: DTails -> DT|Work
  # [14:53] *** Death is now known as Memnoch

  if ($line =~ /\[\d\d\:\d\d\] Nick change/)
  {
   $line =~ s/(\[\d\d\:\d\d\]) Nick change\: (\S+) \-\> (\S+)/$1 *** $2 is now known as $3/;
  }

  # [11:23] #gencorp: mode change '+o ark|tv' by curtis!~curtis@co...
  # [11:23] *** curtis sets mode: +o ark
  if ($line =~ /\[\d\d\:\d\d\] \#\S+ mode change/)
  {
   ($timestamp,$mode,$setter) = $line =~
	/(\[\d\d\:\d\d\]) \#\S+ mode change \'([^']+)\' by ([^!]+)\!/;
   $line = "$timestamp *** $setter sets mode: $mode";
  }

  # [19:32] Gumpy kicked from #gencorp by curtis: flood
  # [18:49] *** darkmoon was kicked by dark|away (BLAM!)
  if ($line =~ /\[\d\d\:\d\d\] \S+ kicked from \#/)
  {
   ($timestamp,$victim,$kicker,$reason) = $line =~
	/(\[\d\d\:\d\d\]) (\S+) kicked from \#\S+ by ([^:]+)\: (.+)/;
   $line = "$timestamp *** $victim was kicked by $kicker ($reason)";
  }

  # [00:48] Topic changed on #gen by arknstone!~...: <topic>
  # [14:43] *** arknstone changes topic to 'this is a test'
  if ($line =~ /\[\d\d\:\d\d\] Topic changed/)
  {
   ($timestamp,$changer,$topic) = $line =~
	/(\[\d\d\:\d\d\]) Topic changed on \#\S+ by ([^!]+)\![^:]+\: (.+)/;
   $line = "$timestamp *** $changer changes topic to '$topic'";
  }



  if (!(($line =~ /got lost/) && !($line =~ /\[\d\d\:\d\d\] \</)))
  {
   print OUTFILE "$line\n";
  }

 }

 $time = timelocal(59,59,23,$day,$mon,$year);
 print OUTFILE "Session Close: " . localtime($time) . "\n";
 print "done!\n";
}

close(OUTFILE);

