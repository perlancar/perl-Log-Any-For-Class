package Log::Any::For::Class;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

use Data::Clone;
use Scalar::Util qw(blessed);
use Log::Any::For::Package qw(add_logging_to_package);

our %SPEC;

sub import {
    my $class = shift;

    for my $arg (@_) {
        if ($arg eq 'add_logging_to_class') {
            no strict 'refs';
            my @c = caller(0);
            *{"$c[0]::$arg"} = \&$arg;
        } else {
            add_logging_to_class(packages => [$arg]);
        }
    }
}

sub _default_precall_logger {
    my $args  = shift;
    my $margs = $args->{args};

    # exclude $self or package
    $margs->[0] = '$self' if blessed($margs->[0]);

    Log::Any::For::Package::_default_precall_logger($args);
}

sub _default_postcall_logger {
    my $args = shift;

    Log::Any::For::Package::_default_postcall_logger($args);
}

my $spec = clone $Log::Any::For::Package::SPEC{add_logging_to_package};
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

    if (!$args{precall_logger}) {
        $args{precall_logger} = \&_default_precall_logger;
        $args{logger_args}{precall_wrapper_depth} = 3;
    }
    if (!$args{postcall_logger}) {
        $args{postcall_logger} = \&_default_postcall_logger;
        $args{logger_args}{postcall_wrapper_depth} = 3;
    }
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


=head1 DESCRIPTION

Most of the things that apply to L<Log::Any::For::Package> also applies to this
module, since this module uses add_logging_to_package() as its backend.


=head1 SEE ALSO

L<Log::Any::For::Package>

L<Log::Any::For::DBI>, an application of this module.

=cut
