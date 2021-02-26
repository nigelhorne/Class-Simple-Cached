#!perl -wT

use strict;
use warnings;

use Test::Most tests => 2;
use Class::Simple::Cached;

isa_ok(Class::Simple::Cached->new(), 'Class::Simple::Cached', 'Creating Class::Simple::Cached object');
ok(!defined(Class::Simple::Cached::new()));
