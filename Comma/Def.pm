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

package XML::Comma::Def;
use XML::Comma::Util qw( dbg trim name_and_args_eval array_includes );

@ISA = qw( XML::Comma::NestedElement
           XML::Comma::Configable
           XML::Comma::Hookable
           XML::Comma::Methodable );

use strict;

# _Def_deftable : cache built as-we-go for definitions,
#            : * should be accessed/modified only by  def_by_name() *
# _Def_name_up_path

# _Def_indexes                : {} hashref {_Def_indexes}->{name} = $index
# _Def_storages               : {} hashref {_Def_storages}->{name} = $storage
# _Def_macro_names            : [] arrayref listing macros applied
# _Def_plural                 : {} an existence hashref
# _Def_ignore_for_hash        : {} an existence hashref
# _Def_required               : {} an existence hashref
#
# _Def_sort_sub               : a code ref created by _config__sort_sub
#
# _Def_is_nested              : a cached scalar to avoid re-checking nested-ness
# _Def_is_blob                : a cached scalar to avoid re-checking blob-ness


# file ||
# block  ||
# tag_up_path  [def]file:///allafrica/docs/perl-bookshelf/cookbook/ch13_01.htm
#
# last_mod_time
# from_file
sub new {
  my ( $class, %arg ) = @_;
  if ( $arg{file} ) {
    return _new_from_file ( $arg{file}, $class );
  } elsif ( $arg{block} ) {
    return _new_from_block ( $arg{block}, $class );
  }
  # called simply: this routine actually does all the work of making a
  # new def, the above ifs call it one way or another.
  my $self = {}; bless ( $self, $class );
  $self->{_from_file} = $arg{from_file} || '';
  $self->{_last_mod_time} = $arg{last_mod_time} || 0;
  my $tag_up_path = $arg{tag_up_path} || 'DocumentDefinition';
  my $def = $arg{def} || XML::Comma::DefManager->for_path($tag_up_path);
  $self->_init ( def => $def,
                 tag_up_path=>$tag_up_path, 
                 init_index=>$arg{init_index} );
  return $self;
}

sub _init {
  my ( $self, %arg ) = @_;
  $self->{_Def_plural} = {};
  $self->{_Def_required} = {};
  $self->{_Def_macro_names} = [];
  $self->allow_hook_type ( 'read_hook',
                           'document_write_hook',
                           'validate_hook',
                           'set_hook',
                           'set_from_file_hook' );
  $self->SUPER::_init ( %arg );
}

sub _Def_init_name_up_path {
  my ( $self, $in_progress_parser ) = @_;
  $self->{_Def_name_up_path} = '';
  foreach my $element ( $in_progress_parser->down_tree_branch() ) {
#    dbg 'initting', $element, $element->to_string()
#      unless ref($element) =~ /Bootstrap/;
    $self->{_Def_name_up_path} .= $element->element('name')->get() . ':';
  }
  chop $self->{_Def_name_up_path};
}

# arg: name
sub read {
  my ( $class, %arg ) = @_;
  my $def;
  eval {
    my $name = $arg{name} ||  die  "no name given to Def->retrieve()";
    $def = XML::Comma::DefManager->for_path ( $name );
  }; if ( $@ ) {
    XML::Comma::Log->err ( 'DEF_READ_ERROR', $@ );
  }
  return $def;
}

sub retrieve {
  XML::Comma::Log->err ( 'DEF_READ_ERROR', 'not allowed to retrieve a Def' );
}

sub _new_from_block {
  my ( $block, $class ) = @_;
  my $def = eval {
    XML::Comma::parser()->new ( block => $block,
                                top_level_class => $class );
  }; if ( $@ ) {
    XML::Comma::Log->err ( 'DEF_ERROR', $@ );
  }
  return $def;
}

sub _new_from_file {
  my ( $file, $class ) = @_;
  my $def = eval {
    XML::Comma::parser()->new ( filename => $file,
                                top_level_class => $class );
  };
  if ( $@ ) {
    XML::Comma::Log->err ( 'DEF_ERROR', $@ );
  }
  return $def;
}


sub finish_initial_read {
  my ( $self, $in_progress_parser ) = @_;
  $self->_Def_init_name_up_path ( $in_progress_parser );
  # we would like to make DefManager aware of us, so we do that
  # here. DefManager itself can't do this, because a) we might be
  # defining ourself by hand from a block, and b) we might be a
  # sub-def that it never sees
  XML::Comma::DefManager->add_def ( $self );
  # the storages and methods creation routines should
  # be done specially, rather than as part of the _config__ stuff,
  # to avoid order-of-declaration errors.
  if ( $self->tag() eq 'DocumentDefinition' ) {
    $self->_create_indexes();
    $self->_create_storages();
  }
  $self->_config_dispatcher();
}


# override the standard Element::add_element to instantiate sub_elements
# as Defs, not just as Elements
sub add_element {
  my ( $self, $tag ) = @_;
  $self->_add_element_legality_check ( $tag );
  my $element;
  # sub-elements need to be instantiated as defs, but everything else
  # should just be elements.
  if ( $tag eq 'element' or
       $tag eq 'nested_element' or
       $tag eq 'blob_element' ) {
    $element = XML::Comma::Def->new
      ( def           => $self->def()->def_by_name($tag),
        tag_up_path   => $self->tag_up_path() . ':' . $tag,
        from_file     => $self->{_from_file},
        last_mod_time => $self->{_last_mod_time},
        init_index     => scalar(@{$self->{_nested_elements}}) );
  } elsif ( $self->def()->def_by_name($tag)->is_nested() ) {
    $element = XML::Comma::NestedElement->new
      ( def            => $self->def()->def_by_name($tag),
        tag_up_path    => $self->tag_up_path() . ':' . $tag,
        init_index     => scalar(@{$self->{_nested_elements}}) );
  } else {
    $element = XML::Comma::Element->new
      ( def          => $self->def()->def_by_name($tag),
        tag_up_path  => $self->tag_up_path() . ':' . $tag,
        init_index     => scalar(@{$self->{_nested_elements}}) );
  }
  $self->_add_elements ( $element );
  return $element;
}


####
sub name_up_path {
  return $_[0]->{_Def_name_up_path};
}


####
sub def_by_name {
  my ( $self, $name ) = @_;
  # check cache
  return $self->{_Def_deftable}->{$name}  if  $self->{_Def_deftable}->{$name}; 
  # not in cache yet: get, stick in cache and return
  foreach my $el ( $self->def_sub_elements() ) {
    if ( $el->element('name')->get() eq $name ) {
      if ( $el->elements('defname')->[0] ) {
        return $self->{_Def_deftable}->{$name} =
          XML::Comma::DefManager->for_path
              ( $el->elements('defname')->[0]->get() );
      } else {
        return $self->{_Def_deftable}->{$name} = $el;
      }
    }
  }
}


# turn a storage section element into a Store object and save that
# object in our _storage hash so that we can look it up later by
# name. do this after _create_indexes, so that we can check the
# index_on_store validity and add a hook to accomplish that. 
sub _create_storages {
  my $self = shift();
  foreach my $storage_el ( $self->elements('store') ) {
    $self->{_Def_storages}->{ $storage_el->element('name')->get() } =
      XML::Comma::Storage::Store::init_and_cast
          ( $storage_el,
            $self->element('name')->get() );
    $self->_index_on_store_hooks ( $storage_el );
  }
}

sub _index_on_store_hooks {
  my ( $self, $storage_el ) = @_;
  foreach my $inx_name ( $storage_el->elements_group_get('index_on_store') ) {
    # check whether the index exists, and that it expects this storage
    my $index;
    eval { $index = $self->get_index ( $inx_name ); };
    if ( $@ ) {
      die "can't index_by_name to '$inx_name' -- it doesn't exist\n";
    }
    my $st = $index->store();
    if ( $st ne $storage_el->name() ) {
      die "can't index_by_name to '$inx_name' -- it stores from '$st'\n";
    }
    my $update_string = "sub { \$_[0]->index_update ( index=>'$inx_name' ) };";
    my $delete_string = "sub { \$_[0]->index_remove ( index=>'$inx_name' ) };";
    $storage_el->add_hook ( 'post_store_hook', $update_string );
    $storage_el->add_hook ( 'erase_hook', $delete_string );
  }
}


# as with storage stuff above, turn an index section into an Index
# object and keep track of it by name.
sub _create_indexes {
  my $self = shift;
  foreach my $index_el ( $self->elements('index') ) {
    $self->{_Def_indexes}->{ $index_el->element('name')->get() } =
      XML::Comma::Indexing::Index::init_and_cast
          ( $index_el,
            $self->element('name')->get() );
  }
}

sub get_store {
  my ( $self, $storage_name ) = @_;
  return $self->{_Def_storages}->{$storage_name} ||
    XML::Comma::Log->err ( 'NO_SUCH_STORAGE',
                           "no storage named '$storage_name' defined for " .
                           $self->name_up_path() );
}

sub store_names {
  return keys %{$_[0]->{_Def_storages}};
}

sub get_index {
    my ( $self, $index_name ) = @_;
    return $self->{_Def_indexes}->{$index_name} ||
      XML::Comma::Log->err ( 'NO_SUCH_INDEX',
                             "no index named '$index_name' defined for ".
                             $self->name_up_path() );
}

sub index_names {
  return keys %{$_[0]->{_Def_indexes}};
}


sub _config__macro {
  my ( $self, $el ) = @_;
  # get name and set special variable @macro_args to args list
  my ( $macro_name, @macro_args ) = name_and_args_eval ( $el->get() );
  # ask DefManager for the macro as a string, and eval it in this
  # context, with $self set to this Def, and @macro_args as the list
  # of arguments to the macro
  scalar ( eval XML::Comma::DefManager->macro_string($macro_name) ) ||
    die "error during macro '$macro_name' eval: $@\n";
  push @{$self->{_Def_macro_names}}, $macro_name;
}

sub applied_macros {
  my ( $self, @mnames ) = @_;
  if ( @mnames ) {
    foreach ( @mnames ) {
      return  unless
        XML::Comma::Util::array_includes ( @{$self->{_Def_macro_names}}, $_ );
    }
    return 1;
  } else {
    return @{$self->{_Def_macro_names}};
  }
}

sub _config__document_write_hook {
  my ( $self, $el ) = @_;
  # these should appear only in top-level defs -- bootstrap def should
  # take care of that
  $self->add_hook ( 'document_write_hook', $el->get() );
}


####
# validation methods
####

sub _config__plural {
  my ( $self, $el ) = @_;
  my @plural_list = eval $el->get();
  if ( $@ ) {
    die "problem with plural list: " . $el->get() . "\n";
  }
  map { $self->{_Def_plural}->{$_} = 1 } @plural_list;
}

sub _config__ignore_for_hash {
  my ( $self, $el ) = @_;
  my @ignore_list = eval $el->get();
  if ( $@ ) {
    die "problem with ignore_for_hash list: " . $el->get() . "\n";
  } map { $self->{_Def_ignore_for_hash}->{$_} = 1 } @ignore_list;
}

# note in the existence hashref that this is a required element, so
# that we can quickly check that (from doc->element_is_required(), for
# example). Also, add a validation hook that makes sure that an
# element exists and either has content or is nested.
sub _config__required {
  my ( $self, $el ) = @_;
  my $required = $el->get();
  my @list = eval $required;
  if ( $@ ) {
    die "error while trying to parse required list '$required': $@\n";
  }
  foreach my $req ( @list ) {
    $self->{_Def_required}->{$req} = 1;
    $self->add_hook ( 'validate_hook',
         "sub {
            my \$self = shift();
            my \$req_el = \$self->elements('$req')->[0];
            die \"required element '$req' not found in \" . \$self->tag_up_path() . \"\\n\"  if
                    (! \$req_el) or 
                    ((! \$req_el->def()->is_nested()) and (! \$req_el->get()));
          }",
                    0xffffff # our "hook order" number -- high because
                             # we want to do this hook after any that
                             # are declared in the defs
                    );
  }
}


#    # this string will get interpolated into the string below and used
#    # as the list that foreach loops across. there may well be a cleaner
#    # way to do this.
#    my $raw_string = $el->get() || '()';
#    $self->add_hook ( 'validate_hook',
#      "sub {
#         my \$self = shift();
#         foreach my \$string ( $raw_string ) {
#           my \$rel = \$self->elements(\$string)->[0];
#           die \"error: required element \$string not found in \" . \$self->tag_up_path() . \"\\n\"  if
#             (! \$rel)  or
#             ((! \$rel->def()->is_nested()) and (! \$rel->get()) );
#        }
#      }" );
#  }


sub _config__read_hook {
  my ( $self, $el ) = @_;
  $self->add_hook ( 'read_hook', $el->get() );
}

sub _config__validate_hook {
  my ( $self, $el ) = @_;
  $self->add_hook ( 'validate_hook', $el->get() );
}

sub _config__set_hook {
  my ( $self, $el ) = @_;
  $self->add_hook ( 'set_hook', $el->get() );
}

sub _config__set_from_file_hook {
  my ( $self, $el ) = @_;
  $self->add_hook ( 'set_from_file_hook', $el->get() );
}

sub _config__def_hook {
  my ( $self, $el ) = @_;
  eval $el->get();
  if ( $@ ) { XML::Comma::Log->err ( 'DEF_HOOK_ERR', $@ ); }
}

sub _config__sort_sub {
  my ( $self, $el ) = @_;
  $self->{_Def_sort_sub} = eval $el->get();
  if ( $@ ) { XML::Comma::Log->err ( 'SORT_SUB_EVAL_ERR', $@ ); }
}

sub def_pnotes {
  return XML::Comma::DefManager->get_pnotes ( $_[0] );
}

sub sort_sub {
  return $_[0]->{_Def_sort_sub};
}

# is the element the name of which we pass plural
sub is_plural {
  return 1  if  $_[0]->{_Def_plural}->{$_[1]};
  return;
}

sub is_required {
  return 1  if  $_[0]->{_Def_required}->{$_[1]};
  return;
}

sub is_ignore_for_hash {
  return 1  if  $_[0]->{_Def_ignore_for_hash}->{$_[1]};
  return;
}

sub validate {
  my ( $self, $element, $content ) = @_;
    foreach my $hook ( @{$self->get_hooks_arrayref('validate_hook')} ) {
      $hook->( $element, $content );
    }
}

# is the element we define allowed to have sub-elements
sub is_nested {
  return $_[0]->{_Def_is_nested} ||=
              ( $_[0]->tag() eq 'nested_element' ||
                $_[0]->tag() eq 'DocumentDefinition' );
}

# is the element we define a blob element
sub is_blob {
  return $_[0]->{_Def_is_blob} ||= ( $_[0]->tag() eq 'blob_element' );
}

# a method to get all sub-elements of this Def that are also Def-ed
# elements -- used by def_by_name(), and various to_string() and
# similar methods
sub def_sub_elements {
  return ( $_[0]->elements('element','nested_element','blob_element') );
}


########
#
# method methods -- override these from AbstractElement to point at
# ourself, not at our def...
#
# note that methods called this way get the Def as their $self, not a
# Doc. for many methods this won't matter, but it might be a good FAQ
# entry. also, it would be good to unify the code for Def->method and
# Doc->method, although (I think) that would require another layer of
# indirection.
#
########

sub method {
  my ( $self, $name, @args ) = @_;
  my $method = $self->get_method ( $name );
  if ( $method ) {
    my $return; my @return;
    if ( wantarray ) {
      @return = eval { $method->( $self, @args ); };
    } else {
      $return = eval { $method->( $self, @args ); };
    }
    if ( $@ ) {
      XML::Comma::Log->err ( 'METHOD_ERROR',
                             "'$name' call threw error: $@" );
    }
    return wantarray ? @return : $return;
  } else {
    XML::Comma::Log->err ( 'NO_SUCH_METHOD',
                           "no method '$name' found in '" .
                           $self->tag_up_path() . "'" );
  }
}

sub method_code {
  my ( $self, $name ) = @_;
  return $self->get_method ( $name );
}


##
# Empty DESTROY: we don't want to autoload this
##
sub DESTROY {
#    if ( $_[0]->{_tag} eq 'DocumentDefinition' ) {
#      print "D: $_[0]\n";
#    }
}


1;

