#!/usr/bin/perl -w

# This is a small script which modifies the outputted txt docs into a more
# readable one, by adding some lines to the output.

use strict;

my $cacheword;
while (<>) {
    if ($_ =~ /^(\w+)$/ && $_ !~ /^Name$/) {
        $cacheword = $1;
    }
    if ($_ =~ /^Name$/) {
        print "-----------------------\n$cacheword option\n-----------------------\n";
    } elsif ($_ =~ /^Description$/) {
        print "Description\n-----------\n";
    } elsif ($_ =~ /^Synopsis$/) {
        print "Synopsis\n--------\n";
    } else {
        print $_;
    }

}

