# This is a template for creating your own logfile parser. You can also look
# in the other .pm files in this directory as good examples.

package Pisg::Parser::Format::Template;

use strict;
$^W = 1;

# The 3 variables in the new subrountine, 'normalline', 'actionline' and
# 'thirdline' represents regular expressions for extracting information from
# the logfile. normalline is for lines where the person merely said
# something, actionline is for lines where the person performed an action,
# and thirdline matches everything else, including things like kicks, nick
# changes, and op grants.  See the thirdline subroutine for a list of
# everything it should match.

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '',
        actionline => '',
        thirdline  => '',
    };

    bless($self, $type);
    return $self;
}

# Parse a normal line - returns a hash with 'hour', 'nick' and 'saying'
sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {

        # Most log formats are regular enough that you can just match the
        # appropriate things with parentheses in the regular expression.

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $3;

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

    if ($line =~ /$self->{actionline}/o) {

        # Most log formats are regular enough that you can just match the
        # appropriate things with parentheses in the regular expression.

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $3;

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
        $hash{nick} = $3;

        # Format-specific stuff goes here.

        return \%hash;

    } else {
        return;
    }
}

1;
