package Pisg::Parser::Format::rbot;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm
#
use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '\[\d+/\d+/\d+ (\d+):\d+:\d+\] <([^>\s]+)>\s+(.*)',
        actionline => '\[\d+/\d+/\d+ (\d+):\d+:\d+\] \*{1,}\s+(\S+) (.*)',
        thirdline  => '\[\d+/\d+/\d+ (\d+):(\d+):\d+\] @ ([^:\s]+):? ([^:\s]+):? (\S+) (\S+) ?(\S+)? ?(.*)?',
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
	$hash{nick} = $3;
	
	if ($3 and (($3) eq 'Quit')) {
	    $hash{nick} = $4;

	} elsif (($3) eq 'Mode') {
	    
	    if (($4) eq '+o') {
		$hash{newmode} = '+o';
		$hash{nick} = $5;

	    } elsif (($4) eq '-o') {
		$hash{newmode} = '-o';
		$hash{nick} = $5;

	    } elsif (($4) eq '+v') {
		$hash{newmode} = '+v';
		$hash{nick} = $5;

	    } elsif (($4) eq '-v') {
		$hash{newmode} = '-v';
		$hash{nick} = $5;

	    }
		    
	}elsif (($4.$5) eq 'joinedchannel') {
	    $hash{nick} = $3;
	    $hash{newjoin} = $3;

	}elsif (($4.$5) eq 'settopic') {
            my $newtopic;
            if ($8 and $7 and $6) {
                $newtopic = $6.$7.$8;
            } elsif ($7 and $6) {
                $newtopic = $6.$7;
            } else {
                $newtopic = $6;
            }
            $hash{newtopic} = $newtopic;

	}elsif (($4.$5.$6.$7) eq 'isnowknownas') {
	    $hash{nick} = $3;
	    $hash{newnick} = $8;
	}


        return \%hash;

    } else {
        return;
    }
}

1;
