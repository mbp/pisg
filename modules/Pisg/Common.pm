package Pisg::Common;

=head1 NAME

Pisg::Common - some common functions of pisg.

=cut

use Exporter;
@ISA = ('Exporter');
@EXPORT = qw(add_alias add_aliaswild add_ignore add_url_ignore is_ignored url_is_ignored find_alias store_aliases restore_aliases match_urls match_email htmlentities is_nick);

use strict;
$^W = 1;

my (%aliases, %aliaswilds, %ignored, %aliasseen, %ignored_urls, %url_seen);
my (%aliases2, %aliaswilds2, %ignored2, %aliasseen2, %ignored_urls2, %url_seen2);

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
    if ($ignored{$nick}) {
        return 1;
    } elsif ($ignored{find_alias($nick)}) {
        $ignored{$nick} = 1;
    } else {
        $ignored{$nick} = 0;
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

# Sub to do a -cheap- check on wether or not a word is a nick
# This will only match if it has seen it used as a nick
sub is_nick
{
    my ($nick) = @_;
    my $lcnick = lc($nick);

    if ($aliases{$lcnick}) {
        return $aliases{$lcnick};
    } elsif ($aliasseen{$lcnick}) {
        return $aliasseen{$lcnick}
    }
    return 0;
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

sub store_aliases
{
    %aliases2 = %aliases;
    %aliaswilds2 = %aliaswilds;
    %ignored2 = %ignored;
    %aliasseen2 = %aliasseen;
    %ignored_urls2 = %ignored_urls;
    %url_seen2 = %url_seen;
}

sub restore_aliases
{
    %aliases = %aliases2;
    %aliaswilds = %aliaswilds2;
    %ignored = %ignored2;
    %aliasseen = %aliasseen2;
    %ignored_urls = %ignored_urls2;
    %url_seen = %url_seen2;
}

sub match_urls
{
    my $str = shift;

    # Interpret 'www.' as 'http://www.'
    $str =~ s/(http:\/\/)?www\./http:\/\/www\./igo;

    my @urls;
    while ($str =~ s/(http|https|ftp|telnet|news)(:\/\/[-a-zA-Z0-9_\/~]+\.[-a-zA-Z0-9.,_~=:&amp;@%?#\/+]+)//io) { 
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
