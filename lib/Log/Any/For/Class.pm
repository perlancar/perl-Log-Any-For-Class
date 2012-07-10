package Log::Any::For::Class;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

use Data::Clone;
use Scalar::Util qw(blessed);
# doesn't currently work, Log::Log4perl not fooled
#use Sub::Uplevel;

our %SPEC;
require Exporter;
use Log::Any::For::Package qw(add_logging_to_package);
our @ISA = qw(Log::Any::For::Package Exporter);
our @EXPORT_OK = qw(add_logging_to_class);

sub _default_precall_logger {
    my $args  = shift;
    my $margs = $args->{args};

    #uplevel 2, $args->{orig}, @$margs;

    # exclude $self or package
    $margs->[0] = '$self' if blessed($margs->[0]);

    $log->tracef("---> %s(%s)", $args->{name}, $margs);
}

sub _default_postcall_logger {
    my $args = shift;
    #uplevel 2, $args->{orig}, @{$args->{args}};

    if (@{$args->{result}}) {
        $log->tracef("<--- %s() = %s", $args->{name}, $args->{result});
    } else {
        $log->tracef("<--- %s()", $args->{name});
    }
}

my $spec = $Log::Any::For::Package::SPEC{add_logging_to_package};
$spec->{summary} = 'Add logging to class';
$spec->{description} = <<'_';

Logging will be done using Log::Any.

Currently this function adds logging around method calls, e.g.:

    -> Class::method(...)
    <- Class::method() = RESULT
    ...

_
delete $spec->{args}{packages};
$spec->{args}{classes} = {
    summary => 'Classes to add logging to',
    schema => ['array*' => {of=>'str*'}],
    req => 1,
    pos => 0,
};
delete $spec->{args}{filter_subs};
$spec->{args}{filter_methods} = {
    summary => 'Filter methods to add logging to',
    schema => ['array*' => {of=>'str*'}],
    description => <<'_',

The default is to add logging to all non-private methods. Private methods are
those prefixed by `_`.

_
};
$SPEC{add_logging_to_class} = $spec;
sub add_logging_to_class {
    my %args = @_;

    my $classes = $args{classes} or die "Please specify 'classes'";
    $classes = [$classes] unless ref($classes) eq 'ARRAY';
    delete $args{classes};

    my $filter_methods = $args{filter_methods};
    delete $args{filter_methods};

    $args{precall_logger}  //= \&_default_precall_logger;
    $args{postcall_logger} //= \&_default_postcall_logger;

    add_logging_to_package(
        %args,
        packages => $classes,
        filter_subs => $filter_methods,
    );
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

L<Log::Any::For::Package>

L<Log::Any::For::DBI>, an application of this module.

=cut
