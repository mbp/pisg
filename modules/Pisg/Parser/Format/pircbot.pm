package Pisg::Parser::Format::pircbot;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $ctcpchr = chr(1);

    my $self = {
        cfg => $args{cfg},
        normalline => '^(\d+)\s:([^!]+)![^@]+@\S+\sPRIVMSG\s([#&+!]\S+)\s:([^' . $ctcpchr . '].*)$'
                      . '|' .
                      '^(\d+)\s(>>>)PRIVMSG\s([#&+!]\S+)\s:([^' . $ctcpchr . '].*)$',
        actionline => '^(\d+)\s:([^!]+)![^@]+@\S+\sPRIVMSG\s([#&+!]\S+)\s:' . $ctcpchr . 'ACTION (.+)' . $ctcpchr . '\s*$'
                      . '|' . 
                      '^(\d+)\s(>>>)PRIVMSG\s([#&+!]\S+)\s:' . $ctcpchr . 'ACTION (.+)' . $ctcpchr . '\s*$',
	thirdline  => '^(\d+)\s:([^!]+)![^@]+@\S+\s(.+)$'
                      . '|' .
                      '^(\d+)\s(>>>)([^P].+)$',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {
        if (defined($8)) {
            return unless (lc($7) eq lc($self->{cfg}->{channel}));

            my @time = localtime($5 / 1000);
            $hash{hour}   = $time[2];
            $hash{nick}   = $6;
            $hash{saying} = $8;
        } else {
            return unless (lc($3) eq lc($self->{cfg}->{channel}));

            my @time = localtime($1 / 1000);
            $hash{hour}   = $time[2];
            $hash{nick}   = $2;
            $hash{saying} = $4;
        }

        $hash{nick}   = $self->{cfg}->{maintainer}
          if ($hash{nick} eq '>>>');

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
        if (defined($8)) {
            return unless (lc($7) eq lc($self->{cfg}->{channel}));

            my @time = localtime($5 / 1000);
            $hash{hour}   = $time[2];
            $hash{nick}   = $6;
            $hash{saying} = $8;
        } else {
            return unless (lc($3) eq lc($self->{cfg}->{channel}));

            my @time = localtime($1 / 1000);
            $hash{hour}   = $time[2];
            $hash{nick}   = $2;
            $hash{saying} = $4;
        }

        $hash{nick}   = $self->{cfg}->{maintainer}
          if ($hash{nick} eq '>>>');

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
        my ($time, @line);
        if (defined($6)) {
            my @time = localtime($4 / 1000);
            $hash{hour}   = $time[2];
            $hash{min}  = $time[1];
            $hash{nick} = $self->{cfg}->{maintainer};

            @line = split(/\s+/, $6);
        } else {
            my @time = localtime($1 / 1000);
            $hash{hour}   = $time[2];
            $hash{min}  = $time[1];
            $hash{nick} = $2;

            @line = split(/\s+/, $3);
        }

        if ($line[0] eq 'KICK') {
            return unless (lc($line[1]) eq lc($self->{cfg}->{channel}));
            $hash{kicker} = $hash{nick};
            $hash{nick} = $line[2];

        } elsif ($line[0] eq 'TOPIC') {
            return unless (lc($line[1]) eq lc($self->{cfg}->{channel}));
            $hash{newtopic} = join(' ', @line[2..$#line]);
            $hash{newtopic} =~ s/^://;

        } elsif ($line[0] eq 'MODE') {
            return unless (lc($line[1]) eq lc($self->{cfg}->{channel}));
            $hash{newmode} = join(' ', @line[2..$#line]);

        } elsif ($line[0] eq 'JOIN') {
            return unless (lc($line[1]) eq ':' . lc($self->{cfg}->{channel}));
            $hash{newjoin} = $hash{nick};

        } elsif ($line[0] eq 'NICK') {
            $hash{newnick} = $line[1];
            $hash{newnick} =~ s/^://;
        }


        return \%hash;

    } else {
        return;
    }
}

1;
