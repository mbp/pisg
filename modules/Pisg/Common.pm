package Pisg::Common;

=head1 NAME

Pisg::Common - some common functions of pisg.

=cut

use Exporter;
@ISA = ('Exporter');
@EXPORT = qw(add_alias add_aliaswild add_ignore add_url_ignore is_ignored url_is_ignored find_alias match_urls match_email htmlentities);

use strict;
$^W = 1;

my (%aliases, %aliaswilds, %ignored, %aliasseen, %ignored_urls, %url_seen);

# add_alias assumes that the first argument is the true nick and the second is
# the alias, but will accomidate other arrangements if necessary.
sub add_alias
{
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
    }
}

sub add_aliaswild
{
    my ($nick, $alias) = @_;
    my $lcnick  = lc($nick);
    my $lcalias = lc($alias);

    if (not defined $aliases{$lcnick}) {
        $aliases{$lcnick}  = $nick;
    }
    $aliaswilds{$lcalias} = $nick;
}

sub add_ignore
{
    my $nick = shift;
    $ignored{$nick} = 1;
}

sub is_ignored
{
    my $nick = shift;
    if ($ignored{$nick} or $ignored{find_alias($nick)}) {
        return 1;
    }
}

sub url_is_ignored
{
    my $url = shift;
    if ($ignored_urls{$url}) {
        return 1;
    }
}

sub add_url_ignore
{
    my $url = shift;
    $ignored_urls{$url} = 1;
}

# For efficiency reasons, find_alias() caches aliases when it finds them,
# because the regexp search through %aliaswilds is *really* expensive.
# %aliasseen is used to mark nicks for which nothing matches--we can't add
# such nicks to an actual alias, though, because they might be aliased (e.g.
# by a nick change) later.
sub find_alias
{
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

sub match_urls
{
    my $str = shift;

    # Interpret 'www.' as 'http://www.'
    $str =~ s/(http:\/\/)?www\./http:\/\/www\./ig;

    my @urls;
    while ($str =~ s/(http|https|ftp|telnet|news)(:\/\/[-a-zA-Z0-9_\/~]+\.[-a-zA-Z0-9.,_~=:&amp;@%?#\/+]+)//i) { 
        my $url = "$1$2";
        if ($url_seen{$url}) {
            push(@urls, $url);
        } elsif ($url =~ s/\/$//) {
            if ($url_seen{$url}) {
                push(@urls, $url);
            } else {
                $url_seen{"$url/"} = 1;
                push(@urls, "$url/");
            }
        } elsif ($url_seen{"$url/"}) {
            push(@urls, "$url/");
        } else {
            $url_seen{$url} = 1;
            push(@urls, $url);
        }
    }

    return @urls;
}

sub match_email
{
    my $str = shift;

    if ($str =~ /([-a-zA-Z0-9._]+@[-a-zA-Z0-9_]+\.[-a-zA-Z0-9._]+)/) {
        return $1;
    }
    return undef;
}

sub htmlentities
{
    my $str = shift;

    $str =~ s/\&/\&amp;/go;
    $str =~ s/\</\&lt;/go;
    $str =~ s/\>/\&gt;/go;
    $str =~ s/ü/&uuml;/go;
    $str =~ s/ö/&ouml;/go;
    $str =~ s/ä/&auml;/go;
    $str =~ s/ß/&szlig;/go;
    $str =~ s/å/&aring;/go;
    $str =~ s/æ/&aelig;/go;
    $str =~ s/ø/&oslash;/go;
    $str =~ s/Å/&Aring;/go;
    $str =~ s/Æ/&AElig;/go;
    $str =~ s/Ø/&Oslash;/go;

    return $str;
}

1;
