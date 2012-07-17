package Log::Any::For::Package;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';
use Module::Patch 0.07 qw(patch_package);
use SHARYANTO::Package::Util qw(package_exists);

# VERSION

#use Sub::Uplevel;

our %SPEC;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(add_logging_to_package);

sub _default_precall_logger {
    my $args = shift;
    #uplevel 2, $args->{orig}, @{$args->{args}};

    $log->tracef("---> %s(%s)", $args->{name}, $args->{args});
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

$SPEC{add_logging_to_package} = {
    v => 1.1,
    summary => 'Add logging to package',
    description => <<'_',

Logging will be done using Log::Any.

Currently this function adds logging around function calls, e.g.:

    -> Package::func(...)
    <- Package::func() = RESULT
    ...

_
    args => {
        packages => {
            summary => 'Packages to add logging to',
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

You can use this mechanism to customize logging.

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

You can use this mechanism to customize logging.

_
        },
        filter_subs => {
            summary => 'Filter subroutines to add logging to',
            schema => 'regex*',
            description => <<'_',

The default is to add logging to all non-private subroutines. Private
subroutines are those prefixed by `_`.

_
        },
    },
    result_naked => 1,
};
sub add_logging_to_package {
    my %args = @_;

    patch_package(
        $args{packages},
        [{
            action => 'wrap',
            sub_name => ($args{filter_subs} // ':public'),
            code => sub {
                my $ctx  = shift;
                my $orig = shift;

                my @args = @_;
                my %largs = (
                    orig   => $orig,
                    name   => $ctx->{orig_name},
                    args   => [@args],
                );

                my $logger;

                $logger = $args{precall_logger} // \&_default_precall_logger;
                $logger->(\%largs);

                my $wa = wantarray;
                my @res;
                if ($wa) {
                    @res =  $orig->(@args);
                } elsif (defined $wa) {
                    $res[0] = $orig->(@args);
                } else {
                    $orig->(@args);
                }

                $logger = $args{postcall_logger} // \&_default_postcall_logger;
                $largs{result} = \@res;
                $logger->(\%largs);

                if ($wa) {
                    return @res;
                } elsif (defined $wa) {
                    return $res[0];
                } else {
                    return;
                }
            },
        }]
    );
}

1;
# ABSTRACT: Add logging to package

=head1 SYNOPSIS

 use My::Module;
 use My::Other::Module;
 use Log::Any::For::Package qw(add_logging_to_package);

 my $h = add_logging_to_package(packages => [qw/My::Module My::Other::Module/]);

 # now calls to your module functions are logged, by default at level 'trace'
 My::Module::foo(...);

 # restore original subroutines
 undef $h;


=head1 SEE ALSO

L<Log::Any::For::Class>

=cut
