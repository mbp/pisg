# This is a template for creating your own logfile parser.  After making the
# necessary changes to the template, you will need to add the new module to
# pisg.pl and add an entry for it in the choose_log_format subroutine.

package Pisg::Parser::Format::Template;

use strict;
$^W = 1;

# These three variables are regular expressions for extracting information
# from the logfile.  $normalline is for lines where the person merely said
# something, $actionline is for lines where the person performed an action,
# and# $thirdline matches everything else, including things like kicks, nick
# changes, and op grants.  See the thirdline subroutine for a list of
# everything it should match.
my $normalline = '';
my $actionline = '';
my $thirdline  = '';

my ($debug);


# The $debug subroutine needs to be passed to the module so output will go
# to the correct file.
sub new
{
    my $self = shift;
    $debug = shift;
    return bless {};
}

# Parse a normal line - returns a hash with 'hour', 'nick' and 'saying'
sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$normalline/) {
	$debug->("[$lines] Normal: $1 $2 $3");

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

    if ($line =~ /$actionline/) {
	$debug->("[$lines] Action: $1 $2 $3");

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
#   kicker          - the nick which were kicked (if any)
#   newtopic        - the new topic (if any)
#   newmode         - deops or ops, must be '+o' or '-o', or '+ooo'
#   newjoin         - a new nick which has joined the channel
#   newnick         - a person has changed nick and this is the new nick
#
# The hash may also have a "repeated" key indicating the number of times
# the line was repeated.
sub thirdline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$thirdline/) {
	$debug->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7 $8 $9");

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
