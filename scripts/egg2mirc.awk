#!/bin/awk
# Quite fast log format converter (eggdrop->mirc)
# For those channel stat generators that accept only mirc log format
# use: awk -f egg2mirc.awk channel.log > mircformat.log
#
# Gandalf the Grey <gandalf@irc.pl>
# "The Song Remains The Same" - Led Zeppelin
#
/\[..\:..\] <.+>/ {	print $0 
			next }
/\[..\:..\] Action:/ { 	$2="*"
			print $0 
			next }
/\[..\:..\] .+ (.+) joined #/	{	print $1 " *** " $2 " " $3 " has " $4 " " substr($5,1,length($5)-1) 
					next }
/\[..\:..\] .+ (.+) left #/	{	print $1 " *** " $2 " " $3 " has " $4 " " substr($5,1,length($5)-1) 
					next }
/\[..\:..\] .+ (.+) left irc/	{	print $1 " *** " $2 " " $3 " Quit (" $6 "...)" 
					next }
/\[..\:..\] .+ kicked from #/	{	print $1 " *** " $2 " was " $3 " by " substr($7,1,length($7)-1) " (" $8 "...)" 
					next }
/\[..\:..\] #.+\: mode change /	{ if (index($NF,"!")!=0) print $1 " *** " substr($NF,1,index($NF,"!")-1) " sets mode: " substr($0,index($0,"'")+1,length($0)-length($(NF))-index($0,"'")-5) 
					else print $1 " *** " $NF " sets mode: " substr($0,index($0,"'")+1,length($0)-length($(NF))-index($0,"'")-5)}
