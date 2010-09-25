package Pisg::Parser::Format::eggdrop;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\[(\d+):\d+(?:\:\d+)?\] <([^>]+)> (.*)$',
        actionline => '^\[(\d+):\d+(?:\:\d+)?\] Action: (\S+) (.*)$',
        thirdline  => '^\[(\d+):(\d+)(?:\:\d+)?\] (\S+) (\S+) (\S+) (\S+)(.*)$',
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

        if (($4.$5) eq 'kickedfrom') {
            $7 =~ /^ by ([\S]+):\s*(.*)/;
            $hash{kicktext} = $2;
            $1 =~ /([^!]+)/;    # Remove anything after the !
            $hash{kicker} = $1;

        } elsif ($3 eq 'Topic') {
            $7 =~ /^ by (\S*)!(\S+): (.*)/;
            $hash{nick} = $1 || $2; # $1 might be empty if topic is reset by server
            $hash{newtopic} = $3;

        } elsif (($4.$5) eq 'modechange') {
            my $newmode = $6;
            if ($7 =~ /^ (.+) by ([\S]+)!.*/) {
                $hash{modechanges} = $2;
                $hash{nick} = $2;
                $newmode =~ s/^\'//;
                $hash{newmode} = $newmode;
            }

        } elsif ($5 eq 'joined') {
            $hash{newjoin} = $3;

        } elsif (($3.$4) eq 'Nickchange:') {
            $hash{nick} = $5;
            $7 =~ /([\S]+)/;
            $hash{newnick} = $1;

        } elsif (($3.$4.$5) eq 'Lastmessagerepeated') {
            $hash{repeated} = $6;
        }

        $hash{nick} =~ /([^!]+)/;
        $hash{nick} = $1;
        return \%hash;

    } else {
        return;
    }
}

1;
