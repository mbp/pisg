package Pisg::Parser::Format::virc98;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm
# Parser for MeGALiTH's Visual IRC 98 on IRCnet (nicks lenght 9 chars)
# by HceZar hcezar@freemail.it
# Fender @ IRCnet #oristano,#italymania

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^(\d+)\.\d+[^ ]+ [<\[](.{1,9})[\]>]\s+(.*)',
        actionline => '^(\d+)\.\d+[^ ]+ \* (\S+) (.*)',
        thirdline  => '^(\d+)\.(\d+)[^ ]+.* \*\*\* (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)(.*)',
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
        
        if (($4.$5) eq 'haskicked') {
            $hash{kicker} = $3;
            $hash{nick} = $6;
		
        } elsif ($4.$5.$6.$7 eq 'haschangedthetopic') {
            $hash{nick} = $3;
            $hash{newtopic} = "$11";

        } elsif (($3.$4) eq 'Modechange') {
            $hash{newmode} = remove_braces($5);
            $hash{nick} = $11;

        } elsif (($5.$6) eq 'hasjoined') {
            $hash{newjoin} = $3;
            $hash{nick} = $3;

        } elsif (($5.$6) eq 'nowknown') {
            $hash{newnick} = $8;
            $hash{nick} = $3;
        }

        return \%hash;

    } else {
        return;
    }
}

sub remove_braces
{
    my $str = shift;
    
    $str =~ s/^\[//;
    
    return $str;
}
1;
