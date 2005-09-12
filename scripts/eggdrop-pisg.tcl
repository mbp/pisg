#pisg.tcl v0.15 by HM2K - auto stats script for pisg (perl irc statistics generator)
#based on a script by Arganan

# WARNING - READ THIS
#
# If you use this script, PLEASE read the documentation about the "Silent"
# option. If you get the message "an error occured: Pisg v0.67 - perl irc
# statistics generator" in the channel, you are NOT running silent. Fix it.

set pisgver "0.15"

#Location of pisg execuitable perl script
set pisgexe "/home/nf/pisg/pisg"

#URL of the generated stats
set pisgurl "http://stats.nemesisforce.com/"

#channel that the stats are generated for
set pisgchan "#nemesisforce"

#Users with these flags can operate this function
set pisgflags "nm"

#How often the stats will be updated in minutes, ie: 30 - stats will be updated every 30 minutes
set pisgtime "30"

bind pub $pisgflags !stats pub:pisgcmd

proc pub:pisgcmd {nick host hand chan arg} {
	global pisgexe pisgurl pisgchan
	append out "PRIVMSG $pisgchan :" ; if {[catch {exec $pisgexe} error]} { append out "$pisgexe an error occured: [string totitle $error]" } else { append out "Stats Updated: $pisgurl" }
	puthelp $out
}

proc pisgcmd_timer {} {
	global pisgexe pisgurl pisgchan pisgtime
	append out "PRIVMSG $pisgchan :" ; if {[catch {exec $pisgexe} error]} { append out "$pisgexe an error occured: [string totitle $error]" } else { append out "Stats Updated: $pisgurl" }
	puthelp $out
	timer $pisgtime pisgcmd_timer
}

if {![info exists {pisgset}]} {
  set pisgset 1
  timer 2 pisgcmd_timer
}

putlog "pisg.tcl $pisgver loaded"
