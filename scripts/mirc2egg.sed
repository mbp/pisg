#!/bin/sed -f
# mirc2egg.sed: convert mIRC log to eggdrop format - 01/12/02
# Useful in replacing missing eggdrop logs 
# (supports mIRC 5.x, 6.x and 'Peace and Protection' formats)
#
# Usage: sed -f mirc2egg.sed channel.log > eggformat.log
#
# Geoff Simmons <geoff.simmons@member.sage-au.org.au>

{
        # Remove carriage returns, delete single hyphen and blank lines
        s/$//
        /^-$/d
        /^$/d

        # Strip color/formatting
        s/[0-9][0-9],[0-9][0-9]//g
        s/[0-9],[0-9][0-9]//g
        s/[0-9][0-9],[0-9]//g
        s/[0-9],[0-9]//g
        s/[0-9][0-9]//g
        s/[0-9]//g
        s///g
        s///g
        s///g
        s///g
        s///g
        s/—//g

        # Remove seconds from timestamp
        s/^\[\(..:..\):..\]/[\1]/

        # PnP: reformat conversations to standard mIRC
        /^\[..:..\] (.*): /{
                s/(/</1
                s/):/>/1
        }

        # Extract channel name from header, convert to lower-case, 
        # place in hold space, delete from pattern space
        /^\[..:..\] \*\*\* Now talking in #/{
        s/.*\(#.*\)/\1/1
        y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/
        h
        d       
        }       
        /^Session Ident:/{
        s/.*: \(.*\)/\1/1
        y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/
        h
        d
        }

        # Change footer into end-of-log mark
        s/^Session Close: \(...\) \(...\) \(..\) \(..:..\):.. \(....\)/[\4] --- \1 \2 \3 \5/

        # Retain conversations, actions and events - purge everything else
        /^\[..:..\] [<*-].*/!d

        # Remove op/voice tags from talking/actions
        s/^\[\(..:..\)\] <[@+]/[\1] </
        s/^\[\(..:..\)\] \* [@+]/[\1] \* /

        # Reformat nick changes (mIRC 5.x)
        /^\[..:..\] \*\*\* .*is now known as/{
                s/is now known as/->/1
                s/^\[\(..:..\)\] \*\*\*/[\1]/
                s/^\[\(..:..\)\]/[\1] Nick change:/
        }
        # Reformat nick changes (mIRC 6.x)
        /^\[..:..\] \* .*is now known as/{
                s/is now known as/->/1
                s/^\[\(..:..\)\] \*/[\1]/
                s/^\[\(..:..\)\]/[\1] Nick change:/
        }

        # Reformat quit actions (PnP)
        /^\[..:..\] \*\*\* Quits: .* (.*@.*\..*\..*)/{
                s/\*\*\* Quits: //1
                s/) (/) left irc: /1
                s/)$//
        }
        # Reformat quit actions, append fake hostmask (mIRC 5.x)
        /^\[..:..\] \*\*\* Quits:/{
                s/\*\*\* Quits: //1
                s/] \(.*\) (\(.*\))$/] \1 (username@hostname.org) left irc: \2/
        }
        # Reformat quit actions (mIRC 6.x)
        /^\[..:..\] \* .*) Quit.*)$/{
                s/Quit/left irc:/1
                s/^\[\(..:..\)\] \*/[\1]/
                s/(//2
                s/)$//
        }

        # Reformat part actions (mIRC 5.x)
        /^\[..:..\] \*\*\* Parts:/{
                s/\*\*\* Parts: //1
                s/) (\(.*\))$/) left irc: \1/
                s/)$/) left irc:/
        }

        # Reformat join actions (mIRC 5.x)
        /^\[..:..\] \*\*\* Joins:/{
                s/\*\*\* Joins: //1
                G
                s/\(.*\)\n\(#.*\)/\1 joined \2./1
        }
        # Reformat join actions (mIRC 6.x)
        /^\[..:..\] \* .*) has joined/{
                s/has //1
                s/^\[\(..:..\)\] \*/[\1]/
                G
                s/\(.*\)\n\(.*joined \)\(#.*\)/\2\1/1
                s/\(.*joined\).*\n\(.*\)/\1 \2/1
                s/$/./
        }

        # Reformat kick actions (mIRC 5.x)
        /^\[..:..\] \*\*\* .*was kicked by.*)$/{
                s/by \(.*\) (/by \1: (/1
                s/was //1
                s/kicked/kicked from /1
                s/^\[\(..:..\)\] \*\*\*/[\1]/
                G 
                s/\(.*from \)\(.*\)\n\(.*\)/\1\3\2/1
                s/(//1
                s/)$//
        }
        # Reformat kick actions (mIRC 6.x)
        /^\[..:..\] \* .*was kicked by.*)$/{
                s/by \(.*\) (/by \1: (/1
                s/was //1
                s/kicked/kicked from /1
                s/^\[\(..:..\)\] \*/[\1]/
                G
                s/\(.*from \)\(.*\)\n\(.*\)/\1\3\2/1
                s/(//1
                s/)$//
        }

        # Delete topic changes made by rejoining servers (mIRC 5.x)
        /^\[..:..\] \*\*\* .*\..*\..*changes topic to/d
        # Delete topic changes made by rejoining servers (mIRC 6.x)
        /^\[..:..\] \* .*\..*\..*changes topic to/d

        # Reformat topic changes, append fake hostmask (mIRC 5.x)
        /^\[..:..\] \*\*\* .*changes topic to/{
                s/ changes topic to/!username@hostname.org:/1
                s/^\[\(..:..\)\] \*\*\*/[\1]/1
                s/^\[\(..:..\)\] /[\1] Topic changed on /1
                G
                s/\(.*on \)\(.*\)\n\(.*\)/\1\3 by \2/1
                s/'//1
                s/'$//
        }
        # Reformat topic changes, append fake hostmask (mIRC 6.x)
        /^\[..:..\] \* .*changes topic to/{
                s/ changes topic to/!username@hostname.org:/1
                s/^\[\(..:..\)\] \*/[\1]/1
                s/^\[\(..:..\)\] /[\1] Topic changed on /1
                G
                s/\(.*on \)\(.*\)\n\(.*\)/\1\3 by \2/1
                s/'//1
                s/'$//
        }

        # Delete mode changes made by rejoining servers (mIRC 5.x)
        /^\[..:..\] \*\*\* .*\..*\..*sets mode: /d
        # Delete mode changes made by rejoining servers (mIRC 6.x)
        /^\[..:..\] \* .*\..*\..*sets mode: /d

        # Reformat multiple mode changes, append fake hostmask (mIRC 5.x)
        /^\[..:..\] \*\*\* .*sets mode: [+-][ovbntsmelkip][+-ovbntsmelkip ]/{
                s/sets mode: //1
                s/^\[\(..:..\)\] \*\*\*/[\1]/
                s/^\[\(..:..\)\] \(.*\) \([+-].*\)/[\1] \2 '\3'/
                G
                s/\] \(.*\) \('.*\)\n\(.*\)/] \3: mode change \2 by \1!username@hostname.org/1
        }
        # Reformat multiple mode changes, append fake hostmask (mIRC 6.x)
        /^\[..:..\] \* .*sets mode: [+-][ovbntsmelkip][+-ovbntsmelkip ]/{
                s/sets mode: //1
                s/^\[\(..:..\)\] \*/[\1]/
                s/^\[\(..:..\)\] \(.*\) \([+-].*\)/[\1] \2 '\3'/
                G
                s/\] \(.*\) \('.*\)\n\(.*\)/] \3: mode change \2 by \1!username@hostname.org/1
        }
        # Reformat single mode changes, append fake hostmask (mIRC 5.x)
        /^\[..:..\] \*\*\* .*sets mode: [+-][imtnselp]$/{
                s/sets mode: //1
                s/^\[\(..:..\)\] \*\*\*/[\1]/
                s/^\[\(..:..\)\] \(.*\) \([+-].*\)/[\1] \2 '\3'/
                G
                s/\] \(.*\) \('.*\)\n\(.*\)/] \3: mode change \2 by \1!username@hostname.org/1
        }
        # Reformat single mode changes, append fake hostmask (mIRC 6.x)
        /^\[..:..\] \* .*sets mode: [+-][imtnselp]$/{
                s/sets mode: //1
                s/^\[\(..:..\)\] \*/[\1]/
                s/^\[\(..:..\)\] \(.*\) \([+-].*\)/[\1] \2 '\3'/
                G
                s/\] \(.*\) \('.*\)\n\(.*\)/] \3: mode change \2 by \1!username@hostname.org/1
        }

        # Remove client-induced crap (mIRC 6.x)
        /^\[..:..\] \* Disconnected/d
        /^\[..:..\] \* Attempting to rejoin/d
        /^\[..:..\] \* Rejoined channel/d
        /^\[..:..\] \* Respond to/d
        /^\[..:..\] \* Retrieving #.*info\.\.\./d
        /^\[..:..\] \* Topic is/d
        /^\[..:..\] \* Set by/d
        /^\[..:..\] \* You/d
        /^\[..:..\] \* \/msg/d
        /^\[..:..\] \* Looking up.*user info/d
        /^\[..:..\] \* Timer vote/d
        /^\[..:..\] \* Break:/d
        /^\[..:..\] \* Waiting.*for previous request/d

        # Reformat actions
        s/^\[\(..:..\)\] \* /[\1] Action: /

        # Remove remaining crap
        /^\[..:..\] \*/d
        /^\[..:..\] \-/{
                /-\{3\} /!d
        }
 
}
