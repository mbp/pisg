package Pisg::Parser::Format::xchat;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

# This module supports both the old and new logformat (after 1.8.7)

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '(\d+):\d+:\d+ <([^>\s]+)>\s+(.*)',
        actionline => '(\d+):\d+:\d+ (\*){1,}\s+(\S+) (.*)',
        thirdline  => '(\d+):(\d+):\d+ .{1,}--\s+(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {

        $hash{hour} = $1;
        $hash{nick} = $2;
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

        $hash{hour} = $1;
        $hash{nick} = $2;
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
        $hash{min} = $2;
        $hash{nick} = $3;

        if (($4.$5) eq 'haskicked') {
            $hash{kicker} = $3;
            $hash{nick} = $6;

        } elsif (($4.$5) eq 'haschanged') {
            $hash{newtopic} = $9;

        } elsif (($4.$5) eq 'giveschannel') {
            $hash{newmode} = '+o';

        } elsif (($4.$5) eq 'removeschannel') {
            $hash{newmode} = '-o';

        } elsif (($5.$6) eq 'hasjoined') {
            $hash{newjoin} = $1;

        } elsif (($5.$6) eq 'nowknown') {
            $hash{newnick} = $8;

        } elsif (($3.$4.$6) eq 'Topicforis') {
            $self->{topictemp} = $9;
            $hash{newtopic} = $9;

        } elsif (($3.$4.$6) eq 'Topicforset') {
            $hash{nick} = $8;
            $hash{newtopic} =  $self->{topictemp};

        }

        return \%hash;

    } else {
        return;
    }
}

1;
