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
