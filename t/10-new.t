#!perl -wT

use strict;
use warnings;

use Test::Most tests => 4;

BEGIN {
	use_ok('Class::Simple::Cached');
}

ok(!defined(Class::Simple::Cached->new()));
isa_ok(Class::Simple::Cached->new(cache => {}), 'Class::Simple::Cached', 'Creating Class::Simple::Cached object');
ok(!defined(Class::Simple::Cached::new()));
