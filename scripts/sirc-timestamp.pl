# sirc-timestamp.pl
# script for sirc irc client  which shows time in every line
# by bartko!misiopysio09@netscape.net
# http://mywebpage.netscape.com/bartek09/

$add_ons.="+sirc-timestamp.pl";

sub whattime {
   ($sec,$min,$hour) = localtime(time);
   ($min < 10) && ($min = "0" . $min);
   ($hour < 10) && ($hour = "0" . $hour);
   return "$hour:$min";
}
 
sub hook_timeprint {
  my ($theline) = $_[0];
  $_[0] = whattime() . ' ' . $theline;
}
addhook ('print','timeprint');

&addhelp("timestamp","This is \cusirc-timestamp.pl\cu for sirc by \cbbartko\cb

The script adds timestamps in format hh:mm at the
beginning of each line");

print("*\cba\cb* \cbbartko\cb's \cvsirc-timestamp.pl\cv loaded ... \n");
