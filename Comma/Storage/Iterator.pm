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

package XML::Comma::Storage::Iterator;

use strict;
use File::Find;
use XML::Comma::Util qw( dbg  );

# _Iterator_Store
# _Iterator_cached_list
# _Iterator_index

# store=>, size=>, pos=>
sub new {
  my ( $class, %arg ) = @_;
  my $self = {};
  # which store
  my $store = $self->{_Iterator_Store} = $arg{store} ||
    die "Storage Iterator needs a store to iterate across\n";
  my $extension = $store->extension() ||
    die "Storage Iterator requires a Store that provides an extension\n";
  # where do we start and how much do we want?
  my $size = $arg{size} || 0xffffffff;
  my $pos = $arg{pos} || '+';
  # build the cached list of locations -- we post-sort the results in
  # chunks again because find's preprocess block doesn't actually sort
  # the file contents of a directory;
  my $temp_by_dir = {};
  my $total_pushed = 0;
  find ( { preprocess => sub { 
             return () if $total_pushed > $size;
             return ($pos eq '+') ? sort @_ : reverse sort @_;
           },
           wanted => sub {
             push ( @{$temp_by_dir->{$File::Find::dir}}, $File::Find::name )
               if  m|$extension$|;
           },
           postprocess => sub {
             $total_pushed += scalar ( @{$temp_by_dir->{$File::Find::dir}} )
               if  defined $temp_by_dir->{$File::Find::dir};
           }
         }, $store->base_directory()
       );
  # post-sort and set where we're starting from and our actual length
  if ( $pos eq '-' ) {
    map { push @{$self->{_Iterator_cached_list}},reverse @{$temp_by_dir->{$_}} }
      sort keys %{$temp_by_dir};
    $#{$self->{_Iterator_cached_list}} = $size-1  if
      ($size-1) < $#{$self->{_Iterator_cached_list}};
    $self->{_Iterator_index} = -1;
  } else {
    map { push @{$self->{_Iterator_cached_list}}, @{$temp_by_dir->{$_}} }
      sort keys %{$temp_by_dir};
    if ( ($size-1) < $#{$self->{_Iterator_cached_list}} ) {
      @{$self->{_Iterator_cached_list}} =
        reverse @{$self->{_Iterator_cached_list}};
      $#{$self->{_Iterator_cached_list}} = $size-1;
      @{$self->{_Iterator_cached_list}} =
        reverse @{$self->{_Iterator_cached_list}};
    }
    $self->{_Iterator_index} = $#{$self->{_Iterator_cached_list}} + 1;
  }
  # bless and return
  bless ( $self, $class );
  return $self;
}

sub length {
  return $#{$_[0]->{_Iterator_cached_list}} + 1;
}

sub index {
  return $_[0]->{_Iterator_index};
}

sub inc {
  return $_[0]->{_Iterator_index} += $_[1] || 1;
}

sub set {
  return $_[0]->{_Iterator_index} = $_[1];
}

sub next_id {
  my $self = shift();
  return if ( $self->{_Iterator_index} >= $#{$self->{_Iterator_cached_list}} );
  $self->inc();
  return $self->{_Iterator_Store}->id_from_location
    ( $self->{_Iterator_cached_list}->[$self->{_Iterator_index}] );
}

sub prev_id {
  my $self = shift();
  return  if ( $self->{_Iterator_index} <= 0 );
  $self->inc(-1);
  return $self->{_Iterator_Store}->id_from_location
    ( $self->{_Iterator_cached_list}->[$self->{_Iterator_index}] );
}

sub next_retrieve {
  my $id = $_[0]->next_id() || return;
  return XML::Comma::Doc->retrieve 
    ( type => $_[0]->{_Iterator_Store}->doctype(),
      store => $_[0]->{_Iterator_Store}->element('name')->get(),
      id => $id );
}

sub prev_retrieve {
  my $id = $_[0]->prev_id() || return;
  return XML::Comma::Doc->retrieve 
    ( type => $_[0]->{_Iterator_Store}->doctype(),
      store => $_[0]->{_Iterator_Store}->element('name')->get(),
      id => $id );
}

sub next_read {
  my $id = $_[0]->next_id() || return;
  return XML::Comma::Doc->read 
    ( type => $_[0]->{_Iterator_Store}->doctype(),
      store => $_[0]->{_Iterator_Store}->element('name')->get(),
      id => $id );
}

sub prev_read {
  my $id = $_[0]->prev_id() || return;
  return XML::Comma::Doc->read
    ( type => $_[0]->{_Iterator_Store}->doctype(),
      store => $_[0]->{_Iterator_Store}->element('name')->get(),
      id => $id );
}

sub doc_id {
  return $_[0]->{_Iterator_Store}->id_from_location
    ( $_[0]->{_Iterator_cached_list}->[$_[0]->{_Iterator_index}] );
}

1;

