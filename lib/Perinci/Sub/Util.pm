package Perinci::Sub::Util;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Exporter qw(import);

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(
                       err
                       caller
                       warn_err
                       die_err
                       gen_modified_sub
                       gen_curried_sub
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Helper when writing functions',
};

our $STACK_TRACE;
our @_c; # to store temporary celler() result
our $_i; # temporary variable
sub err {
    require Scalar::Util;

    # get information about caller
    my @caller = CORE::caller(1);
    if (!@caller) {
        # probably called from command-line (-e)
        @caller = ("main", "-e", 1, "program");
    }

    my ($status, $msg, $meta, $prev);

    for (@_) {
        my $ref = ref($_);
        if ($ref eq 'ARRAY') { $prev = $_ }
        elsif ($ref eq 'HASH') { $meta = $_ }
        elsif (!$ref) {
            if (Scalar::Util::looks_like_number($_)) {
                $status = $_;
            } else {
                $msg = $_;
            }
        }
    }

    $status //= 500;
    $msg  //= "$caller[3] failed";
    $meta //= {};
    $meta->{prev} //= $prev if $prev;

    # put information on who produced this error and where/when
    if (!$meta->{logs}) {

        # should we produce a stack trace?
        my $stack_trace;
        {
            no warnings;
            # we use Carp::Always as a sign that user wants stack traces
            last unless $STACK_TRACE // $INC{"Carp/Always.pm"};
            # stack trace is already there in previous result's log
            last if $prev && ref($prev->[3]) eq 'HASH' &&
                ref($prev->[3]{logs}) eq 'ARRAY' &&
                    ref($prev->[3]{logs}[0]) eq 'HASH' &&
                        $prev->[3]{logs}[0]{stack_trace};
            $stack_trace = [];
            $_i = 1;
            while (1) {
                {
                    package DB;
                    @_c = CORE::caller($_i);
                    if (@_c) {
                        $_c[4] = [@DB::args];
                    }
                }
                last unless @_c;
                push @$stack_trace, [@_c];
                $_i++;
            }
        }
        push @{ $meta->{logs} }, {
            type    => 'create',
            time    => time(),
            package => $caller[0],
            file    => $caller[1],
            line    => $caller[2],
            func    => $caller[3],
            ( stack_trace => $stack_trace ) x !!$stack_trace,
        };
    }

    #die;
    [$status, $msg, undef, $meta];
}

sub warn_err {
    require Carp;

    my $res = err(@_);
    Carp::carp("ERROR $res->[0]: $res->[1]");
}

sub die_err {
    require Carp;

    my $res = err(@_);
    Carp::croak("ERROR $res->[0]: $res->[1]");
}

sub caller {
    my $n0 = shift;
    my $n  = $n0 // 0;

    my $pkg = $Perinci::Sub::Wrapper::default_wrapped_package //
        'Perinci::Sub::Wrapped';

    my @r;
    my $i =  0;
    my $j = -1;
    while ($i <= $n+1) { # +1 for this sub itself
        $j++;
        @r = CORE::caller($j);
        last unless @r;
        if ($r[0] eq $pkg && $r[1] =~ /^\(eval /) {
            next;
        }
        $i++;
    }

    return unless @r;
    return defined($n0) ? @r : $r[0];
}

$SPEC{gen_modified_sub} = {
    v => 1.1,
    summary => 'Generate modified metadata (and subroutine) based on another',
    description => <<'_',

Often you'll want to create another sub (and its metadata) based on another, but
with some modifications, e.g. add/remove/rename some arguments, change summary,
add/remove some properties, and so on.

Instead of cloning the Rinci metadata and modify it manually yourself, this
routine provides some shortcuts.

You can specify base sub/metadata using `base_name` (string, subroutine name,
either qualified or not) or `base_code` (coderef) + `base_meta` (hash).

_
    args => {
        die => {
            summary => 'Die upon failure',
            schema => 'bool*',
        },

        base_name => {
            summary => 'Subroutine name (either qualified or not)',
            schema => 'str*',
            description => <<'_',

If not qualified with package name, will be searched in the caller's package.
Rinci metadata will be searched in `%SPEC` package variable.

Alternatively, you can also specify `base_code` and `base_meta`.

Either `base_name` or `base_code` + `base_meta` are required.

_
        },
        base_code => {
            summary => 'Base subroutine code',
            schema  => 'code*',
            description => <<'_',

If you specify this, you'll also need to specify `base_meta`.

Alternatively, you can specify `base_name` instead, to let this routine search
the base subroutine from existing Perl package.

_
        },
        base_meta => {
            summary => 'Base Rinci metadata',
            schema  => 'hash*', # XXX defhash/rifunc
        },
        output_name => {
            summary => 'Where to install the modified sub',
            schema  => 'str*',
            description => <<'_',

Output subroutine will be put in the specified name. If the name is not
qualified with package name, will use caller's package. If the name is not
specified, the base name will be used and must not be from the caller's package.

Note that this argument is optional.

To prevent installing subroutine, set `install_sub` to false.
_
        },
        output_code => {
            summary => 'Code for the modified sub',
            schema  => 'code*',
            description => <<'_',

Alternatively you can use `wrap_code`. If both are not specified, will use
`base_code` (which will then be required) as the modified subroutine's code.

_
        },
        wrap_code => {
            summary => 'Wrapper to generate the modified sub',
            schema  => 'code*',
            description => <<'_',

The modified sub will become:

    sub { wrap_code->(base_code, @_) }

Alternatively you can use `output_code`. If both are not specified, will use
`base_code` (which will then be required) as the modified subroutine's code.

_
        },
        summary => {
            summary => 'Summary for the mod subroutine',
            schema  => 'str*',
        },
        description => {
            summary => 'Description for the mod subroutine',
            schema  => 'str*',
        },
        remove_args => {
            summary => 'List of arguments to remove',
            schema  => 'array*',
        },
        add_args => {
            summary => 'Arguments to add',
            schema  => 'hash*',
        },
        replace_args => {
            summary => 'Arguments to add',
            schema  => 'hash*',
        },
        rename_args => {
            summary => 'Arguments to rename',
            schema  => 'hash*',
        },
        modify_args => {
            summary => 'Arguments to modify',
            description => <<'_',

For each argument you can specify a coderef. The coderef will receive the
argument ($arg_spec) and is expected to modify the argument specification.

_
            schema  => 'hash*',
        },
        modify_meta => {
            summary => 'Specify code to modify metadata',
            schema  => 'code*',
            description => <<'_',

Code will be called with arguments ($meta) where $meta is the cloned Rinci
metadata.

_
        },
        install_sub => {
            schema  => 'bool',
            default => 1,
        },
    },
    args_rels => {
        req_one => [qw/base_name base_code/],
        choose_all => [qw/base_code base_meta/],
    },
    result => {
        schema => ['hash*' => {
            keys => {
                code => ['code*'],
                meta => ['hash*'], # XXX defhash/risub
            },
        }],
    },
};
sub gen_modified_sub {
    require Function::Fallback::CoreOrPP;

    my %args = @_;

    # get base code/meta
    my $caller_pkg = CORE::caller();
    my ($base_code, $base_meta);
    my ($base_pkg, $base_leaf);
    if ($args{base_name}) {
        if ($args{base_name} =~ /(.+)::(.+)/) {
            ($base_pkg, $base_leaf) = ($1, $2);
        } else {
            $base_pkg  = $caller_pkg;
            $base_leaf = $args{base_name};
        }
        {
            no strict 'refs'; ## no critic: TestingAndDebugging::ProhibitNoStrict
            $base_code = \&{"$base_pkg\::$base_leaf"};
            $base_meta = ${"$base_pkg\::SPEC"}{$base_leaf};
        }
        die "Can't find Rinci metadata for $base_pkg\::$base_leaf" unless $base_meta;
    } elsif ($args{base_meta}) {
        $base_meta = $args{base_meta};
        $base_code = $args{base_code}
            or die "Please specify base_code";
    } else {
        die "Please specify base_name or base_code+base_meta";
    }

    my $output_meta = Function::Fallback::CoreOrPP::clone($base_meta);
    my $output_code = ($args{wrap_code} ? sub { $args{wrap_code}->($base_code, @_) } : undef) //
        $args{output_code} // $base_code;

    # modify metadata
    for (qw/summary description/) {
        $output_meta->{$_} = $args{$_} if $args{$_};
    }
    if ($args{remove_args}) {
        delete $output_meta->{args}{$_} for @{ $args{remove_args} };
    }
    if ($args{add_args}) {
        for my $k (keys %{ $args{add_args} }) {
            my $v = $args{add_args}{$k};
            die "Can't add arg '$k' in mod sub: already exists"
                if $output_meta->{args}{$k};
            $output_meta->{args}{$k} = $v;
        }
    }
    if ($args{replace_args}) {
        for my $k (keys %{ $args{replace_args} }) {
            my $v = $args{replace_args}{$k};
            die "Can't replace arg '$k' in mod sub: doesn't exist"
                unless $output_meta->{args}{$k};
            $output_meta->{args}{$k} = $v;
        }
    }
    if ($args{rename_args}) {
        for my $old (keys %{ $args{rename_args} }) {
            my $new = $args{rename_args}{$old};
            my $as = $output_meta->{args}{$old};
            die "Can't rename arg '$old' in mod sub: doesn't exist" unless $as;
            die "Can't rename arg '$old'->'$new' in mod sub: ".
                "new name already exist" if $output_meta->{args}{$new};
            $output_meta->{args}{$new} = $as;
            delete $output_meta->{args}{$old};
        }
    }
    if ($args{modify_args}) {
        for (keys %{ $args{modify_args} }) {
            $args{modify_args}{$_}->($output_meta->{args}{$_});
        }
    }
    if ($args{modify_meta}) {
        $args{modify_meta}->($output_meta);
    }

    # install
    my ($output_pkg, $output_leaf);
    if (!defined $args{output_name}) {
        $output_pkg  = $caller_pkg;
        $output_leaf = $base_leaf;
        if ($base_pkg eq $output_pkg) {
            if ($args{die}) {
                die "Won't override $base_pkg\::$base_leaf";
            } else {
                return [412, "Won't override $base_pkg\::$base_leaf"];
            }
        }
    } elsif ($args{output_name} =~ /(.+)::(.+)/) {
        ($output_pkg, $output_leaf) = ($1, $2);
    } else {
        $output_pkg  = $caller_pkg;
        $output_leaf = $args{output_name};
    }
    {
        no strict 'refs'; ## no critic: TestingAndDebugging::ProhibitNoStrict
        no warnings 'redefine', 'once';
        log_trace "Installing modified sub to $output_pkg\::$output_leaf ...";
        *{"$output_pkg\::$output_leaf"} = $output_code if $args{install_sub} // 1;
        ${"$output_pkg\::SPEC"}{$output_leaf} = $output_meta;
    }

    [200, "OK", {code=>$output_code, meta=>$output_meta}];
}

$SPEC{gen_curried_sub} = {
    v => 1.1,
    summary => 'Generate curried subroutine (and its metadata)',
    description => <<'_',

This is a more convenient helper than `gen_modified_sub` if you want to create a
new subroutine that has some of its arguments preset (so they no longer need to
be present in the new metadata).

For more general needs of modifying a subroutine (e.g. add some arguments,
modify some arguments, etc) use `gen_modified_sub`.

_
    args => {
        base_name => {
            summary => 'Subroutine name (either qualified or not)',
            schema => 'str*',
            description => <<'_',

If not qualified with package name, will be searched in the caller's package.
Rinci metadata will be searched in `%SPEC` package variable.

_
            req => 1,
            pos => 0,
        },
        set_args => {
            summary => 'Arguments to set',
            schema  => 'hash*',
            req => 1,
            pos => 1,
        },
        output_name => {
            summary => 'Where to install the modified sub',
            schema  => 'str*',
            description => <<'_',

Subroutine will be put in the specified name. If the name is not qualified with
package name, will use caller's package. If the name is not specified, will use
the base name which must not be in the caller's package.

_
            pos => 2,
        },
    },
    args_as => 'array',
    result_naked => 1,
};
sub gen_curried_sub {
    my ($base_name, $set_args, $output_name) = @_;

    my $caller = CORE::caller();

    my ($base_pkg, $base_leaf);
    if ($base_name =~ /(.+)::(.+)/) {
        ($base_pkg, $base_leaf) = ($1, $2);
    } else {
        $base_pkg  = $caller;
        $base_leaf = $base_name;
    }

    my ($output_pkg, $output_leaf);
    if (!defined $output_name) {
        die "Won't override $base_pkg\::$base_leaf" if $base_pkg eq $caller;
        $output_pkg = $caller;
        $output_leaf = $base_leaf;
    } elsif ($output_name =~ /(.+)::(.+)/) {
        ($output_pkg, $output_leaf) = ($1, $2);
    } else {
        $output_pkg  = $caller;
        $output_leaf = $output_name;
    }

    my $base_sub = \&{"$base_pkg\::$base_leaf"};

    gen_modified_sub(
        die         => 1,
        base_name   => "$base_pkg\::$base_leaf",
        output_name => "$output_pkg\::$output_leaf",
        output_code => sub {
            no strict 'refs'; ## no critic: TestingAndDebugging::ProhibitNoStrict
            $base_sub->(@_, %$set_args);
        },
        remove_args => [keys %$set_args],
        install => 1,
    );
}

1;
# ABSTRACT:

=head1 SYNOPSIS

Example for err() and caller():

 use Perinci::Sub::Util qw(err caller);

 sub foo {
     my %args = @_;
     my $res;

     my $caller = caller();

     $res = bar(...);
     return err($err, 500, "Can't foo") if $res->[0] != 200;

     [200, "OK"];
 }

Example for die_err() and warn_err():

 use Perinci::Sub::Util qw(warn_err die_err);
 warn_err(403, "Forbidden");
 die_err(403, "Forbidden");

Example for gen_modified_sub():

 use Perinci::Sub::Util qw(gen_modified_sub);

 $SPEC{list_users} = {
     v => 1.1,
     args => {
         search => {},
         is_suspended => {},
     },
 };
 sub list_users { ... }

 gen_modified_sub(
     output_name => 'list_suspended_users',
     base_name   => 'list_users',
     remove_args => ['is_suspended'],
     output_code => sub {
         list_users(@_, is_suspended=>1);
     },
 );

Example for gen_curried_sub():

 use Perinci::Sub::Util qw(gen_curried_sub);

 $SPEC{list_users} = {
     v => 1.1,
     args => {
         search => {},
         is_suspended => {},
     },
 };
 sub list_users { ... }

 # simpler/shorter than gen_modified_sub, but can be used for currying only
 gen_curried_sub('list_users', {is_suspended=>1}, 'list_suspended_users');


=head1 append:FUNCTIONS

=head2 caller([ $n ])

Just like Perl's builtin caller(), except that this one will ignore wrapper code
in the call stack. You should use this if your code is potentially wrapped. See
L<Perinci::Sub::Wrapper> for more details.

=head2 err(...) => ARRAY

Experimental.

Generate an enveloped error response (see L<Rinci::function>). Can accept
arguments in an unordered fashion, by utilizing the fact that status codes are
always integers, messages are strings, result metadata are hashes, and previous
error responses are arrays. Error responses also seldom contain actual result.
Status code defaults to 500, status message will default to "FUNC failed". This
function will also fill the information in the C<logs> result metadata.

Examples:

 err();    # => [500, "FUNC failed", undef, {...}];
 err(404); # => [404, "FUNC failed", undef, {...}];
 err(404, "Not found"); # => [404, "Not found", ...]
 err("Not found", 404); # => [404, "Not found", ...]; # order doesn't matter
 err([404, "Prev error"]); # => [500, "FUNC failed", undef,
                           #     {logs=>[...], prev=>[404, "Prev error"]}]

Will put C<stack_trace> in logs only if C<Carp::Always> module is loaded.

=head2 warn_err(...)

This is a shortcut for:

 $res = err(...);
 warn "ERROR $res->[0]: $res->[1]";

=head2 die_err(...)

This is a shortcut for:

 $res = err(...);
 die "ERROR $res->[0]: $res->[1]";


=head1 FAQ

=head2 What if I want to put result ($res->[2]) into my result with err()?

You can do something like this:

 my $err = err(...) if ERROR_CONDITION;
 $err->[2] = SOME_RESULT;
 return $err;


=head1 SEE ALSO

L<Perinci>

=cut
