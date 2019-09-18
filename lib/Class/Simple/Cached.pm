package Class::Simple::Cached;

use strict;
use warnings;
use Carp;
use Class::Simple;

my @ISA = ('Class::Simple');

=head1 NAME

Class::Simple::Cached - cache messages to an object

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

A sub-class of L<Class::Simple> which caches calls to read
the status of an object that are otherwise expensive.

It is up to the caller to maintain the cache if the object comes out of sync with the cache,
for example by changing its state.

=head1 SUBROUTINES/METHODS

=head2 new

Creates a Class::Simple::Cached object.

It takes one manadatory parameter: cache,
which is an object which understands get() and set() calls,
such as an L<CHI> object.

It takes one optional argument: super,
which is an object which is taken to be the object to be cached.
If not given, an object of the class L<Class::Simple> is instantiated
and that is used.

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	return unless(defined($class));

	my %args;
	if(ref($_[0]) eq 'HASH') {
		%args = %{$_[0]};
	} elsif(ref($_[0])) {
		Carp::croak('Usage: ', __PACKAGE__, '->new(cache => $cache [, super => $super ], %args)');
	} elsif(@_ % 2 == 0) {
		%args = @_;
	}

	if(!defined($args{'super'})) {
		$args{'super'} = Class::Simple->new();
	}

	Carp::croak('Usage: ', __PACKAGE__, '->new(cache => $cache [, super => $super ], %args)') unless($args{'cache'});
	return bless \%args, $class;
}

sub _caller_class
{
	my $self = shift;

	if($self->{'super'} && ($self->{'super'} eq 'Class::Simple')) {
		# return $self->SUPER::_caller_class(@_);
		return $self->Class::Simple::_caller_class(@_);
	}
}

sub AUTOLOAD {
	our $AUTOLOAD;
	my $param = $AUTOLOAD;

	$param =~ s/.*:://;

	return if($param eq 'DESTROY');
	my $self = shift;
	# my $func = $self->{'super'} . "::$param";
	my $func = $param;
	my $super = $self->{'super'};

	if($param !~ /^[gs]et_/) {
		my $cache = $self->{'cache'};

		if(scalar(@_) == 0) {
			if(my $rc = $cache->get($param)) {
				return $rc;
			}
		}

		# $param = "SUPER::$param";
		# return $cache->set($param, $self->$param(@_), 'never');
		return $cache->set($param, $super->$func(@_), 'never');
	}
	# $param = "SUPER::$param";
	$super->$func(@_);
}

=head1 AUTHOR

Nigel Horne, C<< <njh at bandsman.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-class-simple-cached at rt.cpan.org>,
or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Class-Simple-Cached>.
I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

params() returns a ref which means that calling routines can change the hash
for other routines.
Take a local copy before making amendments to the table if you don't want unexpected
things to happen.

=head1 SEE ALSO

L<Class::Simple>, L<CHI>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Class::Simple::Cached

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Simple-Cached>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Class-Simple-Cached>

=item * Search CPAN

L<http://search.cpan.org/dist/Class-Simple-Cached/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2019 Nigel Horne.

This program is released under the following licence: GPL2

=cut

1;
