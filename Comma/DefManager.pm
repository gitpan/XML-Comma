##
#
#    Copyright 2001, AllAfrica Global Media
#
#    This file is part of XML::Comma
#
#    XML::Comma is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    For more information about XML::Comma, point a web browser at
#    http://xymbollab.com/tools/comma/, or read the tutorial included
#    with the XML::Comma distribution at docs/guide.html
#
##

package XML::Comma::DefManager;
use strict;

use XML::Comma::Util qw( dbg );

## hash for def references. $def->name_up_path() => $def
my %defs;
my %pnotes;

sub for_path {
  my ( $class, $path ) = @_;
  return $defs{$path} if  $defs{$path} && ! _modified_since ( $defs{$path} );
  my @path = split ':', $path;
  _make_def ( $path[0] );
  return $defs{$path} || die "no Def found for '$path'\n";
}

sub macro_string {
  my ( $class, $name ) = @_;
  open ( MACRO, _find_macro_file($name) ) || die "can't open macro file: $!\n";
  my @lines = <MACRO>;
  close MACRO;
  return join ( '', @lines );
}


sub add_def {
  my ( $class, $def ) = @_;
  $defs{$def->name_up_path()} = $def;
}


sub to_string {
  my $str = "--- DefManager ---\n";
  foreach my $key ( sort keys %defs ) {
    $str .= $key . "    - $defs{$key} \n";
  }
  return $str;
}


sub _modified_since {
  my $def = shift();
  # if we don't have a from_file for this def, we can't know when it
  # was modified, so return false
  return if  ! $def->{_from_file};
  # otherwise, check modified time
  if ( (stat($def->{_from_file}))[9] > $def->{_last_mod_time} ) {
    return 1;
  }
  return;
}


sub _make_def {
  my $doc_type = shift();
  XML::Comma::Def->new ( file => _find_def_file($doc_type) );
}

sub _find_def_file {
  my $name = shift();
  # try each defs_directory in turn
  foreach my $dir ( @{XML::Comma->defs_directories()} ) {
    my $filename = $dir . '/' . $name . XML::Comma->defs_extension();
    return $filename  if  -r $filename;
  }
  die "cannot find definition file for def '$name'\n";
}

sub _find_macro_file {
  my $name = shift();
  # try each defs_directory in turn
  foreach my $dir ( @{XML::Comma->defs_directories()} ) {
    my $filename = $dir . '/' . $name . XML::Comma->macro_extension();
    return $filename  if  -r $filename;
  }
  die "cannot find macro file for macro '$name'\n";
}

sub get_pnotes {
  my ( $class, $def ) = @_;
  if ( ref($def) && ref($def) eq 'XML::Comma::Def' ) {
    return $pnotes{$def->name_up_path()} ||= {};
  } else {
    return $pnotes{ $class->for_path($def)->name_up_path() } ||= {};
  }
}

#
####
####
my $bootstrap_def = XML::Comma::Bootstrap->new
  ( block => XML::Comma::Bootstrap->bootstrap_block() );
####
####
#

# be paranoid about global destruction: undef the references that
# we're holding to all Defs and pnotes objects...
END {
#  print "DefManager undefing...\n";
  map { undef $defs{$_} } keys %defs;
  map { undef $defs{$_} } keys %pnotes;
#  print "done with DM end\n";
}

1;


