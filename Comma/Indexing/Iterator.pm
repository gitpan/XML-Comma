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

package XML::Comma::Indexing::Iterator;

use vars '$AUTOLOAD';
use XML::Comma::SQL::Base;
use XML::Comma::Util qw( dbg );

use strict;

use overload bool => \&iterator_has_stuff,
             '++' => \&iterator_next,
             '='  => sub { return $_[0] };
BEGIN {
  # suppress warnings (subroutine redefined warnings are expected)
  local $^W = 0;
  if ( my $syntax = XML::Comma::SQL::DBH_User->db_struct()->{sql_syntax} ) {
    # try to use()
    eval "use XML::Comma::SQL::$syntax";
    # report failure
    if ( $@ ) {
      die "trouble importing: $@\n";
    }
  }
}

# _Iterator_index
# _Iterator_from_tables : [] of tables to select from, includes data table and
#                         whatever is in the sort_spec
# _Iterator_where_clause
# _Iterator_order_by
# _Iterator_order_expressions : [] of expression elements that are used by
#                                     order by and so need to be part of the
#                                     select statement
# _Iterator_sort_spec        : simple SQL string created from sort_spec arg
# _Iterator_collection_spec  : SQL string created from collection_spec arg
# _Iterator_textsearch_spec  : SQL string created from textsearch_spec arg
# _Iterator_st
# _Iterator_current_row
#
# _Iterator_newly_created
# _Iterator_newly_refreshed

sub new {
  my ( $class, %args ) = @_;
  my $self = {};
  eval {
    bless ( $self, $class );
    $self->{_Iterator_index} = $args{index} ||
      die "need an Indexing::Index reference to make an Iterator\n";
    $self->{_Iterator_order_by} = $args{order_by} || '';
    $self->{_Iterator_where_clause} = $args{where_clause} || '';
    $self->{_Iterator_from_tables} =
      [ $self->{_Iterator_index}->data_table_name() ];
    $self->{_Iterator_sort_spec} = $self->_make_sort_spec($args{sort_spec});
    $self->{_Iterator_collection_spec} =
      $self->_make_collection_spec( $args{collection_spec} );
    $self->{_Iterator_textsearch_spec} =
      $self->_make_textsearch_spec( $args{textsearch_spec} );
    $self->{_Iterator_newly_created} = 1;
    #  dbg 'i-spec', $self->{_Iterator_sort_spec};
  }; if ( $@ ) { XML::Comma::Log->err ( 'BAD_ITERATOR_CREATE', $@ ); }
  return $self;
}

sub count_only {
  my ( $class, %args ) = @_;
  my $sth;
  my $self = $class->new ( %args );
  eval {
    my $order_by = $self->_fill_order_expressions();
    my $string = sql_select_from_data
      ( $self->{_Iterator_index},
        $self->{_Iterator_order_expressions},
        $self->{_Iterator_from_tables},
        $self->{_Iterator_where_clause},
        $self->{_Iterator_sort_spec},
        $order_by,
        0, 0, # limits
        $self->{_Iterator_collection_spec},
        $self->{_Iterator_textsearch_spec},
        'do count only' );
    #  dbg 'sql-count', $string;
    $sth = $self->{_Iterator_index}->get_dbh()->prepare ( $string );
    $sth->execute();
  }; if ( $@ ) { XML::Comma::Log->err ( 'ITERATOR_ACCESS_FAILED', $@ ); }
  return $sth->fetchrow_arrayref()->[0];
}

sub aggregate {
  my ( $class, %args ) = @_;
  my $function = $args{function} || die "need a function to aggregate\n";
  my $sth;
  my $self = $class->new ( %args );
  eval {
    my $order_by = $self->_fill_order_expressions();
    my $string = sql_select_from_data
      ( $self->{_Iterator_index},
        $self->{_Iterator_order_expressions},
        $self->{_Iterator_from_tables},
        $self->{_Iterator_where_clause},
        $self->{_Iterator_sort_spec},
        $order_by,
        0, 0, # limits
        $self->{_Iterator_collection_spec},
        $self->{_Iterator_textsearch_spec},
        '',   # count only
        $function );
    #  dbg 'sql-count', $string;
    $sth = $self->{_Iterator_index}->get_dbh()->prepare ( $string );
    $sth->execute();
  }; if ( $@ ) { XML::Comma::Log->err ( 'ITERATOR_ACCESS_FAILED', $@ ); }
  return $sth->fetchrow_arrayref()->[0];
}

sub iterator_refresh {
  my ( $self, $limit_number, $limit_offset ) = @_;
  eval {
    my $order_by = $self->_fill_order_expressions();
    my $index = $self->{_Iterator_index};
    my $dbh = $index->get_dbh();
    $self->{_Iterator_sth}->finish()  if  $self->{_Iterator_sth};
    my $string = sql_select_from_data
      ($index,
       $self->{_Iterator_order_expressions},
       $self->{_Iterator_from_tables},
       $self->{_Iterator_where_clause},
       $self->{_Iterator_sort_spec},
       $order_by,
       $limit_number,
       $limit_offset,
       $self->{_Iterator_collection_spec},
       $self->{_Iterator_textsearch_spec} );
    #  dbg 'refreshing', $self;
    #  dbg 'sql', $string;
    $self->{_Iterator_sth} = $dbh->prepare ( $string );
    $self->{_Iterator_sth}->execute();
    #  dbg 'res', $self->{_Iterator_sth}->dump_results(); exit(0);
    $self->{_Iterator_newly_created} = 0;
    $self->{_Iterator_newly_refreshed} = 1;
    $self->{_Iterator_current_row} = undef;
  }; if ( $@ ) { XML::Comma::Log->err ( 'ITERATOR_ACCESS_FAILED', $@ ); }
  return $self;
}

sub iterator_next {
  my $self = shift();
  if ( $self->{_Iterator_newly_created} ) {
    $self->iterator_refresh();
  }
  $self->{_Iterator_newly_refreshed} = 0;
  eval {
    $self->{_Iterator_current_row} =
      $self->{_Iterator_sth}->fetchrow_arrayref(); 
  }; #if ( $@ ) { XML::Comma::Log->err ( 'ITERATOR_ACCESS_FAILED', $@ ); }
  # it actually seems better not to do anything with errors here. that
  # we we can run under raise_error, and still multiply-advance past
  # the end of an iterator sequence. if there is an actual database
  # error, presumably it will get thrown again next time any fields
  # are asked for.
  return  $self->{_Iterator_current_row} ? $self : 0;
}

sub iterator_has_stuff {
  my $self = shift();
  # as with _current_element (which this could be factored into) check
  # to see if we're newly created or newly refreshed, and need to
  # transparently setup to retrieve elements (dwim in action)
  if ( $self->{_Iterator_newly_created} ) {
    $self->iterator_refresh();
  }
  if ( $self->{_Iterator_newly_refreshed} ) {
    $self->iterator_next();
  }
  return $self->{_Iterator_current_row} ? 1 : 0;
}

sub retrieve_doc {
  my $self = shift();
  return XML::Comma::Doc->retrieve
    ( type => $self->{_Iterator_index}->doctype(),
      store => $self->{_Iterator_index}->store(),
      id => $self->doc_id() );
}

sub read_doc {
  my $self = shift();
  return XML::Comma::Doc->read
    ( type => $self->{_Iterator_index}->doctype(),
      store => $self->{_Iterator_index}->store(),
      id => $self->doc_id() );
}

sub doc_key {
  my $self = shift();
  return XML::Comma::Storage::Util->concat_key
    ( type  => $self->{_Iterator_index}->doctype(),
      store => $self->{_Iterator_index}->store(),
      id    => $self->doc_id() );
}

sub _current_element {
  my ( $self, $el_name ) = @_;
  # check to see if we're newly created or newly refreshed, and need
  # to transparently setup to retrieve elements (dwim in action)
  if ( $self->{_Iterator_newly_created} ) {
    $self->iterator_refresh();
  }
  if ( $self->{_Iterator_newly_refreshed} ) {
    $self->iterator_next();
  }
  # get field position in Index
  my $pos = $self->{_Iterator_index}->column_pos ( $el_name );
  die "no '$el_name' field in iterator\n"  if  ! defined $pos;
  # return the value
  return $self->{_Iterator_current_row}->[ $pos ];
}



# first runs _get_order_by to get the order_by expression, and then
# loops to check whether various order_by_expressions are being
# referenced. pushes the <order_by_expression> elements that it finds
# onto the array.
sub _fill_order_expressions {
  my $self = shift();
  my $odb = $self->_get_order_by() || return '';
  $self->{_Iterator_order_expressions} = [];
  foreach my $exp ($self->{_Iterator_index}->elements('order_by_expression')) {
    # if the name of this el appears in the order_by clause (as a
    # whole word), push this el onto our order_by_expressions array
    if ( $odb =~ m:\b${ \( $exp->element('name')->get() )}\b: ) {
      push @{$self->{_Iterator_order_expressions}}, $exp;
    }
  }
  return $odb;
}


# generate an order by clause -- use default_order_by if no order_by is given
sub _get_order_by {
  my $self = shift();
  my $order_by_string = "";
  my $this_odb = $self->{_Iterator_order_by};
  my $default = $self->{_Iterator_index}->element('default_order_by')->get();
  if ( $this_odb ) {
    $order_by_string = $this_odb;
  } else {
    $order_by_string = $default;
  }
  # dbg 'odb', $order_by_string;
  return $order_by_string;
}

sub _make_sort_spec {
  my ( $self, $arg ) = @_;
  return '' if ! $arg;
  my $data_tn = $self->{_Iterator_index}->data_table_name();
  my $sort_tn = $self->{_Iterator_index}->sort_table_name ( $arg );
  die "no such sort: $arg\n"  if  ! $sort_tn;
  push @{$self->{_Iterator_from_tables}}, $sort_tn;
  return " $data_tn.doc_id=$sort_tn.doc_id";
}

sub _make_collection_spec {
  my ( $self, @arg ) = @_;
  return '' if ! $arg[0];
  my $data_tn = $self->{_Iterator_index}->data_table_name();
  my ( $collection, $value ) = split /:/, $arg[0], 2;
  my $partial = $self->{_Iterator_index}->collection_partial($value);
  return " $data_tn.$collection LIKE " .
    $self->{_Iterator_index}->get_dbh()->quote ( "%$partial%" );
}

# FIX: should a single term with no matches should stop the search,
# ala google?
sub _make_textsearch_spec {
  my ( $self, @arg ) = @_;
  return '' if ! $arg[0]; # no textsearch given to invocation method
  my $dbh = $self->{_Iterator_index}->get_dbh();
  my $data_table_name = $self->{_Iterator_index}->data_table_name();
  my $sql_string='';
  my @temp_tables;
  my ( $ts_name, $word_string ) = split ( /\:/, $arg[0], 2 );
  foreach my $word ( split /\s+/, $word_string ) {
    my ($stemmed_word) = XML::Comma::Pkg::Textsearch::Preprocessor->stem($word);
    next  if  ! $stemmed_word;  # arg was stopword
    my $q_word = $dbh->quote ( $stemmed_word );

    my ($ts_table_name) =
      $self->{_Iterator_index}->sql_get_textsearch_tables($ts_name);
    die "no textsearch table found for $ts_name\n" if ! $ts_table_name;
    my ($temp_table_name, $size) = $self->{_Iterator_index}
      ->sql_create_textsearch_temp_table ( $ts_table_name, $stemmed_word );
    next  if  ! $temp_table_name;  # arg record not found or empty
    push @temp_tables, { name=>$temp_table_name, size=>$size };
  }
  if ( ! @temp_tables ) {
    die "no record found for any of the keywords given";
  }
  @temp_tables = sort { $a->{size} <=> $b->{size} } @temp_tables;
  # do the first part of the join pivot
  my $temp_table_name = $temp_tables[0]->{name};
  $sql_string .= " $data_table_name._sq=$temp_table_name.id";
  # and do any remaining parts of the join
  foreach my $i ( 1..$#temp_tables ) {
    my $last_temp_table_name = $temp_tables[$i-1]->{name};
    my $temp_table_name = $temp_tables[$i]->{name};
    $sql_string .= " AND $last_temp_table_name.id=$temp_table_name.id";
  }
  push @{$self->{_Iterator_from_tables}}, map { $_->{name} } @temp_tables;
  return $sql_string;
}

####
# AUTOLOAD
#
#
####

sub AUTOLOAD {
  my ( $self, @args ) = @_;
  my $value;
  # strip out local method name and stick into $m
  $AUTOLOAD =~ /::(\w+)$/;  my $m = $1;
  eval {
    if ( my $method = $self->{_Iterator_index}->get_method($m) ) {
      $value = $method->( $self, @args );
    } else {
      $value = $self->_current_element($m);
    }
  }; if ( $@ ) { XML::Comma::Log->err ( 'ITERATOR_ACCESS_FAILED', $@ ); }
  if ( $self->{_Iterator_index}->column_type($m) eq 'collection' ) {
    my $list = $self->{_Iterator_index}->collection_unconcat($value);
    return wantarray ? @{$list} : $list;
  } else {
    return $value;
  }
}

sub DESTROY {
  $_[0]->{_Iterator_sth}->finish()  if  $_[0]->{_Iterator_sth};
  $_[0]->{_Iterator_index}->sql_drop_any_temp_tables
    ( $_[0]->{_Iterator_from_tables} )  if  $_[0]->{_Iterator_index};
}

1;
