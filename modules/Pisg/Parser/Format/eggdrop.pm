package Pisg::Parser::Format::eggdrop;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my $type = shift;
    my $self = {
        debug => $_[0],
        normalline => '^\[(\d+):\d+\] <([^>]+)> (.*)',
        actionline => '^\[(\d+):\d+\] Action: (\S+) (.*)',
        thirdline  => '^\[(\d+):(\d+)\] (\S+) (\S+) (\S+) (\S+)(.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/) {
        $self->{debug}->("[$lines] Normal: $1 $2 $3");

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
        $self->{debug}->("[$lines] Action: $1 $2 $3");

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
        if (defined $7) {
            $self->{debug}->("[$lines] ***: $1 $2 $3 $4 $5 $6 $7");
        } else {
            $self->{debug}->("[$lines] ***: $1 $2 $3 $4 $5 $6");
        }

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $3;

        if (($4.$5) eq 'kickedfrom') {
            $7 =~ /^ by ([\S]+):.*/;
            $hash{kicker} = $1;

        } elsif ($3 eq 'Topic') {
            $7 =~ /^ by ([\S]+)![\S]+: (.*)/;
            $hash{nick} = $1;
            $hash{newtopic} = $2;

        } elsif (($4.$5) eq 'modechange') {
            my $newmode = $6;
            if ($7 =~ /^ .+ by ([\S]+)!.*/) {
                $hash{nick} = $1;
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

        return \%hash;

    } else {
        return;
    }
}

1;
