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
use XML::Comma::Util qw( dbg arrayref_remove );

use strict;

use overload bool => \&iterator_has_stuff,
             '""' => sub { return $_[0] },
             '++' => \&iterator_next,
             '='  => sub {
               #dbg '=======', "$_[0]", $_[0]->{_Iterator_index};
               return $_[0];
             }
;

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

use Parse::RecDescent;
my $spec_parser =
  Parse::RecDescent->new ( $XML::Comma::Indexing::Iterator::spec_grammar );

# _Iterator_index
# _Iterator_columns_pos     : {} column_name => pos
# _Iterator_columns_lst     : [] column names

# _Iterator_from_tables : [] of tables to select from, includes data table and
#                         whatever is in the sort_spec and textsearch_spec
# _Iterator_where_clause
# _Iterator_order_by
# _Iterator_order_expressions : [] of expression elements that are used by
#                                     order by and so need to be part of the
#                                     select statement

# _Iterator_collection_spec  : SQL string created from collection_spec arg
# _Iterator_textsearch_spec  : SQL string created from textsearch_spec arg

# _Iterator_st
# _Iterator_current_row
# _Iterator_select_returnval : whatever value the select statement statement
#                              returned. (MySQL seems to return the total
#                              number of rows, which is useful.) 
#
# _Iterator_newly_created
# _Iterator_newly_refreshed
#
# _Iterator_distinct : flag turned on when sql generation routines recognize
#                    : that a multi-way joing that may create duplicate rows
#                    : has been constructed.

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

    my $cspec_arg;
    if ( $args{collection_spec} and $args{sort_spec} ) {
      $cspec_arg = "$args{collection_spec} AND $args{sort_spec}";
    } else {
      $cspec_arg = $args{collection_spec} || $args{sort_spec};
    }
    $self->{_Iterator_collection_spec} =
      $self->_make_collection_spec( $cspec_arg );

    # this 'distinct' arg isn't documented, because I'm not sure
    # why/how it might be used at the API level
    if ( defined $args{distinct} ) {
      $self->{_Iterator_distinct} = $args{distinct};
    }

    $self->{_Iterator_textsearch_spec} =
      $self->_make_textsearch_spec( $args{textsearch_spec} );

    ( $self->{_Iterator_columns_lst}, $self->{_Iterator_columns_pos} ) =
      $self->_make_columns_lsts ( $args{fields} );

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
        $self->{_Iterator_distinct},
        $order_by,
        0, 0, # limits
        [],   # columns list
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
        $self->{_Iterator_distinct},
        $order_by,
        0, 0, # limits
        [],   # columns list
        $self->{_Iterator_collection_spec},
        $self->{_Iterator_textsearch_spec},
        '',   # count only
        $function );
   # dbg 'sql-aggr', $string;
    $sth = $self->{_Iterator_index}->get_dbh()->prepare ( $string );
    $self->{_Iterator_select_returnval} = $sth->execute();
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
       $self->{_Iterator_distinct},
       $order_by,
       $limit_number,
       $limit_offset,
       $self->{_Iterator_columns_lst},
       $self->{_Iterator_collection_spec},
       $self->{_Iterator_textsearch_spec} );
    #  dbg 'refreshing', $self;
    #dbg 'sql', $string;
    $self->{_Iterator_sth} = $dbh->prepare ( $string );
    $self->{_Iterator_select_returnval} = $self->{_Iterator_sth}->execute();
    #  dbg 'srv', $self->{_Iterator_select_returnval};
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

sub iterator_select_returnval {
  unless ( defined $_[0]->{_Iterator_select_returnval} ) {
    $_[0]->iterator_refresh();
  }
  return $_[0]->{_Iterator_select_returnval};
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
  return  if  ! $self->{_Iterator_current_row};
  my $pos = $self->_ce_pos ( $el_name );
  if ( defined $pos ) {
    my $value = $self->{_Iterator_current_row}->[ $pos ];
    if ( $self->{_Iterator_index}->column_type($el_name) eq 'collection' ) {
      my $list =
        $self->{_Iterator_index}->collection_stringify_unconcat ( $value );
      return wantarray ? @{$list} : $list;
    } else {
      return $value;
    }
  } else {
    die "no '$el_name' item available from iterator\n";
  }
}

# get the position in the select statement of a given 'column' name
sub _ce_pos {
  return 0 if $_[1] eq 'doc_id';
  return scalar ( @{$_[0]->{_Iterator_columns_lst}} ) + 1
      if $_[1] eq 'record_last_modified';
  return $_[0]->{_Iterator_columns_pos}->{$_[1]};
}

sub _make_columns_lsts {
  my ( $self, $fields_arg ) = @_;
  my $array_ref;
  if ( defined $fields_arg ) {
    $array_ref = [ @$fields_arg ];
    arrayref_remove ( $array_ref, 'doc_id', 'record_last_modified' );
    # check to make sure these are all legal columns
    foreach my $col ( @$array_ref ) {
      die "no such field as '$col' known\n"  unless
        $self->{_Iterator_index}->column_type($col);
    }
  } else {
    $array_ref = [ $self->{_Iterator_index}->columns() ];
  }
  my $i=1;
  my %pos_hash = map { $_ => $i++ } @$array_ref;
  return ( [ @$array_ref ], { %pos_hash } );
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
  unless ( $order_by_string = $self->{_Iterator_order_by} ) {
    $order_by_string =
      $self->{_Iterator_index}->element('default_order_by')->get();
  }
  # dbg 'odb', $order_by_string;
  return $order_by_string;
}

sub _make_collection_spec {
  my ( $self, $arg ) = @_;
  return '' if ! $arg;
  my $sql = '(';
  my $dtn = $self->{_Iterator_index}->data_table_name();
  my @from_tables;
  my @binary_tables;
  my @sort_tables;
  my $chunks = $spec_parser->statement ( $arg . " END OF STATEMENT" );
  foreach my $chunk ( @{$chunks} ) {
    my $NOT = ''; my $OP = '=';
    my ( $name, $value) = split /:/, $chunk, 2;
    if ( $value ) {
      $NOT = 'NOT'  if  $name =~ s/NOT //;
      $OP = 'LIKE' if $value =~ /\%/;
      my ( $table_name, $type );
      $table_name =
        $self->{_Iterator_index}->collection_table_name ($name,$value);
      push ( @from_tables, $table_name )  if  $table_name;
      $type = $self->{_Iterator_index}->collection_type ( $name );
      if ( $type eq 'stringified' ) {
        if ( $OP eq 'LIKE' ) {
          # we only support partial matches that are "anchored" at the
          # beginning or the end.
          unless ( $value =~ /^\%/ or $value =~ /\%$/ ) {
            die "can only use front- or rear-anchored partial " .
              "matches with collection '$name'\n";
          }
        }
        my $partial =
          $self->{_Iterator_index}->collection_stringify_partial ( $value );
        $sql .= "$table_name.$name $NOT LIKE " .
          $self->{_Iterator_index}->get_dbh()->quote ( "%$partial%" );
      } elsif ( $type eq 'binary table' ) {
        push @binary_tables, $table_name;
        die "can't use NOT with binary-tables-type collection '$name'\n"
          if $NOT;
        $sql .= "$table_name.value $OP " .
          $self->{_Iterator_index}->get_dbh()->quote ( $value );
      } elsif ( $type eq 'many tables' ) {
        die "can't use a partial (%) match with collection '$name'\n"
          if $OP eq 'LIKE';
        $OP = '!=' if $NOT;
        if ( $table_name ) {
          $sql .= "$dtn.doc_id" . $OP . "$table_name.doc_id";
          push @sort_tables, $table_name;
        } else {
          # we didn't get a table name, so we must have asked for a
          # sort table that is so empty it hasn't ever even been
          # created
          $sql .= '1' . $OP . '0';
        }
      }
    } else {
      # no ':' in chunk, so must be a paren or conjunction
      $sql .= " $chunk ";
    }
  }
  $sql .= ')';
  # push all the tables we've seen onto our object-level from_tables
  # array
  XML::Comma::Util::arrayref_remove_dups ( \@from_tables );
  XML::Comma::Util::arrayref_remove ( \@from_tables, $dtn );
  push @{$self->{_Iterator_from_tables}}, @from_tables;
  # make a little bit more sql for all the binary tables we've seen
  # and throw an error if we see any binary table more than once.
  my %seen;
  foreach my $btn ( @binary_tables ) {
    die "can't use one binary-type collection twice in spec\n" if $seen{$btn}++;
    $sql .= " AND $dtn.doc_id=$btn.doc_id";
  }
  # if we have an OR in our sql clause and have dealt with any tables
  # other than the data table, then we need to select DISTINCT. This
  # can be overridden if we already have an explicit 0 in
  # $self->{_Iterator_distinct}, which would presumably come from an
  # instantiation argument.
  if ( (@binary_tables or @sort_tables) and $sql =~ / or /i ) {
    $self->{_Iterator_distinct} = 1 unless defined $self->{_Iterator_distinct};
  }

  #dbg 'collection sql', $sql;
  return $sql;
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
  return $value;
}

sub DESTROY {
#  dbg 'iterator destroy', $_[0],$_[0]->{_Iterator_index}||'<undef>';
#  map { print "  $_ --> " . (${$_[0]}{$_} || '<undef>') . "\n" } keys(%{$_[0]});
  $_[0]->{_Iterator_sth}->finish()  if  $_[0]->{_Iterator_sth};
  $_[0]->{_Iterator_index}->sql_drop_any_temp_tables
    ( $_[0]->{_Iterator_from_tables} )  if  $_[0]->{_Iterator_index};
#  dbg 'done destroying iterator', $_[0]->{_Iterator_index}||'<undef>';
}

####

BEGIN {
$XML::Comma::Indexing::Iterator::spec_grammar = q{

statement: spec "END OF STATEMENT" { $return = $item[1] } | <error>

spec:
       npair conj  spec { $return = [ $item[1], $item[2], @{$item[3]} ] }   |
       npair            { $return = [ $item[1] ] }                          |
       '(' spec ')' conj spec  
         { $return = [ '(', @{$item[2]}, ')', $item[4], @{$item[5]} ] }    |
       '(' spec ')'
         { $return = [ '(', @{$item[2]}, ')' ] }

conj: 'AND' | 'OR'

npair: 'NOT' pair { $return = 'NOT ' . $item[2] } | pair

pair: /\w+/ ":" /[^\s\)]+/                { $return = $item[1].':'.$item[3] } |
      "'" /\w+/ ":" /.+?(?<!\\\)(?=')/ "'"
        { my $value = $item[4]; $return = $item[2].':'.$item[4]; }

};
}


1;
