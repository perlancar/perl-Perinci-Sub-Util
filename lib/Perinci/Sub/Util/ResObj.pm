package Perinci::Sub::Util::ResObj;

use strict;
use Carp;

use overload
    q("") => sub {
        my $res = shift; "ERROR $res->[0]: $res->[1]\n" . Carp::longmess();
    };

# AUTHORITY
# DATE
# DIST
# VERSION

1;
# ABSTRACT: An object that represents enveloped response suitable for die()-ing

=head1 SYNOPSIS

Currently unused. See L<Perinci::Sub::Util>'s C<warn_err> and C<die_err>
instead.
