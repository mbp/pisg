# This is a template for blootbot logs http://blootbot.sf.net/
# hacked up by Tim Riker <Tim@Rikers.org>

package Pisg::Parser::Format::blootbot;

use strict;
$^W = 1;

# The 3 variables in the new subrountine, 'normalline', 'actionline' and
# 'thirdline' represents regular expressions for extracting information from
# the logfile. normalline is for lines where the person merely said
# something, actionline is for lines where the person performed an action,
# and thirdline matches everything else, including things like kicks, nick
# changes, and op grants.  See the thirdline subroutine for a list of
# everything it should match.


# blootbot puts hh:mm.ss at the start.
# note that one log can contain more than one channel.
# FIXME it would be nice if pisg would process them all in one pass!
#
# Normal lines are like:
#
# 01:02.03 <nick/#channel> normal
# 01:02.03 * nick/#channel action

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^(\d\d):\d\d\.\d\d <([^\/]+)\/(#[^>]+)> (.*)',
        actionline => '^(\d\d):\d\d\.\d\d \* (.*)/(#\S*) (.*)',
        thirdline  => '^(\d\d):(\d\d)\.\d\d >>> (.*)',
    };

    bless($self, $type);
    return $self;
}

# Parse a normal line - returns a hash with 'hour', 'nick' and 'saying'
sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o and
            lc $3 eq lc $self->{cfg}->{channel}) {

        # Most log formats are regular enough that you can just match the
        # appropriate things with parentheses in the regular expression.

        $hash{hour} = $1;
        $hash{nick} = $2;
        $hash{channel} = $3;
        $hash{saying} = $4;

        return \%hash;
    } else {
        return;
    }
}

# Parse an action line - returns a hash with 'hour', 'nick' and 'saying'
sub actionline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o and
            lc $3 eq lc $self->{cfg}->{channel}) {

        # Most log formats are regular enough that you can just match the
        # appropriate things with parentheses in the regular expression.

        $hash{hour} = $1;
        $hash{nick} = $2;
        $hash{channel} = $3;
        $hash{saying} = $4;

        return \%hash;
    } else {
        return;
    }
}

# Parses the 'third' line - (the third line is everything else, like
# topic changes, mode changes, kicks, etc.)
# thirdline() has to return a hash with the following keys, for
# every format:
#   hour            - the hour we're in (for timestamp logging)
#   min             - the minute we're in (for timestamp logging)
#   nick            - the nick
#   kicker          - the nick which kicked somebody (if any)
#   newtopic        - the new topic (if any)
#   newmode         - deops or ops, must be '+o' or '-o', or '+ooo'
#   newjoin         - a new nick which has joined the channel
#   newnick         - a person has changed nick and this is the new nick
# 
# It should return a hash with the following (for formatting lines in html)
#
#   kicktext        - the kick reason (if any)
#   modechanges     - data of the mode change ('Nick' in '+o Nick')
#
# The hash may also have a "repeated" key indicating the number of times
# the line was repeated. (Used by eggdrops log for example.)
sub thirdline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

        $hash{hour} = $1;
        $hash{min}  = $2;

        # Format-specific stuff goes here.

        if ($3 =~ /^topic\/(#\S*) by (\S*) -> (.*)/) {
            # 01:02.03 >>> topic/#channel by nick -> topic...
            $hash{channel} = $1;
            $hash{nick} = $2;
            $hash{newtopic} = "$3";
        
        } elsif ($3 =~ /^mode\/(#\S*) \[([\+\-]o*) (.*)\] by (\S*)/) {
            # 01:02.03 >>> mode/#channel [+o nick] by ChanServ
            $hash{channel} = $1;
            $hash{newmode} = $2;
            $hash{modechanges} = $3;
            $hash{nick} = $4;
            
        } elsif ($3 =~ /^join\/(#\S*) (\S*) \(\S*\)/) {
            # 01:02.03 >>> join/#channel nick (~user@example.com)
            $hash{channel} = $1;
            $hash{newjoin} = $2;
        
        } elsif ($3 =~ /^kick\/(#\S*) \[(\S*)!.*\] by (\S*) \((.*\))/) {
            # 01:02.03 >>> kick/#channel [nick!~user@example.com] by nick (reason)
            $hash{channel} = $1;
            $hash{nick} = $2;
            $hash{kicker} = $3;
            $hash{kicktext} = $4;

        } elsif ($3 =~ /^(\S*) materializes into (\S*)/) {
            # 01:02.03 >>> nick_ materializes into nick
            $hash{nick} = $1;
            $hash{newnick} = $2;
            # no channel so return now
            return \%hash;
        }
        return \%hash if ($hash{channel} and lc $hash{channel} eq lc $self->{cfg}->{channel});
        return;

    } else {
        return;
    }
}

1;
