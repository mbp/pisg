# package for bobot parsing made by Oct@zoy.org
package Pisg::Parser::Format::bobot;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[[^-]+- ([^:]+):[^\]]+\] <([^>]+)> (.*)$',
        actionline => '^\[[^-]+- ([^:]+):[^\]]+\] \* ([^ ]+) (.*)$',
        thirdline  => '^\[[^-]+- ([^:]+):([^\]]+)\] \*\*\* ([^ ]+) \[[^\]]+\] (.*)$',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/) {

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

    if ($line =~ /$self->{actionline}/) {

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
    if ($line =~ /$self->{thirdline}/) {
        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $3;
        if($4 =~ /^topic ([^ ]+) \((.*)\)$/)
	{
	    $hash{newtopic}= $2;
	} elsif($4 =~ /^mode ([\+-]o+) (.*)$/)
	{
	    $hash{newmode} = $1;
	    $hash{nick} = $2;
	} elsif($4 =~/^kick ([^ ]+) .*$/)
	{
	    $hash{kicker} = $hash{nick};
	    $hash{nick} = $1;
	} elsif($4 =~/^join .*$/)
	{
	    $hash{newjoin} = $hash{nick};
	}

        return \%hash;

    } else {
        return;
    }
}

1;
