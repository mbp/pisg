package Pisg::Parser::Format::mIRC;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[(\d+):\d+[^ ]+ <([^>]+)> (.*)',
        actionline => '^\[(\d+):\d+[^ ]+ \* (\S+) (.*)',
        thirdline  => '^\[(\d+):(\d+)[^ ]+ \*\*\* (\S+) (\S+) (\S+) (\S+) (\S+)(.*)',
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

    if ($line =~ /$self->{actionline}/o) {

        $hash{hour}   = $1;
        $hash{nick}   = remove_prefix($2);
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
        $hash{nick} = remove_prefix($3);

        if (($4.$5) eq 'waskicked') {
            $hash{kicker} = $7;

        } elsif ($4 eq 'changes') {
            $hash{newtopic} = "$7 $8";

        } elsif (($4.$5) eq 'setsmode:') {
            $hash{newmode} = $6;

        } elsif (($5.$6) eq 'hasjoined') {
            $hash{newjoin} = $3;

        } elsif (($4.$5) eq 'nowknown') {
            $hash{newnick} = $8;
        }

        return \%hash;

    } else {
        return;
    }
}

sub remove_prefix
{
    my $str = shift;

    $str =~ s/^@//;
    $str =~ s/^\+//;

    return $str;

}

1;
