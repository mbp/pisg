package Pisg::Common;

use Exporter;
@ISA = ('Exporter');
@EXPORT = qw(add_alias add_aliaswild add_ignore is_ignored find_alias match_url match_email);

use strict;
$^W = 1;

my (%aliases, %aliaswilds, @ignored);

# add_alias assumes that the first argument is the true nick and the second is
# the alias, but will accomidate other arrangements if necessary.
sub add_alias {
    my ($nick, $alias) = @_;
    my $lcnick  = lc($nick);
    my $lcalias = lc($alias);

    if (not defined $aliases{$lcnick} and not defined $aliases{$lcalias}) {
        $aliases{$lcnick}  = $nick;
        $aliases{$lcalias} = $nick;
    } elsif (defined $aliases{$lcnick} and not defined $aliases{$lcalias}) {
        $aliases{$lcalias} = $aliases{$lcnick};
    } elsif (not defined $aliases{$lcnick} and defined $aliases{$lcalias}) {
        $aliases{$lcnick} = $aliases{$lcalias};
    } else { # Both are defined.
        # If both point to the same nick, all is well.  Otherwise, redefine
        # the alias's alias.
        if ($aliases{$lcnick} ne $aliases{$lcalias}) {
            $aliases{$lcalias} = $aliases{$lcnick};
        }
    }
    #$debug->("Alias added: $alias -> $aliases{$lcalias}");
}

sub add_aliaswild {
    my ($nick, $alias) = @_;
    my $lcnick  = lc($nick);
    my $lcalias = lc($alias);

    if (not defined $aliases{$lcnick}) {
        $aliases{$lcnick}  = $nick;
    }
    $aliaswilds{$lcalias} = $nick;
    #$debug->("Aliaswild added: $alias -> $aliaswilds{$lcalias}");
}

sub add_ignore {
    my ($nick) = @_;
    push @ignored, find_alias($nick);
}

sub is_ignored {
    my ($nick) = @_;
    my $realnick = find_alias($nick);
    return grep /^\Q$realnick\E$/, @ignored;
}

sub find_alias {
    my $nick = shift;
    my $lcnick = lc($nick);

    if ($aliases{$lcnick}) {
        return $aliases{$lcnick};
    } else {
        foreach (keys %aliaswilds) {
            if ($nick =~ /^$_$/i) {
                add_alias($aliaswilds{$_}, $lcnick);
                return $aliaswilds{$_};
            }
        }
    }
    add_alias($nick, $nick);
    return $nick;
}

sub match_url {
    my ($str) = @_;

    if ($str =~ /(http|https|ftp|telnet|news)(:\/\/[-a-zA-Z0-9_]+\.[-a-zA-Z0-9.,_~=:;&@%?#\/+]+)/) {
        return "$1$2";
    }
    return undef;
}

sub match_email {
    my ($str) = @_;

    if ($str =~ /([-a-zA-Z0-9._]+@[-a-zA-Z0-9_]+\.[-a-zA-Z0-9._]+)/) {
        return $1;
    }
    return undef;
}

1;
