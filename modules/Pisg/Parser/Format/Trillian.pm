package Pisg::Parser::Format::Trillian;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

# old format:
# [hh:mm] <nick> says something
# new v3 format:
# [hh:mm] nick: says something

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[(\d+):\d+[^ ]+ <?([^*:>]+)[^ ]+ (.*)',
        actionline => '^\[(\d+):\d+[^ ]+ \* (\S+) (.*)',
        thirdline  => '^\[(\d+):(\d+)[^ ]+ \*{3}\s(.+)',
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
        ($hash{nick}  = $2) =~ s/^[@%\+~&]//o; # Remove prefix
        $hash{saying} = $3;
        $hash{saying} =~ s/\(Link: (((http|https|ftp|telnet|news):\/\/|).*?)\)\1/$1/;

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
        ($hash{nick}  = $2) =~ s/^[@%\+~&]//o; # Remove prefix
        $hash{saying} = $3;
        $hash{saying} =~ s/\(Link: (((http|https|ftp|telnet|news):\/\/|).*?)\)\1/$1/;

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
        ($hash{nick}  = $3) =~ s/^[@%\+~&]//o; # Remove prefix

        if ($3 =~ /^(\S+) has been kicked off channel (\S+) by (\S+) .+/) {
            ($hash{nick}  = $1) =~ s/^[@%\+~&]//o; # Remove prefix
            $hash{kicker} = $3;

        } elsif ($3 =~ /^(\S+) has changed the topic on channel (\S+) to (.+)/) {
            ($hash{nick}  = $1) =~ s/^[@%\+~&]//o; # Remove prefix
             $hash{newtopic} = $3;

        } elsif ($3 =~ /^Mode change \"(\S+)[^\"]+\".+ by (.+)$/) {
            ($hash{nick}  = $2) =~ s/^[@%\+~&]//o; # Remove prefix
             $hash{newmode} = $1;

        } elsif ($3 =~ /^(\S+) \S+ has joined channel \S+/) {
            $hash{nick} = $1;
            $hash{newjoin} = $1;

        } elsif ($3 =~ /^(\S+) is now known as (\S+)/) {
            ($hash{nick}  = $1) =~ s/^[@%\+~&]//o; # Remove prefix
            $hash{newnick} = $2;
        }

        return \%hash;

    } else {
        return;
    }
}

1;
