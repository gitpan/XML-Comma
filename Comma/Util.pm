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

package XML::Comma::Util;

require Exporter;
@ISA = qw ( Exporter );

@EXPORT_OK = qw(
  trim
  array_includes
  arrayref_remove_dups
  arrayref_remove
  flatten_arrayrefs
  XML_basic_escape
  XML_basic_unescape
  XML_smart_escape
  XML_bare_amp_escape
  dbg
  name_and_args_eval
  random_an_string
);

use strict;

# pass a list of strings to trim, which are not modified.
#
sub trim {
  my @array = grep { defined } @_;
  for ( @array ) { s/^\s+//;  s/\s+$//; }
  return wantarray ? @array : $array[0];
}

# return true if the given array contains a string that eq
# the passed arg
# usage: array_includes ( @array, $string )
sub array_includes (\@$) {
  my $arrayref = shift();
  my $string = shift();
  foreach ( @$arrayref ) {
    #print "array includes: $string, $_\n";
    next unless defined $_; # defensive programming to avoid warnings
    return 1  if  $string eq $_;
  }
  return;
}

# remove duplicates from the array passed in by reference
sub arrayref_remove_dups {
  my $ref = shift();
  my %s=();
  @$ref = ( grep { ! $s{$_} ++ } @$ref );
  return wantarray ? @$ref : $ref;
}

# remove matching element(s) from the array passed in by
# reference. uses array_includes() to determine matches
#
# usage: arrayref_remove ( $arrayref, @elements )
sub arrayref_remove {
  my $ref = shift();
  my @removes = flatten_arrayrefs(@_);
  @{$ref} = grep { ! array_includes(@removes, $_) } @{$ref};
  return wantarray ? @$ref : $ref;
}

# takes a list of arguments, and returns that list with any
# arrayrefs de-reffed and mashed into the list
sub flatten_arrayrefs {
  my @flat;
  foreach my $arg ( @_ ) {
    if ( ref($arg) eq 'ARRAY' ) {
      push @flat, @$arg;
    } else {
      push @flat, $arg;
    }
  }
  return @flat;
}


# XML escapes & < >
sub XML_basic_escape {
  my $string = shift;
  # escape &
  $string =~ s/\&/&amp;/g;
  # escape < >
  $string =~ s/</\&lt;/g ;
  $string =~ s/>/\&gt;/g ;
  return $string;
}

sub XML_basic_unescape {
  my $string = shift;
  $string =~ s/\&amp;/&/g ;
  $string =~ s/\&lt;/</g ;
  $string =~ s/\&gt;/>/g ;
  return $string;
}

# XML escapes & < > -- Tries to be smart about escaping ampersands
# (&'s) only when they're not part of an entity encoding.
sub XML_smart_escape {
  my $string = XML_bare_amp_escape ( shift );
  # escape < > " '
  $string =~ s/</\&lt;/g ;
  $string =~ s/>/\&gt;/g ;
  return $string;
}

# escape all ampersands that don't seem to be part of an entity encoding
sub XML_bare_amp_escape {
  my $string = shift;
  # look for orphan amps, assume that entities that have 1-12
  # word-constituent letters between an & and a ;
  $string =~ s/\&(?!\w{1,15};)/&amp;/g;
  return $string;
}


sub dbg {
  my @flat = flatten_arrayrefs ( @_ );
  my $msg = shift @flat || '';
  print "dbg $msg: ";
  print join '/', @flat;
  print "\n";
  return $_[0];
}

sub name_and_args_eval {
  my ( $string, %defines ) = @_;
  my ( $name, $args_string ) = split ( ':', $string, 2 );
  die "no string argument\n"  if  ! $name;
  my @args;
  if  ( defined $args_string ) {
    @args = eval $args_string;
    if ( $@ ) {
      die "error while evaluating arguments: $@\n";
    }
  }
  return ( $name, @args );
}

sub random_an_string {
  my $length = shift();
  my @chars = ( 'a'..'z', 'A'..'Z', 0..9 );
  my $string;
  for ( 1..$length ) {
    $string .= $chars[ rand(scalar @chars) ];
  }
  return $string;
}

sub attr_from_tag_string {
  my $string = shift();
  my %attrs = ();
#  print "1: $string\n";
  while ( $string =~ m:(\w+)="([^"]*)":g ) {
#    print "   $1 => $2\n";
    $attrs{$1} = $2;
  }
  return %attrs;
}

1;


