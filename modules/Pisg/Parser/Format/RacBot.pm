package Pisg::Parser::Format::RacBot;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[(\d+):\d+:\d+\]\s+<([^>]+)> (.*)',
        actionline => '^\[(\d+):\d+:\d+\]\s+\*(\S+)\s+(.*)',
        thirdline  => '^\[(\d+):(\d+):\d+\]\s+([^-\$!#].*)',
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
        my @line = split /\s+/, $3;
        if ($#line >= 5 && $line[1].$line[2].$line[3] eq 'hasbeenkicked') {
            ($hash{kicker} = $line[5]) =~ s/!.*$//;
            ($hash{nick} = $line[0]) =~ s/!.*$//;
        } elsif ($line[0].$line[1] eq 'Topicchanged') {
            if ($line[2] eq 'to') {
                $hash{newtopic} = join ' ', @line[3 .. ($#line-2)];
                $hash{newtopic} =~ s/^"//;
                $hash{newtopic} =~ s/"$//;
                ($hash{nick} = $line[$#line]) =~ s/!.*$//;
            } elsif ($line[2] eq 'on') {
                $hash{newtopic} = join ' ', @line[7 .. $#line];
                $hash{newtopic} =~ s/^"//;
                $hash{newtopic} =~ s/"$//;
                ($hash{nick} = $line[5]) =~ s/!.*$//;
            } else {
                return;
            }
        } elsif ($#line >= 4 && $line[2].$line[3] eq 'hasjoined') {
            $hash{newjoin} = $line[0];
        } elsif ($#line >= 5 && $line[1].$line[2].$line[3].$line[4] eq 'isnowknownas') {
             $hash{newnick} = $line[5];
             $hash{nick} = $line[0];
        } elsif ($line[0].$line[$#line-1] eq 'MODEby') {
            ($hash{nick} = $line[$#line]) =~ s/!.*$//;
            $hash{newmode} = $line[1];
            $hash{newmode} =~ s/^"//;
        } else {
            return;
        }
        return \%hash;

    } else {
        return;
    }
}

1;
