package Perinci::Sub::Util::Sort;

use 5.010;
use strict;
use warnings;

use Exporter qw(import);

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(
                       sort_args
               );

our %SPEC;

sub sort_args {
    my $args = shift;
    sort {
        (($args->{$a}{pos} // 9999) <=> ($args->{$b}{pos} // 9999)) ||
            $a cmp $b
        } keys %$args;
}

1;
# ABSTRACT: Sort routines

=head1 SYNOPSIS

 use Perinci::Sub::Util::Sort qw(sort_args);

 my $meta = {
     v => 1.1,
     args => {
         a1 => { pos=>0 },
         a2 => { pos=>1 },
         opt1 => {},
         opt2 => {},
     },
 };
 my @args = sort_args($meta->{args}); # ('a1','a2','opt1','opt2')


=head1 FUNCTIONS

=head2 sort_args(\%args) => LIST

Sort argument in args property by pos, then by name.
