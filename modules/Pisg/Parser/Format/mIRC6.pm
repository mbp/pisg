package Pisg::Parser::Format::mIRC6;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[(\d+):\d+:?\d*\] <([^>]+)> (.*)',
        thirdline  => '^\[(\d+):(\d+):?\d*\] \* (.+)'
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
        $hash{nick}   = remove_prefix($2);
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

    return $self->thirdline($line, $lines, 1);
}

sub thirdline
{
    my ($self, $line, $lines, $action) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

        my @line = split(/\s/, $3);

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{saying}  = $3;
        $hash{nick} = remove_prefix($line[0]);

        if ($#line >= 4 && ($line[1].$line[2]) eq 'waskicked' && ($line[$#line] =~ /\)$/)) {
                $hash{kicker} = $line[4];

        } elsif ($#line >= 4 && ($line[1].$line[2]) eq 'werekicked' && ($line[$#line] =~ /\)$/)) {
                $hash{kicker} = $line[4];
                $hash{nick} = $self->{cfg}{maintainer};

        } elsif ($#line >= 4 && ($line[1] eq 'changes') && ($line[$#line] =~ /\'$/)) {
                $hash{newtopic} = join(' ', @line[4..$#line]);
                $hash{newtopic} =~ s/^'//;
                $hash{newtopic} =~ s/'$//;

        } elsif ($#line >= 3 && ($line[1].$line[2]) eq 'setsmode:') {
            $hash{newmode} = $line[3];

        } elsif ($#line == 3 && ($line[1].$line[2]) eq 'hasjoined') {
            $hash{newjoin} = $line[0];

        } elsif ($#line == 5 && ($line[2].$line[3]) eq 'nowknown') {
            $hash{newnick} = $line[5];

        } elsif ($action) {
            if (
                ($hash{saying} =~ /^Set by \S+ on \S+ \S+ \d+ \d+:\d+:\d+/) ||
                ($hash{saying} =~ /^Now talking in #\S+/) ||  
                ($hash{saying} =~ /^Topic is \'.*\'/) ||  
                ($hash{saying} =~ /^Disconnected/) ||  
                ($hash{saying} =~ /^\S+ has quit IRC \(.+\)/) ||  
                ($hash{saying} =~ /^Retrieving #\S+ info\.\.\./)
              ) {
                return 0;
            } else {
                $hash{saying} =~ s/^\Q$hash{nick}\E //;
                return \%hash;
            }

        } else {
            return;
        }

        return \%hash
            unless ($action);

    }
    return;
}

sub remove_prefix
{
    my $str = shift;

    $str =~ s/^@//;
    $str =~ s/^\+//;
    $str =~ s/^%//;

    return $str;
}

1;
