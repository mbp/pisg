package Pisg::Parser::Format::DCpp;

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[\d+\-\d+\-\d+\s(\d+):\d+\]\s+\<([^>]+)\> (.+)',
        actionline => '^NA',
        thirdline  => '^\[\d+\-\d+\-\d+\s(\d+):(\d+)\]\s+\<([^>]+)\> (.+)',
    };

    $self->{cfg}->{botnicks} .= ' Hub-Security';
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

        if ($self->{cfg}->{botnicks} =~ /\b\Q$hash{nick}\E\b/) {
            return;
        }
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
        my $text    = $4;
        my @line    = split(/\s+/, $text);
        

        # Format-specific stuff goes here.

        if ($self->{cfg}->{botnicks} =~ /\b\Q$hash{nick}\E\b/) {
            
            if (lc($hash{nick}) eq 'hub-security') {
                if (defined $line[3] && $line[1].$line[2] eq 'isin') {
                    $hash{newjoin} = $line[0];
                    $hash{nick} = $hash{newjoin};
                } elsif (defined $line[6] && $line[3].$line[4] eq 'waskicked') {
                    $hash{kicker} = $line[6];
                    $hash{nick} = $line[2];
                }
            }
            return \%hash;
        } else {
            return;
        }

    } else {
        return;
    }
}

1;
