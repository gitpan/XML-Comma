package XML::Comma::Util::DefModule;
use XML::Comma;

use strict;
use warnings;

my %_def_cache;
my $_def_name;

# default new returns a new empty doc
sub new {
  my $class = shift;
  return XML::Comma::Doc->new ( type => eval "\$$class\::_def_name" ||
                                        die "need to 'load_def' for $class\n" );
}

sub load_def {
  my $class = shift;
  my $_def_name_ref = eval "\\\$$class\::_def_name";
  return  XML::Comma::Def->read(name=>$$_def_name_ref)  if  $$_def_name_ref;
  my $def = XML::Comma::Def->new( block => $class->_def_string() );
  $$_def_name_ref = $def->name;
  return $def;
}

# calls to $class->def_string were not returning any data after
# the first call.  seek( $fh, 0, 0 ) before returning <$fh> 
# didn't work (should it?).  This is the temporary hack, which
# is better than the previous breakage in User and Group.pm 
# (see Gadgets::User::get_user_by_username for details)  -- dug
#
sub _def_string {
  no strict 'refs';
  my $class = shift;

  if ( not $_def_cache{ $class } ) {
    my $fh = *{"$class\::DATA"};
    local $/ = undef;
    $_def_cache{ $class } = <$fh>;
  }
  return $_def_cache{ $class };
}

1;

=pod

=head1 NAME

XML::Comma::Util::DefModule - Abstract parent for modules that define
a Def in a __DATA__ block.

=head1 DESCRIPTION

This module provides an easy way to define a Def inside a
module. Children of XML::Comma::Util::DefModule inherit two methods:

  load_def

  new

The Def is created from a string found in the DATA section of the
module. The load_def() method should be called by the inheriting
class, in order to load the Def into Comma's weltenshmatzel. The
default new() method simply returns a new Doc of the Def's type, and
can be used as-is or overridden. A complete, basic inheritor might
look like this:

  package Example::Frobulator;

  use strict;
  use warnings;

  use base 'XML::Comma::Util::DefModule';
  __PACKAGE__->load_def;

  1;

  __DATA__

  <DocumentDefinition>
    <name>Example_Frobulator_Def</name>
    <class><module>Example::Frobulator</module></class>

    <element><name>frobuvalue</name></element>
  </DocumentDefinition>

=cut
