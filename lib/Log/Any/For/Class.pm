package Log::Any::For::Class;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

use Scalar::Util qw(blessed);
# doesn't currently work, Log::Log4perl not fooled
#use Sub::Uplevel;

our %SPEC;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(add_logging_to_class);

# XXX copied from SHARYANTO::Package::Util
sub package_exists {
    no strict 'refs';

    my $pkg = shift;

    return unless $pkg =~ /\A\w+(::\w+)*\z/;
    if ($pkg =~ s/::(\w+)\z//) {
        return !!${$pkg . "::"}{$1 . "::"};
    } else {
        return !!$::{$pkg . "::"};
    }
}

sub _default_precall_logger {
    my %args  = @_;
    my $name  = $args{name};
    my $margs = $args{args};

    #uplevel 2, $args{orig}, @$margs;

    # exclude $self or package
    my $o = shift @$margs;

    unless (blessed $o) {
        $name =~ s/::(\w+)$/->$1/;
    }

    $log->tracef("---> %s(%s)", $name, $margs);
}

sub _default_postcall_logger {
    my %args = @_;
    #uplevel 2, $args{orig}, @{$args{args}};

    $log->tracef("<--- %s() = %s", $args{name}, $args{result});
}

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

    for my $class (@$classes) {

        die "Invalid class name $class" unless $class =~ /\A\w+(::\w+)*\z/;

        # require class
        unless (package_exists($class)) {
            eval "use $class; 1" or die "Can't load $class: $@";
        }

        my $src;
        # get the calling package symbol table name
        {
            no strict 'refs';
            $src = \%{ $class . '::' };
        }

        # loop through all symbols in calling package, looking for subs
        for my $symbol (keys %$src) {
            # get all code references, make sure they're valid
            my $sub = *{ $src->{$symbol} }{CODE};
            next unless defined $sub and defined &$sub;

            # save all other slots of the typeglob
            my @slots;

            for my $slot (qw( SCALAR ARRAY HASH IO FORMAT )) {
                my $elem = *{ $src->{$symbol} }{$slot};
                next unless defined $elem;
                push @slots, $elem;
            }

            # clear out the source glob
            undef $src->{$symbol};

            # replace the sub in the source
            $src->{$symbol} = sub {
                my $logger;
                my @args = @_;

                $logger = $args{precall_logger} // \&_default_precall_logger;
                $logger->(
                    orig   => $sub,
                    name   => "${class}::$symbol",
                    args   => [@args],
                );

                my $wa = wantarray;
                my @res;
                if ($wa) {
                    @res =  $sub->(@args);
                } else {
                    $res[0] = $sub->(@args);
                }

                $logger = $args{postcall_logger} // \&_default_postcall_logger;
                $logger->(
                    orig   => $sub,
                    name   => "${class}::$symbol",
                    args   => [@args],
                    result => \@res,
                );

                if ($wa) {
                    return @res;
                } else {
                    return $res[0];
                }
            };

            # replace the other slot elements
            for my $elem (@slots) {
                $src->{$symbol} = $elem;
            }
        } # for $symbol

    } # for $class

    1;
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
