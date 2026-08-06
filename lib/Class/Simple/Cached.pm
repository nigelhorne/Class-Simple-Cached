package Class::Simple::Cached;

use strict;
use warnings;
use autodie qw(:all);

use Carp ();
use Class::Simple;
use Params::Get 0.15;
use Scalar::Util ();

# Stored in the cache to distinguish "the object returned undef" from
# "this key has never been cached".  Must never be a legitimate return value.
use constant UNDEF_SENTINEL => __PACKAGE__ . '>UNDEF<';

=head1 NAME

Class::Simple::Cached - cache getter results for any get/set object

=head1 VERSION

Version 0.06

=cut

our $VERSION = '0.06';

=encoding UTF-8

=head1 SYNOPSIS

    use CHI;
    use Class::Simple::Cached;

    # Wrap an existing object with a cache layer
    my $cache = CHI->new(driver => 'RawMemory', global => 1);
    my $obj   = Class::Simple::Cached->new(
        cache  => $cache,
        object => My::Expensive::Object->new(),
    );

    $obj->name('Alice');      # setter: delegates to wrapped object, updates cache
    my $n = $obj->name();     # getter: returns cached 'Alice' without hitting object

    # Or use a plain hash ref as the cache backend
    my %store;
    my $simple = Class::Simple::Cached->new(cache => \%store);
    $simple->colour('blue');
    print $simple->colour();  # 'blue', served from %store

=head1 DESCRIPTION

A subclass of L<Class::Simple> that transparently caches the return values of
getter calls, so that repeated reads of expensive-to-compute or
expensive-to-transport values hit the cache instead of the wrapped object.

Cache coherency is I<not> automatic.  If the wrapped object's state changes
through a path other than the cached wrapper, callers must invalidate the cache
themselves.

=head1 SUBROUTINES/METHODS

=head2 new

Constructs a C<Class::Simple::Cached> instance that wraps C<object> behind
C<cache>.

=head3 ARGUMENTS

=over 4

=item C<cache> (mandatory)

Either a blessed object implementing C<get($key)>, C<set($key, $val, $expires)>,
and C<purge()> (e.g. any L<CHI> driver); or a plain hash reference used as an
in-process store.

=item C<object> (optional)

The object whose methods will be proxied and cached.  Defaults to a fresh
C<Class::Simple> instance.

=back

Calling C<< ->new() >> on an already-blessed instance returns a shallow clone
(all stored fields are merged, including the existing cache handle).

=head3 RETURNS

A blessed C<Class::Simple::Cached> instance.

=head3 SIDE EFFECTS

None beyond allocating the new instance.

=head3 EXAMPLE

    # CHI-backed cache
    use CHI;
    my $obj = Class::Simple::Cached->new(
        cache  => CHI->new(driver => 'RawMemory', global => 1),
        object => My::Model->new(),
    );

    # Hash-ref cache (useful for tests or short-lived objects)
    my $obj = Class::Simple::Cached->new(cache => {});

    # Clone an existing wrapped object
    my $clone = $obj->new();

=head3 API SPECIFICATION

    Input:
      cache  => HashRef | CHICompatibleObject  # required
      object => Object                          # optional

    Output:
      Class::Simple::Cached instance

=head3 MESSAGES

    Message                                              Meaning                              Resolution
    ---------------------------------------------------  -----------------------------------  ----------------------------------------
    "use ->new() not ::new() to instantiate"             Called as Class::Simple::Cached::new  Use $obj->new() or ClassName->new()
    "Usage: $class->new(cache => \$cache)"               No arguments supplied                 Pass at least cache => ...
    "Cache must be ref to HASH or object"                cache is a plain scalar or wrong ref  Use a hashref or CHI-compatible object
    "Cache object must implement get, set, purge"        Blessed cache lacks required methods  Use a fully CHI-compatible object

=head3 PSEUDOCODE

    new(class, args):
      IF class undefined   → carp and return undef
      IF class is blessed  → merge fields, return shallow clone
      IF no args           → croak Usage message
      PARSE args into hashref via Params::Get
      IF params.object absent → params.object = Class::Simple->new()
      IF params.cache is a blessed object:
        VERIFY it can('get') AND can('set') AND can('purge')
        IF not → croak capability message
        RETURN bless params, class
      IF params.cache is a HASH ref:
        RETURN bless params, class
      croak "Cache must be ref to HASH or object"

=cut

sub new
{
	my $class = shift;

	# Guard: always call as a method, not a bare function
	if(!defined($class)) {
		Carp::carp(__PACKAGE__, ' use ->new() not ::new() to instantiate');
		return;
	}

	# When called on a blessed instance, return a shallow clone
	if(Scalar::Util::blessed($class)) {
		my $params = Params::Get::get_params(undef, @_) || {};
		return bless { %{$class}, %{$params} }, ref($class);
	}

	# Require at least one argument so Params::Get's confess is never reached;
	# we want croak (Test::Carp-compatible) not confess.
	if(scalar(@_) == 0) {
		Carp::croak('Usage: ', $class, '->new(cache => $cache)');
	}

	my $params = Params::Get::get_params('cache', @_) || {};

	# Default the wrapped object to a bare Class::Simple instance
	$params->{'object'} ||= Class::Simple->new();

	if(Scalar::Util::blessed($params->{'cache'})) {
		# Verify the cache object speaks the required interface
		unless($params->{'cache'}->can('get')
			&& $params->{'cache'}->can('set')
			&& $params->{'cache'}->can('purge'))
		{
			Carp::croak("Cache object must implement 'get', 'set', and 'purge' methods");
		}
		return bless $params, $class;
	}

	if(ref($params->{'cache'}) eq 'HASH') {
		return bless $params, $class;
	}

	Carp::croak("$class: Cache must be ref to HASH or object");
}

=head2 can

Reports whether this wrapper (or its embedded object) can handle a method.

=head3 ARGUMENTS

=over 4

=item C<$method> — the method name to probe.

=back

=head3 RETURNS

True if the method is known; false otherwise.

=head3 EXAMPLE

    $obj->can('name');   # true if the wrapped object has a name() method

=head3 API SPECIFICATION

    Input:  method_name : Str
    Output: Bool

=head3 MESSAGES

    None.

=cut

sub can
{
	my ($self, $method) = @_;

	# When called as a class method there is no wrapped object to probe
	return $self->SUPER::can($method) unless Scalar::Util::blessed($self);

	return ($method eq 'new')
		|| $self->{'object'}->can($method)
		|| $self->SUPER::can($method);
}

=head2 isa

Reports whether this wrapper or its embedded object is of a given class.

=head3 ARGUMENTS

=over 4

=item C<$class> — the class name to test.

=back

=head3 RETURNS

True if the wrapper or the wrapped object is-a C<$class>.

=head3 EXAMPLE

    $obj->isa('My::Model');   # delegates to the wrapped object

=head3 API SPECIFICATION

    Input:  class_name : Str
    Output: Bool

=head3 MESSAGES

    None.

=cut

sub isa
{
	my ($self, $class) = @_;

	# When called as a class method there is no wrapped object to interrogate
	return $self->SUPER::isa($class) unless Scalar::Util::blessed($self);

	return 1 if $class eq ref($self)
		|| $class eq __PACKAGE__
		|| $self->SUPER::isa($class);

	return $self->{'object'}->isa($class);
}

# DESTROY — purge this instance's entries from the cache on object teardown.
#
# Purpose:      Prevent stale entries from leaking into a shared cache after
#               the wrapper goes out of scope.
# Entry:        Called automatically by Perl's garbage collector.
# Exit Status:  None (void).
# Side Effects: Removes all cache keys prefixed with ref($self) for hash caches;
#               calls purge() for CHI-style caches.
#               See https://github.com/Perl/perl5/issues/14673 for why an
#               explicit DESTROY is required even though AUTOLOAD could catch it.
sub DESTROY
{
	my $self = shift;

	my $cache = $self->{'cache'} or return;

	if(ref($cache) eq 'HASH') {
		# Remove only this class's keys to avoid stomping on siblings sharing the hash
		my $class = ref($self);
		delete $cache->{$_} for grep { index($_, "$class:") == 0 } keys %{$cache};
		return;
	}

	# Skip purge during global destruction to avoid order-of-destruction crashes
	if(defined($^V) && ($^V ge 'v5.14.0')) {
		return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
	}

	$cache->purge();
}

=head2 AUTOLOAD (getter/setter proxy)

Intercepts every method call that is not explicitly defined, proxying it to
the wrapped object with a caching layer for zero-argument (getter) calls.

Setter calls (one or more arguments) always pass through to the wrapped object
and update the cache with the new value.

=head3 ARGUMENTS

    $method()        — getter: returns cached value if present, else calls object
    $method($scalar) — scalar setter: stores scalar, updates cache
    $method(@list)   — array setter: stores list, updates cache

=head3 RETURNS

The value returned by the wrapped object (or the cached copy thereof).

=head3 SIDE EFFECTS

=over 4

=item * Getter: may write to the cache on first call.

=item * Setter: writes to both the wrapped object and the cache.

=item * DESTROY: clears cache entries for this instance (see above).

=back

=head3 EXAMPLE

    $obj->colour('red');    # setter — writes 'red' to object and cache
    $obj->colour();         # getter — returns 'red' from cache

=head3 API SPECIFICATION

    Input (getter):  method_name : Str,  args : ()
    Input (setter):  method_name : Str,  args : (Scalar | List)
    Output:          the stored/retrieved value or list

=head3 MESSAGES

    Message                           Meaning                             Resolution
    --------------------------------  ----------------------------------  ----------------------------------------
    "$method" (croak)                 Cached array's first element is     Do not store the sentinel string
                                      the UNDEF_SENTINEL string           as a real value in the wrapped object

=head3 PSEUDOCODE

    AUTOLOAD(method, args...):
      key = ref(self) + ":" + method

      IF no args (getter mode):
        val = cache_get(key)
        IF cache hit:
          IF val is UNDEF_SENTINEL → return undef
          IF val is an arrayref:
            IF first element is UNDEF_SENTINEL → croak (data collision)
            RETURN dereferenced list
          RETURN scalar val
        # Cache miss — ask the wrapped object
        IF list context:
          result_list = object->method()
          IF empty      → return ()
          cache_set(key, \result_list)
          RETURN result_list
        # Scalar context
        result = object->method()
        IF defined:
          cache_set(key, result)
          RETURN result
        cache_set(key, UNDEF_SENTINEL)
        RETURN undef

      ELSE (setter mode):
        IF more than one arg (array setter):
          val = object->method(\@args)     # wrapped object stores arrayref
          IF defined:
            cache_set(key, val)
            RETURN @val
          cache_set(key, UNDEF_SENTINEL)
          RETURN undef
        ELSE (scalar setter):
          val = object->method(args[0])
          cache_set(key, val // UNDEF_SENTINEL)
          RETURN val

=cut

sub AUTOLOAD
{
	our $AUTOLOAD;
	my ($param) = $AUTOLOAD =~ /::(\w+)$/;

	my $self  = shift;
	my $cache = $self->{'cache'};

	# Getter path ─────────────────────────────────────────────────────────────
	if(scalar(@_) == 0) {
		my $key = ref($self) . ":$param";
		my $object = $self->{'object'};

		# Probe the cache
		my $rc;
		if(ref($cache) eq 'HASH') {
			$rc = $cache->{$key};
		} else {
			$rc = $cache->get($key);
		}

		# Truthiness check: falsy-but-defined values (0, '') are treated as cache
		# misses so the object is re-invoked every call.  This is a known
		# limitation; see the LIMITATIONS section in the POD.
		if($rc) {
			# Sentinel signals the object previously returned undef
			return if $rc eq UNDEF_SENTINEL;

			if(ref($rc) eq 'ARRAY') {
				# Guard: array whose first element collides with our sentinel
				Carp::croak($param) if $rc->[0] eq UNDEF_SENTINEL;
				return @{$rc};
			}
			return $rc;
		}

		# Cache miss — call the real object
		if(wantarray) {
			my @result = $object->$param();
			return unless scalar(@result);	# empty list: don't cache, return ()
			if(ref($cache) eq 'HASH') {
				$cache->{$key} = \@result;
			} else {
				$cache->set($key, \@result, 'never');
			}
			return @result;
		}

		# Scalar / void context
		my $val = $object->$param();
		if(defined($val)) {
			if(ref($cache) eq 'HASH') {
				$cache->{$key} = $val;
			} else {
				$cache->set($key, $val, 'never');
			}
			return $val;
		}

		# Object returned undef — store sentinel so we don't re-call next time
		if(ref($cache) eq 'HASH') {
			$cache->{$key} = UNDEF_SENTINEL;
		} else {
			$cache->set($key, UNDEF_SENTINEL, 'never');
		}
		return;
	}

	# Setter path ─────────────────────────────────────────────────────────────
	my $key    = ref($self) . ":$param";
	my $object = $self->{'object'};

	if(scalar(@_) > 1) {
		# Array setter: pass the list as an arrayref; the wrapped object stores it
		my $val = $object->$param(\@_);
		if(defined($val)) {
			if(ref($cache) eq 'HASH') {
				$cache->{$key} = $val;
			} else {
				$cache->set($key, $val, 'never');
			}
			return @{$val};
		}
		# Object returned undef for this array set
		if(ref($cache) eq 'HASH') {
			$cache->{$key} = UNDEF_SENTINEL;
		} else {
			$cache->set($key, UNDEF_SENTINEL, 'never');
		}
		return;
	}

	# Scalar setter
	my $val = $object->$param($_[0]);
	if(ref($cache) eq 'HASH') {
		$cache->{$key} = defined($val) ? $val : UNDEF_SENTINEL;
	} else {
		# CHI's set() returns the cache object, not the stored value;
		# capture the value before the set call and return it directly
		$cache->set($key, defined($val) ? $val : UNDEF_SENTINEL, 'never');
	}
	return $val;
}

=head1 LIMITATIONS

=over 4

=item Setter arguments are not part of the cache key.

Calls like C<< $obj->method($arg) >> use the key C<ClassName:method> regardless
of C<$arg>.  Setters with different arguments therefore overwrite each other's
cache entries.  For read-only caching of parameterised methods, see
L<Class::Simple::Readonly::Cached>.

=item Falsy scalar return values are not cached.

Methods that return C<0> or C<''> (false but defined) are treated as a cache
miss on every call: the underlying object is re-invoked each time.  Only
C<undef> is cached (via the UNDEF_SENTINEL).  If you need to cache C<0>, wrap
it in a container object or use a different caching strategy.

=item Sentinel collision.

If the wrapped object ever returns the literal string
C<< "Class::Simple::Cached\>UNDEF\<" >> as a scalar, or as the first element of a
list, the module will misinterpret it as a cached-undef marker.  This string is
deliberately unusual, but callers working with arbitrary string data should be
aware of the constraint.

=item Shared cache and multiple classes.

When two C<Class::Simple::Cached> instances of B<different> classes share the
same cache object, their keys are namespaced by class name and do not collide.
However, C<purge()> on a CHI-style cache is global: destroying one instance will
purge I<all> entries from a shared CHI cache, including those of the other
instance.  Use per-instance cache objects, or a hash-ref cache, to avoid this.

=item Does not work with L<Memoize>.

=back

=head1 AUTHOR

Nigel Horne, C<< <njh at nigelhorne.com> >>

=head1 BUGS

Please report bugs and feature requests at
L<https://github.com/nigelhorne/Class-Simple-Cached/issues>.

=head1 SEE ALSO

L<Class::Simple>, L<CHI>, L<Class::Simple::Readonly::Cached>

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

    perldoc Class::Simple::Cached

=over 4

=item * MetaCPAN: L<https://metacpan.org/release/Class-Simple-Cached>

=item * Source: L<https://github.com/nigelhorne/Class-Simple-Cached>

=item * CPANTS: L<http://cpants.cpanauthors.org/dist/Class-Simple-Cached>

=item * Testers Matrix: L<http://matrix.cpantesters.org/?dist=Class-Simple-Cached>

=back

=head1 FORMAL SPECIFICATION

=head2 new

    ─────────────────────────────────────────────────────────────────
    [State]
      cache  : ℙ(HashRef ∪ CHIObject)
      object : Object

    [CHIObject]
      can_get   : Method
      can_set   : Method
      can_purge : Method

    new ──────────────────────────────────────────────────────────────
    Δ(cache, object)
    cache? : HashRef ∪ CHIObject
    object? : Object ∪ {∅}
    ─────────────────────────────────────────────────
    cache? ≠ ∅
    cache ′ = cache?
    object ′ = (object? ≠ ∅ ⟹ object?) ∨ Class::Simple.new()
    ─────────────────────────────────────────────────

=head2 can

    can ──────────────────────────────────────────────────
    Ξ(cache, object)
    method? : MethodName
    ─────────────────────────────────────────────────
    result! = (method? = 'new')
            ∨ object.can(method?)
            ∨ SUPER::can(method?)

=head2 isa

    isa ──────────────────────────────────────────────────
    Ξ(cache, object)
    class? : ClassName
    ─────────────────────────────────────────────────
    result! = (class? = ref(self))
            ∨ (class? = __PACKAGE__)
            ∨ SUPER::isa(class?)
            ∨ object.isa(class?)

=head2 AUTOLOAD

    AUTOLOAD ─────────────────────────────────────────────────────────
    Δ(cache)
    method? : MethodName
    args?   : Seq(Any)
    ─────────────────────────────────────────────────
    key = ref(self) ⊕ ":" ⊕ method?

    Getter (args? = ∅):
      (∃ v • cache_hit(key, v) ∧ v ≠ UNDEF_SENTINEL ⟹ result! = v)
      ∨ (cache_hit(key, UNDEF_SENTINEL)              ⟹ result! = undef)
      ∨ (¬cache_hit(key, _)
          ∧ result! = object.method?()
          ∧ cache′ = cache ∪ {key ↦ encode(result!)})

    Setter (args? ≠ ∅):
      object′.method?(args?) = args?
      cache′ = cache ∪ {key ↦ encode(object′.method?())}
      result! = args?

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2019-2026, Nigel Horne

Usage is subject to the GPL2 licence terms.
If you use it,
please let me know.

=cut

1;
