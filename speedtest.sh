#!/bin/sh

# This is a small, but very useful script for finding out where to speedup a
# Perl program, it will generate a fine statistics on which functions used
# the most time, and how many calls which were made to it.
#
# I hope someone will use this and hopefully make pisg a bit faster :)

dprofpp -u -p ./pisg
