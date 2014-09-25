package Perinci::Sub::Util::ResObj;

# DATE
# VERSION

use Carp;
use overload
    q("") => sub {
        my $res = shift; "ERROR $err->[0]: $err->[1]\n" . Carp::longmess();
    };

1;
# ABSTRACT: An object that represents enveloped response suitable for die()-ing

=head1 SYNOPSIS

Currently unused. See L<Perinci::Sub::Util>'s C<warn_err> and C<die_err>
instead.

