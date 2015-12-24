package Perinci::Sub::Util::PropertyModule;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(
                       get_required_property_modules
               );

sub get_required_property_modules {
    no warnings 'once';
    no warnings 'redefine';

    my $meta = shift;

    # Here's how it works: first we reset the
    # $Sah::Schema::Rinci::SCHEMAS{rinci_function} (well the whole SCHEMAS hash)
    # structure which contains the list of supported properties. This is done by
    # emptying it and force-reloading the Sah::Schema::Rinci module, which is
    # the module responsible for declaring the structure.
    #
    # We also delete Perinci::Sub::Property::* entries from %INC to force-reload
    # them. We then record %INC at this point (1).
    #
    # Then we run $meta to normalize_function_data(), which will load additional
    # Perinci::Sub::Property::* modules that are needed.
    #
    # Finally we compare the previous content %INC (at point (1)) with the
    # current %INC. We now get the list of required Perinci::Sub::Property::*
    # modules.

    %Sah::Schema::Rinci::SCHEMAS = ();
    delete $INC{'Sah/Schema/Rinci.pm'};
    require Sah::Schema::Rinci;

    for (grep {m!^Perinci/Sub/Property/!} keys %INC) {
        delete $INC{$_};
    }

    require Perinci::Sub::Normalize;

    my %inc_before = %INC;
    Perinci::Sub::Normalize::normalize_function_metadata($meta);

    my %res;
    for (keys %INC) {
        next unless m!^Perinci/Sub/Property/!;
        next if $inc_before{$_};
        $res{$_} = 1;
    }

    [map {my $mod = $_; $mod =~ s!/!::!g; $mod =~ s/\.pm\z//; $mod}
         sort keys %res];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

 use Perinci::Sub::Util::PropertyModule qw(get_required_property_modules);

 my $meta = {
     v => 1.1,
     args => {
         foo => {
             ...
             'form.widget' => '...',
         },
         bar => {},
     },
     'cmdline.skip_format' => 1,
     result => {
         table => { ... },
     },
 };
 my $mods = get_required_property_modules($meta);

Result:

 ['Perinci::Sub::Property::arg::form',
  'Perinci::Sub::Property::cmdline',
  'Perinci::Sub::Property::result::table']


=head1 FUNCTIONS

=head2 get_required_property_modules($meta) => array

Since the Perinci framework is modular, additional properties can be introduced
by additional property modules (C<Perinci::Sub::Property::*>). These properties
might be experimental, 3rd party, etc.

This function can detect which modules are used.

This function can be used during distribution building to automatically add
those modules as prerequisites.
