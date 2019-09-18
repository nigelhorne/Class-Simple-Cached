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

A sub-class of L<Simple::Cached> which caches calls to read
the status of an object that are otherwise expensive.

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	return unless(defined($class));

	my %args;
	if(ref($_[0]) eq 'HASH') {
		%args = %{$_[0]};
	} elsif(ref($_[0])) {
		Carp::croak('Usage: ', __PACKAGE__, '->new(cache => $cache, %args)');
	} elsif(@_ % 2 == 0) {
		%args = @_;
	}

	Carp::croak('Usage: ', __PACKAGE__, '->new(cache => $cache, %args)') unless($args{'cache'});
	return bless \%args, $class;
}

sub _caller_class
{
	my $self = shift;

	# return $self->SUPER::_caller_class(@_);
	return $self->Class::Simple::_caller_class(@_);
}

sub AUTOLOAD {
	our $AUTOLOAD;
	my $param = $AUTOLOAD;

	$param =~ s/.*:://;

	return if($param eq 'DESTROY');
	my $self = shift;

	if($param !~ /^[gs]et_/) {
		my $cache = $self->{'cache'};

		if(scalar(@_) == 0) {
			if(my $rc = $cache->get($param)) {
				return $rc;
			}
		}

		# $param = "SUPER::$param";
		my $func = "Class::Simple::$param";
		# return $cache->set($param, $self->$param(@_), 'never');
		return $cache->set($param, $self->$func(@_), 'never');
	}
	# $param = "SUPER::$param";
	$param = "Class::Simple::$param";
	$self->$param(@_);
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

L<Class::Simple>

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
