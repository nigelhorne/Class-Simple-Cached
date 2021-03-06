#!perl -w

use warnings;
use strict;

use Test::Most;

unless($ENV{AUTHOR_TESTING}) {
	plan(skip_all => 'Author tests not required for installation');
}

eval "use Test::Prereq";
plan(skip_all => 'Test::Prereq required to test dependencies') if $@;
prereq_ok();
