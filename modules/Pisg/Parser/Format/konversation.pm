package Pisg::Parser::Format::konversation;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
		normalline => '^\[[^\[]+\[(\d+)[^\]]+\]\s+<([^>]+)>\s+(.*)$',
		actionline => '^\[[^\[]+\[(\d+)[^\]]+\]\s+\*\s(\S+)\s(.*)$',
		thirdline  => '^\[[^\[]+\[(\d+):(\d+)[^\]]+\]\s(\S+)\s+(\S+)\s(.*)$',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {
        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $3;

        return \%hash;
    } else {
        return;
    }
}

sub actionline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o) {
        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $3;

        return \%hash;
    } else {
        return;
    }
}

sub thirdline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {
        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $4;

		if ($4 eq 'You') {
			# Hack to remove You as a nick
			$hash{nick} = $self->{cfg}->{maintainer};
		}

		if ($3 eq 'Mode') {
			$hash{newmode} = $5;
			$hash{newmode} =~ s/^[^+-]*//;

		} elsif ($3 eq 'Join') {
			$hash{newjoin} = $4;

		} elsif ($3 eq 'Nick') {
			$hash{newnick} = $5;
			$hash{newnick} =~ s/^.*\s+(\S+)$/$1/;

		} elsif ($3 eq 'Kick') {
			if ($5 =~ /^have kicked (\S+) from the channel \((.+)\).$/ ) {
				$hash{kicker} = $hash{nick};
				$hash{nick} = $1;
				$hash{kicktext} = $2;
			} elsif ($5 =~ /^has been kicked from the channel by (\S+) \((.+)\).$/ ) {
				$hash{kicker} = $1;
				$hash{kicktext} = $2;
			} else {
				return;
			}

		} elsif ($3 eq 'Topic') {
			if ($5 =~ /the channel topic to "(.*)"\.$/) {
				$hash{newtopic} = $1;
			} else {
				return;
			}
		
		}
		
        return \%hash;

    } else {
        return;
    }
}

1;
