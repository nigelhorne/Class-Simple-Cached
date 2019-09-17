package Class::Simple::Cached;

use strict;
use warnings;
use Class::Simple;

our @ISA = ('Class::Simple');

=head1 NAME

Class::Simple::Cached - cache messages to an object

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

A sub-class of L<Simple::Cached> which caches calls to read
the status of an object that are otherwise expensive.

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {
	my ($proto, %param) = @_;
	my $class = ref($proto) || $proto;

	return unless(defined($class));

	return bless { }, $class;
}

1;
