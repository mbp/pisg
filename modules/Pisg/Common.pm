package Pisg::Common;

use Exporter;
@ISA = ('Exporter');
@EXPORT = qw(add_alias add_aliaswild add_ignore is_ignored find_alias match_url match_email);

use strict;
$^W = 1;

my ($conf, $debug);
my (%aliases, %aliaswilds, %ignored, %aliasseen);

sub init_common {
#    $conf = shift;
    $debug = shift;
}

# add_alias assumes that the first argument is the true nick and the second is
# the alias, but will accomidate other arrangements if necessary.
sub add_alias {
    my ($nick, $alias) = @_;
    my $lcnick  = lc($nick);
    my $lcalias = lc($alias);

    if (not defined $aliases{$lcnick}) {
        if (not defined $aliases{$lcalias}) {
            $aliases{$lcnick}  = $nick;
            $aliases{$lcalias} = $nick;
        } else {
            $aliases{$lcnick} = $aliases{$lcalias};
        }
    } elsif (not defined $aliases{$lcalias}) {
        $aliases{$lcalias} = $aliases{$lcnick};
    } elsif ($aliases{$lcnick} ne $aliases{$lcalias}) {
	$debug->("Alias collision: alias $alias -> $aliases{$lcalias} but nick $nick -> $aliases{$lcnick}");
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
    $debug->("Aliaswild added: $alias -> $aliaswilds{$lcalias}");
}

sub add_ignore {
    my $nick = shift;
    $ignored{$nick} = 1;
}

sub is_ignored {
    my $nick = shift;
    if ($ignored{$nick} || $ignored{find_alias($nick)}) {
        return 1;
    }
}

# For efficiency reasons, find_alias() caches aliases when it finds them,
# because the regexp search through %aliaswilds is *really* expensive.
# %aliasseen is used to mark nicks for which nothing matches--we can't add
# such nicks to an actual alias, though, because they might be aliased (e.g.
# by a nick change) later.
sub find_alias {
    my ($nick) = @_;
    my $lcnick = lc($nick);

    if ($aliases{$lcnick}) {
        return $aliases{$lcnick};
    } elsif ($aliasseen{$lcnick}) {
	return $aliasseen{$lcnick};
    } else {
        foreach (keys %aliaswilds) {
            if ($nick =~ /^$_$/i) {
                add_alias($aliaswilds{$_}, $lcnick);
                return $aliaswilds{$_};
            }
        }
    }
    $aliasseen{$lcnick} = $nick;
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
