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

package XML::Comma::BlobElement;

@ISA = ( 'XML::Comma::AbstractElement' );

use strict;
use XML::Comma::Util qw( dbg trim );

##
# object fields
#
# _Blob_location            :
# _Blob_content_while_parsing
#
# Doc_storage               :


########
#
# Blob Manipulation
#
########

sub set {
  my ( $self, $content, %args ) = @_;
  $self->assert_not_read_only();
  eval {
    # do we have a store?
    die "need to have stored in order to set() a blob_element\n"  if
      ! $self->{Doc_storage}->{store};
    # run set hooks
    unless ( $args{no_set_hooks} ) {
      foreach my $hook ( @{$self->def()->get_hooks_arrayref('set_hook')} ) {
        $hook->( $self, \$content, %args );
      }
    }
    # write out
    if ( defined $content ) {
      $self->{_Blob_location} =
        $self->{Doc_storage}->{store}->write_blob
          ( $self->{Doc_storage}->{location},
            $self->{Doc_storage}->{id},
            $self,
            $content );
    } else {
      $self->{Doc_storage}->{store}->erase_blob ( $self );
      $self->{_Blob_location} = undef;
    }
  }; if ( $@ ) { XML::Comma::Log->err ( 'BLOB_SET_ERROR', $@ ); }
  return $content;
}

sub get {
  my $self = shift();
  return  if  ! $self->{_Blob_location};
  my $content = eval { $self->{Doc_storage}->{store}->read_blob ( $self ); };
  if ( $@ ) { XML::Comma::Log->err ( 'BLOB_GET_ERROR', $@ ); }
  return $content;
}

sub set_from_file {
  my ( $self, $filename, %args ) = @_;
  $self->assert_not_read_only();
  eval {
    die "need to have stored in order to set() a blob_element\n"  if
      ! $self->{Doc_storage}->{store};
    # run set hooks
    foreach my $hook 
      ( @{$self->def()->get_hooks_arrayref('set_from_file_hook')} ) {
        $hook->( $self, $filename, %args );
      }
    $self->{_Blob_location} =
      $self->{Doc_storage}->{store}->copy_to_blob
        (  $self->{Doc_storage}->{location},
           $self->{Doc_storage}->{id},
           $self,
           $filename );
  }; if ( $@ ) { XML::Comma::Log->err ( 'BLOB_SET_ERROR', $@ ); }
  return '';
}

sub validate {
  my $self = shift();
  eval {
    $self->def()->validate ( $self );
  }; if ( $@ ) {
    XML::Comma::Log->err
        ( 'BLOB_VALIDATE_ERROR', "for " . $self->tag_up_path() . ": $@" );
  }
  return '';
}

sub get_location {
  my $self = shift();
  return $self->{_Blob_location} || '';
}

# call this on a blob to handle copy()ing of its parent doc. doesn't
# re-store parent, which is necessary (at some point) in order for the
# <_comma_blob> pointer to be correct.
sub re_store {
  my $self = shift();
  if ( my $filename = $self->{_Blob_location} ) {
    $self->{_Blob_location} = undef;
    $self->{_Blob_location} =
      $self->{Doc_storage}->{store}->copy_to_blob
        (  $self->{Doc_storage}->{location},
           $self->{Doc_storage}->{id},
           $self,
           $filename );
  }
}

# call this on a blob to generate an extension (if any) for the blob's
# location
sub get_extension {
  my $self = shift();
  my ( $_extension_el ) = $self->def()->elements('extension');
  return ''  if  ! $_extension_el;
  my $extension = eval $_extension_el->get();
  if ( $@ ) { XML::Comma::Log->err ( 'BLOB_EXTENSION_ERROR', $@ ); }
  return $extension;
}

sub _get_hash_add { return $_[0]->get(); }

sub to_string {
  my $self = shift();
  if ( $self->{_Blob_location} ) {
    my $str;
    $str = '<' . $self->tag() . $self->attr_string() . '><_comma_blob>' .
      ( $self->{_Blob_location} ) .
        '</_comma_blob></' . $self->tag() . ">\n";
    return $str;
  } else {
    return '';
  }
}


##
# auto_dispatch -- called by AUTOLOAD, and anyone else who wants to
# mimic the shortcut syntax
#
sub auto_dispatch {
  my ( $self, $m, @args ) = @_;
  if ( my $method = $self->method_code($m) ) {
    $method->( $self, @args );
  } else {
    XML::Comma::Log->err ( 'UNKNOWN_ACTION',
                           "no method '$m' found in '" .
                           $self->tag_up_path . "'" );
  }
}


##
# called by parser
#
# keep track of all internal content during the parsing phase, so that
# finish_initial_read can do whatever initialization it needs to do.
sub raw_append {
  $_[0]->{_Blob_content_while_parsing} .= $_[1];
}
sub finish_initial_read {
  my $str = $_[0]->{_Blob_content_while_parsing};
  $str =~ m:(.*)<_comma_blob>(.*)</_comma_blob>(.*):;
  my $preceding = trim $1;
  my $following = trim $3;
  if ( $preceding || $following ) {
    die "illegal content for blob element: $preceding/$following\n";
  }
  $_[0]->{_Blob_location} = $2;
  $_[0]->SUPER::finish_initial_read();
}

1;
