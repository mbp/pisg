package Pisg::Common;

# pisg - Perl IRC Statistics Generator
#
# Copyright (C) 2001-2005  <Morten Brix Pedersen> - morten@wtf.dk
# Copyright (C) 2003-2005  Christoph Berg <cb@df7cb.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=head1 NAME

Pisg::Common - some common functions of pisg.

=cut

use Exporter;
@ISA = ('Exporter');
@EXPORT = qw(add_alias add_aliaswild add_ignore add_url_ignore is_ignored url_is_ignored find_alias store_aliases restore_aliases match_urls match_email htmlentities urlencode is_nick randomglob wordlist_regexp);

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
    } elsif ($ignored{is_nick($nick)}) {
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
    my ($nick, $wilds) = @_;
    my $lcnick = lc($nick);

    if ($aliases{$lcnick}) {
        return $aliases{$lcnick};
    } elsif ($aliasseen{$lcnick}) {
        return $aliasseen{$lcnick}
    }

    # check aliaswilds if were are in _mostusedword()
    if (defined $wilds) {
        foreach (keys %aliaswilds) {
            if ($lcnick =~ /^$_$/i) {
                add_alias($aliaswilds{$_}, $lcnick);
                return $aliaswilds{$_};
            }
        }
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

    my @urls;
    # we don't treat mailto: as URL here
    while ($str =~ /((?:(?:https?|ftp|telnet|news):\/\/|(?:(?:(www)|(ftp))[\w-]*\.))[-\w\/~\@:]+\.\S+[\w\/])/gio) {
        my $url = $2 ? "http://$1" : ($3 ? "ftp://$1" : $1);
        my $url_strip = $url;
        $url_strip =~ s/\/$//;
        $url_seen{$url_strip} ||= $url; # normalize URL to first seen form
        push (@urls, $url_seen{$url_strip});
    }

    return @urls;
}

sub htmlentities
{
    my $str = shift;
    my $charset = shift;

    return $str unless $str;

    $str =~ s/\&/\&amp;/go;
    $str =~ s/\</\&lt;/go;
    $str =~ s/\>/\&gt;/go;
    if ($charset and $charset =~ /iso-8859-1/i) { # this is for people without Text::Iconv
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
        $str =~ s/\x95/\&bull;/go;
    }
    return $str;
}

sub urlencode
{
    my $str = shift;
    $str =~ s/([^\w_.\/?=:+-])/sprintf "%%%02X", ord($1)/ge;
    return $str;
}

sub randomglob
{
    my ($pattern, $globpath, $nick) = @_;
    return $pattern unless $pattern =~ /[*?]/;
    my @globs = glob $globpath . $pattern;
    my $return = $globs[int(rand(@globs))];
    unless($return) {
        print STDERR "Warning: picture $globpath$pattern for $nick not found\n";
        return $pattern;
    }
    $return =~ s/^$globpath//;
    return $return;
}

sub wordlist_regexp
{
    my $list = shift;
    $list =~ s/^\s+//; # split ignores trailing empty fields
    my @words = split(/\s+/, $list);
    my $regexpaliases = shift;
    unless($regexpaliases) {
        map {
            $_ = quotemeta; # quote everything
            s/\\\*/\\S*/g; # replace \*
            s/^\\S\*// or $_ = "\\b$_"; # ... but remote it at beginning/end of word
            s/\\S\*$// or $_ = "$_\\b";
        } @words;
    }
    return join '|', @words;
}

1;
