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

package XML::Comma::Doc;

use XML::Comma::Util qw( dbg flatten_arrayrefs );

@ISA = ( 'XML::Comma::NestedElement' );

use strict;

##
# object fields
#
# _Doc_from_file
# _Doc_locked
# _Doc_new
#
# Doc_storage:        information from last storage, in a hashref
#

##
# new() : takes a type=>, block=> or file=> and returns a new doc.
#
sub new {
  my ( $class, %arg ) = @_;
  if ( $arg{type} ) {
    my $type = $arg{type};
    my $self = {}; bless ( $self, $class );
    eval {
      $self->{_Doc_from_file} = $arg{from_file}  if  $arg{from_file};
      $self->{_Doc_new} = 1;
      $self->_init ( def          => '',
                     tag_up_path  => $type,
                     read_args  => $arg{read_args} );
    }; if ( $@ ) { XML::Comma::Log->err ( 'DOC_NEW_ERROR', $@ ); }
    return $self;
  } elsif ( $arg{file} ) {
    return _new_from_file ( $arg{file}, $arg{read_args} || \%arg );
  } elsif ( $arg{block} ) {
    return _new_from_block ( $arg{block}, $arg{read_args} || \%arg );
  } else {
        XML::Comma::Log->err ( 'DOC_NEW_ERROR',
                               "no type/block/file given" );
  }
}

sub _init {
  my ( $self, %arg ) = @_;
  # set the Doc_storage arg so that SUPER::_init will set
  # $self->{Doc_storage} to the right reference. also set the
  # create_args field, so that sub-elements will have access to flags
  # such as "no_read_hooks" on instantiation.
  $arg{Doc_storage} = {};
  $arg{Doc_storage}->{read_args} = $arg{read_args};
  $self->SUPER::_init ( %arg );
}

sub _new_from_block {
  my $doc = eval {
    XML::Comma::parser()->new ( block => shift(), read_args => shift() );
  }; if ( $@ ) {
    XML::Comma::Log->err ( 'DOC_NEW_ERROR', $@ );
  }
  return $doc;
}

sub _new_from_file {
  my $doc = eval {
    XML::Comma::parser()->new ( filename => shift(), read_args => shift() );
  }; if ( $@ ) {
    XML::Comma::Log->err ( 'DOC_NEW_ERROR', $@ );
  }
  return $doc;
}


##
# retrieve: takes a single 'address' arg, or a hash of type=>,
# storage=>, id=> and gets a doc from storage. type, storage and id
# are all required. Sets Doc_storage->{foo}
# info.
#
# timeout =>
sub _retrieval_common {
  my $class = shift();
  my %args;
  my $store = eval {
    %args = $class->parse_read_args(@_);
    XML::Comma::DefManager->for_path($args{type})->get_store($args{store});
  }; if ( $@ ) {
    XML::Comma::Log->err ( 'DOC_RETRIEVE_ERROR', $@ );
  }
  return ( $store, $args{id}, $args{timeout}, \%args );
}

sub parse_read_args {
  my $class = shift();
  my %args;
  # either a single key arg followed by optional hash args, or all
  # hash args
  if ( scalar(@_) % 2 ) {
    my $key = shift();
    %args = @_;
    ( $args{type}, $args{store}, $args{id} ) =
      XML::Comma::Storage::Util->split_key ( $key );
    die "bad doc key: $key\n"
      unless ($args{type} and $args{store} and $args{id});
  } else {
    %args = @_;
    $args{type}     ||  die "no type given to Doc->retrieve()\n";
    $args{store}    ||  die "no store given to Doc->retrieve()\n";
    $args{id}       ||  die "no id given to Doc->retrieve()\n";
  }
  return %args;
}

## errors for the rest of these methods will be thrown by the
## underlying store routines

## read will either return a doc or throw an error, unless the id
## given is '+' or '-' and there are no docs stored
sub read {
  my $class = shift();
  my ( $store, $id, $to, $parsed_args ) = $class->_retrieval_common(@_);
  my $doc = eval { $store->read ( $id, $parsed_args ); };
  if ( $@ ) { XML::Comma::Log->err ( 'DOC_READ_ERROR', $@); };
  $doc->set_read_only  if  $doc;
  return $doc;
}

sub retrieve {
  my $class = shift();
  my ( $store, $id, $timeout, $parsed_args ) = $class->_retrieval_common(@_);
  # store's read() handles locking and info setting
  my $doc = eval { $store->read ( $id, $parsed_args, 1, 0, $timeout ); };
  if ( $@ ) { XML::Comma::Log->err ( 'DOC_RETRIEVE_ERROR', $@ ); };
  return $doc;
}

sub retrieve_no_wait {
  my $class = shift();
  my ( $store, $id, $to, $parsed_args ) = $class->_retrieval_common(@_);
  my $doc = eval { $store->read ( $id, $parsed_args, 1, 1 ); };
  if ( $@ ) { XML::Comma::Log->err ( 'DOC_RETRIEVE_ERROR', $@ ); };
  return $doc;
}

sub get_lock {
  my ( $self, %arg ) = @_;
  eval {
    my $locked = XML::Comma->lock_singlet()->lock ( $self->doc_key(),
                                                    0,
                                                    $arg{timeout} );
    $self->{_Doc_locked} = 1  if  $locked;
    $self->unset_read_only();
  }; if ( $@ ) { XML::Comma::Log->err ( 'LOCK_ERROR', $@ ); };
  return $self;
}

### used by Store->write() to put an entry in the lock tables for a
### newly-created doc key.
sub force_lock_flag_set {
  $_[0]->{_Doc_locked} = 1;
}

sub get_lock_no_wait {
  my $self = shift();
  my $locked;
  eval {
    $locked = XML::Comma->lock_singlet()->lock ( $self->doc_key(), 1 );
    if ( $locked ) {
      $self->{_Doc_locked} = 1;
      $self->unset_read_only();
    }
  }; if ( $@ ) { XML::Comma::Log->err ( 'LOCK_ERROR', $@ ); };
  return if ! $locked;
  return $self;
}


##
# set the reference to this doc's definition. overrides Element->def()
#
sub _init_def {
  $_[0]->{_def} = XML::Comma::DefManager->for_path ( $_[0]->tag() );
}

##
# return a (possibly very long) string that is this document in XML
# form.
#
# override $element->to_string() so we can run the document_level
# write hook (passing $self as only argument). note that we call
# SUPER::to_string after we do that.
#
# FIX: break into open-content-close, calling $self->SUPER::content()
sub to_string {
  my $self = shift();
  foreach ( @{$self->def()->get_hooks_arrayref('document_write_hook')} ) {
    $_->( $self );
  }
  return $self->system_stringify();
}
#
# to_string without the hooks, basically. FIX: clean up these two
sub system_stringify {
  my $str = $_[0]->SUPER::to_string();
  # Doc still needs to output an empty envelope, if we're empty
  # (unlike NestedElement)
  if ( ! $str ) {
    $str = '<' . $_[0]->tag() . ">\n";
    $str .= '</'. $_[0]->tag() . '>';
    $str .= "\n";
  }
  return $str;
}

##
# HASH
#
sub comma_hash {
  my $self = shift();
  my $digest = XML::Comma->hash_module()->new();
  $digest->add ( $self->_get_hash_add() );
  return $digest->hexdigest();
}


##
# STORAGE
##

##
# Doc_storage stuff. set by retrieve() and store() operations, so
# only available after doing a retrieve or store of some kind.
#
sub doc_store {
  return  $_[0]->{Doc_storage}->{store} || undef;
}
sub doc_location {
 return $_[0]->{Doc_storage}->{location} || undef;
}
sub doc_id {
  return $_[0]->{Doc_storage}->{id} || undef;
}
sub doc_key {
  return $_[0]->{Doc_storage}->{key} || undef;
}
sub doc_is_locked {
  return $_[0]->{_Doc_locked};
}
##
# and a couple of odd-balls, classified under storage_ for convenience
#
# the *original file* this doc was instantiated from, if any
sub doc_source_file {
  return $_[0]->{_Doc_from_file} || undef;
}
sub doc_last_modified {
  if ( ! $_[0]->doc_store() ) {
    XML::Comma::Log->err ( 'NO_LAST_MODIFIED',
                           "doc_last_modified without store" );
  }
  return $_[0]->doc_store()->last_modified ( $_[0]->doc_location() );
}


##
# set_storage_info routine, called mostly from Store as part of its
# lower-level routines. but move() also does some mucking to save
# state cleanly. (FIX? should there be a lower-level Store::move())
#
# Note: this ref is passed down the tree at new element creation, so
# that Blobs down the tree know where to put themselves.
#
# args: ( $store, $filename, $id, $key, $locked )
sub set_storage_info {
  $_[0]->{Doc_storage}->{store} = $_[1];
  $_[0]->{Doc_storage}->{location} = $_[2];
  $_[0]->{Doc_storage}->{id} = $_[3];
  $_[0]->{Doc_storage}->{key} = $_[4];
  $_[0]->{_Doc_locked} = $_[5];
}
sub clear_storage_info {
  $_[0]->{Doc_storage}->{store} = undef;
  $_[0]->{Doc_storage}->{location} = undef;
  $_[0]->{Doc_storage}->{id} = undef;
  $_[0]->{Doc_storage}->{key} = undef;
  $_[0]->{_Doc_locked} = 0;
}


# FIX: make sure that we're locked before we try to unlock (or have
# store info, or something)
sub doc_unlock {
  #dbg 'unlo', $_[0];
  XML::Comma->lock_singlet()->unlock ( $_[1] || $_[0]->doc_key() );
  $_[0]->{_Doc_locked} = undef  if  ref $_[0];
  $_[0]->set_read_only()  if  ref $_[0];
}



##
# store=>      : string storage_name
# keep_open => : if true, don't unlock/mark ro
# no_hooks =>  : don't run either pre_store or post_store hooks (addition of
#              : this is prompted by the need to store inside a post_store_hook)
# :additional args particular to the underlying Store
#
# let Storage->store() throw most of the errors, here
sub store {
  my ( $self, %arg ) = @_;
  # check whether we're allowed to store
  if ( ! ($self->{_Doc_locked} || $self->{_Doc_new}) ) {
    XML::Comma::Log->err ( 'BAD_STORE_ATTEMPT',
                           "doc isn't locked, can't store" );
  }
  # do the write -- differently depending on whether this is a
  # first-time store
  eval {
    if (my $store = $self->doc_store()  and
        (defined $arg{store} ? $arg{store} eq $self->doc_store()->name() : 1)) {
      $store->write ( %arg, doc=>$self );
    } else {
      my $store_name = $arg{store} ||
        die "no store given to first-time Doc->store()\n";
      $store = $self->def()->get_store( $store_name );
      $store->write ( %arg, doc=>$self, anew=>1 );
    }
  }; if ( $@ ) { XML::Comma::Log->err ( 'STORE_ERROR', $@ ); }
  return $self;
}

##
# delete from permanent storage
#
sub erase {
  my ( $self ) = @_;
  if ( ! $self->{_Doc_locked} ) {
    XML::Comma::Log->err ( 'BAD_ERASE_ATTEMPT',
                           "doc isn't locked, can't erase" );
  }
  if ( ! $self->doc_store() ) {
    XML::Comma::Log->err ( 'BAD_ERASE_ATTEMPT',
                           "erase without store" );
  }
  eval {
    $self->doc_store()->erase ( $self, $self->doc_location() );
    $self->doc_unlock();
    $self->clear_storage_info();
  }; if ( $@ ) { XML::Comma::Log->err ( 'STORE_ERROR', $@ ); }
  return $self;
}

##
# copy stores a document again, according to storage args. store=> is
# optional; the current store will be used if none is specified. most
# copy() operations can be performed with a store() and different
# storage arguments. copies from/to the same sequential store, though,
# need this routine. (make sense?)
sub copy {
  my ( $self, %arg ) = @_;
  # first, check to make sure that we are a stored doc. we really
  # don't want to allow calling copy() on a not-yet-stored doc, even
  # though it doesn't really matter.
  if ( ! $self->doc_store() ) {
    XML::Comma::Log->err ( 'BAD_COPY_ATTEMPT',
                           "copy without store" );
  }
  eval {
    my $store;
    if ( $arg{store} ) {
      $store = $self->def()->get_store ( $arg{store} );
    } else {
      $store = $self->doc_store();
    }
    my $key = $self->doc_key();
    $store->write ( %arg, doc=>$self, anew=>1  );
    XML::Comma::Doc->doc_unlock ( $key );
    $self->doc_unlock()  unless  $arg{keep_open};
  }; if ( $@ ) { XML::Comma::Log->err ( 'STORE_ERROR', $@ ); }
  return $self;
}

##
# takes the same args as copy. doc can't be ro
#
sub move {
  my ( $self, %arg ) = @_;
  if ( ! $self->doc_store() ) {
    XML::Comma::Log->err ( 'OPERATION_NEEDS_STORAGE',
                           "move without storage" );
  }
  if ( ! $self->{_Doc_locked} ) {
    XML::Comma::Log->err ( 'DOC_STORE_ERROR',
                           "doc is ro" );
  }
  eval {
    # we're going to erase the current incarnation of this doc when
    # we're done, so let's keep track of its key
    my $old_key = $self->doc_key();
    # copy the doc
    $self->copy ( %arg );
    # retrieve the pre-copy version and erase it
    XML::Comma::Doc->retrieve($old_key)->erase();
  }; if ( $@ ) { XML::Comma::Log->err ( 'STORE_ERROR', $@ ); }
  return $self;
}


##
# INDEXING
#
##

# args: index => (defaults to main)
#       defer_textsearches => flag that, if true, indicates that a record
#                             should be marked as having a textsearch
#                             that needs to be updated, but that the
#                             actual update should be put off until later.
#
#       comma_flag => (used as a special marker by Indexing routines)

sub index_update {
  my ( $self, %arg ) = @_;
  if ( ! $arg{index} ) {
    XML::Comma::Log->err ( 'DOC_INDEX_ERROR',
                           "no index name given to Doc->index_update()" );
  }
  my $ret = eval {
    $self->def()->get_index($arg{index})->update ( $self,
                                                   $arg{comma_flag},
                                                   $arg{defer_textsearches} );
  };
  if ( $@ ) { XML::Comma::Log->err ( 'DOC_INDEX_ERROR', $@ ); }
  return $ret;
}

sub index_remove {
  my ( $self, %arg ) = @_;
  $self->assert_not_read_only();
  if ( ! $arg{index} ) {
    XML::Comma::Log->err ( 'DOC_INDEX_ERROR',
                           "no index-name given to Doc->index_remove()" );
  }
  my $ret = eval { $self->def()->get_index($arg{index})->delete($self); };
  if ( $@ ) { XML::Comma::Log->err ( 'DOC_INDEX_ERROR', $@ ); }
  return $ret;
}


sub DESTROY {
  $_[0]->doc_unlock()  if  $_[0]->{_Doc_locked};
}

1;

