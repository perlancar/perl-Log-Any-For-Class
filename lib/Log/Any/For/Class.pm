package Log::Any::For::Class;

use 5.010;
use strict;
use warnings;

# VERSION

use Sub::Uplevel;

our %SPEC;
our @EXPORT_OK = qw(add_logging_to_class);

$SPEC{add_logging_to_class} = {
    v => 1.1,
    summary => 'Add logging to class',
    description => <<'_',

Logging will be done using Log::Any.

Currently this function adds logging around method calls, e.g.:

    -> Package::method(...)
    <- Package::method() = RESULT
    ...

_
    args => {
        classes => {
            summary => 'Classes to add logging to',
            schema => ['array*' => {of=>'str*'}],
            req => 1,
            pos => 0,
        },
        precall_logger => {
            summary => 'Supply custom precall logger',
            schema  => 'code*',
            description => <<'_',

Code will be called when logging method call. Code will be given a hash argument
%args containing these keys: `args` (arrayref, the original @_), `orig`
(coderef, the original method), `name` (string, the fully-qualified method
name).

You can use this mechanism to do selective logging, preprocess log message, etc.

_
        },
        postcall_logger => {
            summary => 'Supply custom postcall logger',
            schema  => 'code*',
            description => <<'_',

Just like precall_logger, but code will be called after method is call. Code
will be given a hash argument %args containing these keys: `args` (arrayref, the
original @_), `orig` (coderef, the original method), `name` (string, the
fully-qualified method name), `result` (arrayref, the method result).

You can use this mechanism to do selective logging, preprocess log message,
etc.

_
        },
    },
    result_naked => 1,
};
sub add_logging_to_class {
    my %args = @_;

    my $classes = $args{classes} or die "Please specify 'classes'";
    $classes = [$classes] unless ref($classes) eq 'ARRAY';

}

sub _wrap_symbol
{
	my ($traced, $logger) = @_;
	my $src;

	# get the calling package symbol table name
	{
		no strict 'refs';
		$src = \%{ $traced . '::' };
	}

	# loop through all symbols in calling package, looking for subs
	for my $symbol ( keys %$src )
	{
		# get all code references, make sure they're valid
		my $sub = *{ $src->{$symbol} }{CODE};
		next unless defined $sub and defined &$sub;

		# save all other slots of the typeglob
		my @slots;

		for my $slot (qw( SCALAR ARRAY HASH IO FORMAT ))
		{
			my $elem = *{ $src->{$symbol} }{$slot};
			next unless defined $elem;
			push @slots, $elem;
		}

		# clear out the source glob
		undef $src->{$symbol};

		# replace the sub in the source
		$src->{$symbol} = sub
		{
			my @args = @_;
			_log_call->(
				name   => "${traced}::$symbol",
				logger => $logger,
				args   => [ @_ ]
			);
			return $sub->(@_);
		};

		# replace the other slot elements
		for my $elem (@slots)
		{
			$src->{$symbol} = $elem;
		}
	}
}

{
	my $logger = sub { require Carp; Carp::carp( join ', ', @_ ) };

	# set a callback sub for logging
	sub callback
	{
		# should allow this to be a class method :)
		shift if @_ > 1;

		my $coderef = shift;
		unless( ref($coderef) eq 'CODE' and defined(&$coderef) )
		{
			require Carp;
			Carp::croak( "$coderef is not a code reference!" );
		}

		$logger = $coderef;
	}

	# where logging actually happens
	sub _log_call
	{
		my %args    = @_;
		my $log_sub = $args{logger} || $logger;

		$log_sub->( $args{name}, @{ $args{args} });
	}
}

1;
# ABSTRACT: Add logging to class

=head1 SYNOPSIS

 use Log::Any::For::Class qw(add_logging_to_class);
 add_logging_to_class(classes => [qw/My::Class My::SubClass/]);
 # now method calls to your classes are logged, by default at level 'trace'


=head1 CREDITS

Some code portion taken from L<Devel::TraceMethods>.


=head1 SEE ALSO

L<Log::Any::For::DBI>, an application for this module.

=cut
