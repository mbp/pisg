package Pisg::Parser::Format::dancer;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^(\d+)\.\S+ \# \s+ <([^>]+)> (.*)',
        actionline => '^(\d+)\.\S+ \# \s+ \* (\S+) (.*)',
        thirdline  => '^(\d+)\.(\d+)\.\S+ ([^#>* ]+)\s+ (.*)'
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

	if($3 eq 'Kick') {
	    $4 =~ /\(\S+ (\S+) .*?\) by (\S+)\!/o;
	    $hash{nick} = $1;
	    $hash{kicker} = $2;
	} elsif($3 eq 'Topic') {
	    $4 =~ /\"(.*)\" by (\S+) /o;
	    $hash{newtopic} = $1;
	    $hash{nick} = $2;
	} elsif($3 eq 'Mode') {
	    $4 =~ /\S+ (\S+) .*\" by (\S+) /o;
	    $hash{newmode} = $1;
	    $hash{nick} = $2;
	} elsif($3 eq 'Join') {
	    $4 =~ /(\S+) (\S+) /o;
	    $hash{nick} = $1;
	    $hash{newjoin} = $1;
	} elsif($3 eq 'Nick') {
	    $4 =~ /(\S+) is now known as (\S+) /o;
	    $hash{nick} = $1;
	    $hash{newnick} = $2;
	}
        return \%hash;

    } else {
        return;
    }
}

1;
