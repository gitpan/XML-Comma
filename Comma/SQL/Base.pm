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

package XML::Comma::SQL::Base;

require Exporter;
@ISA = qw ( Exporter );

# FIX: separate these into :tags

@EXPORT = qw(
  sql_create_lock_table
  sql_create_hold_table
  sql_get_lock_record
  sql_doc_lock
  sql_doc_unlock
  sql_delete_locks_held_by_this_pid
  sql_get_hold
  sql_release_hold

  sql_create_a_table
  sql_create_index_tables_table
  sql_create_data_table
  sql_data_table_definition
  sql_data_table_name
  sql_get_def
  sql_update_def_in_tables_table

  sql_alter_data_table_drop_or_modify
  sql_alter_data_table_add
  sql_alter_data_table_add_collection
  sql_alter_data_table_add_index
  sql_alter_data_table_drop_index
  sql_insert_into_data
  sql_update_in_data
  sql_delete_from_data
  sql_get_sq_from_data_table

  sql_create_sort_table
  sql_sort_table_definition
  sql_get_sort_table_for_spec
  sql_get_sort_spec_for_table
  sql_get_sort_tables
  sql_insert_into_sort
  sql_delete_from_sort

  sql_create_textsearch_tables
  sql_textsearch_index_table_definition
  sql_textsearch_defers_table_definition
  sql_drop_textsearch_tables
  sql_get_textsearch_tables
  sql_textsearch_word_lock
  sql_textsearch_word_unlock
  sql_textsearch_pack_seq_list
  sql_textsearch_unpack_seq_list
  sql_update_in_textsearch_index_table
  sql_delete_from_textsearch_index_table
  sql_textsearch_defer_delete
  sql_textsearch_defer_update
  sql_delete_from_textsearch_defers_table
  sql_get_textsearch_defers_sth
  sql_get_textsearch_indexed_words
  sql_get_textsearch_index_packed
  sql_create_textsearch_temp_table
  sql_create_textsearch_temp_table_stmt
  sql_load_data
  sql_drop_any_temp_tables

  sql_id_indexed_p
  sql_seq_indexed_p
  sql_simple_rows_count
  sql_drop_table
  sql_update_timestamp
  sql_get_timestamp

  sql_get_table_comma_flag
  sql_set_table_comma_flag
  sql_set_all_table_comma_flags_politely
  sql_get_all_tables_with_comma_flags_set
  sql_unset_all_table_comma_flags
  sql_unset_table_comma_flag
  sql_clean_find_orphans
  sql_set_comma_flags_for_clean
  sql_set_all_comma_flags
  sql_clear_all_comma_flags
  sql_delete_where_not_comma_flags
  sql_delete_where_comma_flags

  sql_select_from_data
  sql_limit_clause
  sql_select_aggregate
);

use strict;
use XML::Comma::Util qw( dbg );

# some of the sql statements that get used, grouped here for
# readability and overrideability. $index (and, usually, $_[0]) refers
# to an Index object, $dbh to a dbh handle, and $doc to a Doc
# object. string arguments vary depending on the statement.

sub sql_create_lock_table {
my $dbh = shift();
$dbh->do (
"CREATE TABLE comma_lock
        ( doc_key         VARCHAR(255) UNIQUE,
          pid             INT,
          info            VARCHAR(255),
          time            INT )" );
}

sub sql_create_hold_table {
# mysql doesn't need a hold table -- uses internal get_lock() and
# release_lock()
}

# $dbh, $key
sub sql_get_lock_record {
my $sth = $_[0]->prepare ( 
"SELECT doc_key,pid,info,time FROM comma_lock WHERE doc_key='$_[1]'" );
$sth->execute();
my $result = $sth->fetchrow_arrayref();
return $result ? { doc_key => $result->[0],
                   pid     => $result->[1],
                   info    => $result->[2],
                   time    => $result->[3] } : '';
}

# dbh
sub sql_delete_locks_held_by_this_pid {
  $_[0]->do ( 'DELETE from comma_lock WHERE pid=' .
              $_[0]->quote($$) );
}

# $dbh, $key - returns 1 if row-insert succeeds, 0 on duplicate
# key. throws error for any error other than duplicate key.
sub sql_doc_lock {
eval { $_[0]->do (
"INSERT INTO comma_lock ( doc_key, pid, time)
                 VALUES ( '$_[1]', $$, ${ \( time() ) } )" );
}; if ( $@ ) {
  if ( $@ =~ /duplicate/i ) {
    # print "lock on $_[1] failed\n";
    return 0;
  }
  die "$@\n";
}
return 1;
}

# $dbh, $key
sub sql_doc_unlock {
$_[0]->do ( "DELETE FROM comma_lock WHERE doc_key = '$_[1]'" );
}


sub sql_get_hold {
  my ( $lock_singlet, $key ) = @_;
  my $dbh = $lock_singlet->get_dbh();
  my $q_lock_name = $dbh->quote ( $key );
  $dbh->do ( "SELECT GET_LOCK($q_lock_name,86400)" );
}

sub sql_release_hold {
  my ( $lock_singlet, $key ) = @_;
  my $dbh = $lock_singlet->get_dbh();
  my $q_lock_name = $dbh->quote ( $key );
  $dbh->do ( "SELECT RELEASE_LOCK($q_lock_name)" );
}

#
# --------------------------------
#


sub sql_create_index_tables_table {
my $index = shift();
$index->get_dbh()->do (
"CREATE TABLE index_tables
  ( _comma_flag    TINYINT,
    _sq            INT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
    doctype        VARCHAR(255),
    index_name     VARCHAR(255),
    table_name     VARCHAR(255),
    table_type     TINYINT,
    last_modified  INT,
    sort_spec      VARCHAR(255),
    textsearch     VARCHAR(255),
    index_def      TEXT )"
);
}

#  table_type => const for the table_type column
#  table_def_sub => string of sub name to call to get table def
#  existing_table_name => pass this to *re_create* a table under old name
#  index_def => string for index_def column (if any)
#  sort_spec => string for sort_spec column (if any)
#  textsearch => string for text_search column (if any)
sub sql_create_a_table {
  my ( $index, %arg ) = @_;
  my $dbh = $index->get_dbh();
  my $q_doctype = $dbh->quote ( $index->doctype() );
  my $q_index_name = $dbh->quote ( $index->element('name')->get() );
  my $name;
  my $table_def_sub = $arg{table_def_sub} || die "need table def sub";
  my $index_def = $dbh->quote ( $arg{index_def} || '' );
  my $sort_spec = $dbh->quote ( $arg{sort_spec} || '' );
  my $textsearch = $dbh->quote ( $arg{textsearch} || '' );

  if ( ! $arg{existing_table_name} ) {
    # add an appropriate line to the index table
    $dbh->do ( "INSERT INTO index_tables ( doctype, index_name, last_modified, _comma_flag, index_def, sort_spec, textsearch, table_type ) VALUES ( $q_doctype, $q_index_name, ${ \( time() ) }, 0, $index_def, $sort_spec, $textsearch, $arg{table_type} )" );

    # make a name for that table
    my $stub = substr ( $index->doctype(), 0, 8 );
    my $sth = $dbh->prepare( "SELECT _sq FROM index_tables WHERE doctype=$q_doctype AND index_name=$q_index_name AND table_type=$arg{table_type} AND index_def=$index_def AND sort_spec=$sort_spec AND textsearch=$textsearch" );
    $sth->execute();
    my $s = $sth->fetchrow_arrayref()->[0];
    $name = $stub . '_' . sprintf ( "%04s", $s );
    my $q_t_name = $dbh->quote ( $name );
    $dbh->do ( "UPDATE index_tables SET table_name=$q_t_name WHERE _sq=$s" );
  } else {
    $name = $arg{existing_table_name};
  }

  # now make the table
  $dbh->do ( $index->$table_def_sub($name) );
  return $name;
}

sub sql_create_data_table {
  my ( $index, $existing_table_name ) = @_;
  return $index->sql_create_a_table
    ( table_type          => XML::Comma::Indexing::Index->DATA_TABLE_TYPE(),
      index_def           => $index->to_string(),
      table_def_sub       => 'sql_data_table_definition',
      existing_table_name => $existing_table_name );
}

sub sql_data_table_definition {
  return
"CREATE TABLE $_[1] (
  _comma_flag             TINYINT,
  record_last_modified    INT,
  _sq                     INT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
  doc_id ${ \( $_[0]->element('doc_id_sql_type')->get() ) } PRIMARY KEY )";
}

sub sql_data_table_name {
my $index = shift();
my $dbh = $index->get_dbh();
my $sth = $dbh->prepare (
"SELECT table_name from index_tables WHERE doctype=${ \( $dbh->quote($index->doctype()) ) } AND index_name=${ \($dbh->quote($index->element('name')->get()) ) } AND table_type=${ \( XML::Comma::Indexing::Index->DATA_TABLE_TYPE() )}" );
$sth->execute();
my $result = $sth->fetchrow_arrayref();
return $result ? $result->[0] : die "FIX: no data table name found\n";
}


sub sql_get_def {
my $index = shift();
my $dbh = $index->get_dbh();
my $sth = $dbh->prepare( 'SELECT index_def FROM index_tables WHERE doctype=' .
  $dbh->quote($index->doctype()) . ' AND index_name=' .
  $dbh->quote($index->element('name')->get()) . ' AND table_type=' .
  $index->DATA_TABLE_TYPE() );
$sth->execute();
my $result = $sth->fetchrow_arrayref();
return $result ? $result->[0] : '';
}

sub sql_update_def_in_tables_table {
my $index = shift();
my $dbh = $index->get_dbh();
$dbh->do ( "UPDATE index_tables SET index_def=${ \( $dbh->quote($index->to_string()) ) } WHERE table_name=${ \( $dbh->quote($index->data_table_name()) ) }" );
}


# handles drop or modify. if there is a third arg, we assume that's a
# column type, and this is a modify.
sub sql_alter_data_table_drop_or_modify {
  my ( $index, $field_name, $field_type ) = @_;
  if ( $field_type ) {
    $index->get_dbh()->do ( "ALTER TABLE " . $index->data_table_name() .
                            " MODIFY $field_name $field_type" );
  } else {
    $index->get_dbh()->do ( "ALTER TABLE " . $index->data_table_name() .
                            " DROP $field_name" );
  }
}

sub sql_alter_data_table_add {
my ( $index, $field_name, $field_type ) = @_;
$index->get_dbh()->do ( "ALTER TABLE ${ \($index->data_table_name()) } " .
                        "ADD $field_name $field_type" );
}

sub sql_alter_data_table_add_collection {
my ( $index, $field_name ) = @_;
$index->get_dbh()->do ( "ALTER TABLE ${ \($index->data_table_name()) } " .
                        "ADD $field_name TEXT" );
}

sub sql_alter_data_table_add_index {
my ( $index, $sql_index ) = @_;
my $unique = ( $sql_index->element('unique')->get() ? 'UNIQUE' : '' );
my $fields = $sql_index->element( 'fields' )->get();
my $sql_index_name = $sql_index->element('name')->get() ||
  die "sql_index must have a name\n";
my $data_table_name = $index->data_table_name();
$index->get_dbh()->do ( "CREATE $unique INDEX $sql_index_name ON $data_table_name ($fields)" );
}

sub sql_alter_data_table_drop_index {
eval {
$_[0]->get_dbh()->do ( "DROP INDEX $_[1] ON ${ \( $_[0]->data_table_name() ) }" );
}; if ( $@ ) {
  XML::Comma::Log->warn ( "warning: couldn't drop index $_[1]" );
}
}

# FIX: is always dbh-quoting the doc_id the right thing?
sub sql_insert_into_data {
  my ( $index, $doc, $comma_flag ) = @_;
  $comma_flag ||= 0;
  my $dbh = $index->get_dbh();

  my @columns = $index->columns();
  my $columns_list = join ( ',', 'doc_id', @columns );
  my $columns_values = 
    join ( ',', $dbh->quote($doc->doc_id()),
           map {
             $dbh->quote ( $index->column_value($_, $doc,) )
           } @columns );

my $string = 'INSERT INTO ' . $index->data_table_name() .
" ( _comma_flag, record_last_modified, $columns_list ) VALUES ( $comma_flag, ${\( time() )}, $columns_values )";

  #print "sql: $string\n";
  $dbh->do ( $string );
}

sub sql_update_in_data {
  my ( $index, $doc, $comma_flag ) = @_;
  $comma_flag = $comma_flag || 0;
  my $dbh = $index->get_dbh();

  my $columns_sets = join 
    ( ',', "_comma_flag=$comma_flag",
      "record_last_modified=${\( time() )}",
      map {
        $_ . '=' . $dbh->quote( $index->column_value($_,$doc) )
      } $index->columns() );

  $dbh->do ( "UPDATE ${ \( $index->data_table_name ) } SET $columns_sets WHERE doc_id = ${ \( $dbh->quote($doc->doc_id()) ) }" );
}

sub sql_delete_from_data {
my ( $index, $doc ) = @_;
my $dbh = $index->get_dbh();
$dbh->do (
"DELETE FROM ${ \( $index->data_table_name() ) } WHERE doc_id = ${ \( $dbh->quote($doc->doc_id()) ) }" );
}

sub sql_create_sort_table {
  my ( $index, $sort_spec ) = @_;
  return $index->sql_create_a_table
    ( table_type    => XML::Comma::Indexing::Index->SORT_TABLE_TYPE(),
      table_def_sub => 'sql_sort_table_definition',
      sort_spec     => $sort_spec );
}

sub sql_sort_table_definition {
  return
"CREATE TABLE $_[1] (
  _comma_flag  TINYINT,
  doc_id ${ \( $_[0]->element('doc_id_sql_type')->get() ) } PRIMARY KEY )";
}

sub sql_get_sort_table_for_spec {
my ( $index, $sort_spec ) = @_;
my $dbh = $index->get_dbh();
my $q_doctype = $dbh->quote ( $index->doctype() );
my $q_index_name = $dbh->quote ( $index->element('name')->get() );
my $q_sort_spec = $dbh->quote ( $sort_spec );
my $sth = $dbh->prepare ( "SELECT table_name FROM index_tables WHERE doctype=$q_doctype AND index_name=$q_index_name AND sort_spec=$q_sort_spec" );
$sth->execute();
my $result = $sth->fetchrow_arrayref();
return  $result ? $result->[0] : '';
}

sub sql_get_sort_spec_for_table {
my ( $index, $table_name ) = @_;
my $dbh = $index->get_dbh();
my $sth = $dbh->prepare (
"SELECT sort_spec FROM index_tables WHERE table_name=${ \( $dbh->quote($table_name) ) }" );
$sth->execute();
my $result = $sth->fetchrow_arrayref();
return  $result ? $result->[0] : '';
}

# sort_name is optional -- if not given, just returns all sort tables
sub sql_get_sort_tables {
my ( $index, $sort_name ) = @_;
my $dbh = $index->get_dbh();
my $sth = $dbh->prepare (
"SELECT table_name FROM index_tables WHERE doctype=${ \( $dbh->quote($index->doctype()) ) } AND index_name=${ \( $dbh->quote($index->element('name')->get()) ) } AND table_type=${ \( $index->SORT_TABLE_TYPE() ) } " .
  ($sort_name ? ('AND sort_spec LIKE ' . $dbh->quote($index->make_sort_spec($sort_name,'') . '%')) : '') );
$sth->execute();
return  map { $_->[0] } @{$sth->fetchall_arrayref()};
}


sub sql_insert_into_sort {
  my ( $index, $doc, $sort_table_name ) = @_;
  $index->get_dbh()->do ( "INSERT INTO $sort_table_name ( _comma_flag, doc_id ) VALUES ( 0, '${ \( $doc->doc_id() ) }' )" );
}

# returns the number of rows deleted
sub sql_delete_from_sort {
my ( $index, $doc, $sort_table_name ) = @_;
return $index->get_dbh()->do (
"DELETE FROM $sort_table_name WHERE doc_id = '${ \( $doc->doc_id() ) }'" );
}


sub sql_create_textsearch_tables {
  my ( $index, $textsearch ) = @_;
  $index->sql_create_a_table
    ( table_type => XML::Comma::Indexing::Index->TEXTSEARCH_INDEX_TABLE_TYPE(),
      table_def_sub       => 'sql_textsearch_index_table_definition',
      textsearch          => $textsearch->element('name')->get() );
  $index->sql_create_a_table
    ( table_type => XML::Comma::Indexing::Index->TEXTSEARCH_DEFERS_TABLE_TYPE(),
      table_def_sub       => 'sql_textsearch_defers_table_definition',
      textsearch          => $textsearch->element('name')->get() );
  return 1;
}

sub sql_textsearch_index_table_definition {
  return
"CREATE TABLE $_[1] (
  word  CHAR(12)  PRIMARY KEY,
  seqs  MEDIUMBLOB )";
}

sub sql_textsearch_defers_table_definition {
  return
"CREATE TABLE $_[1] (
  doc_id        ${ \( $_[0]->element('doc_id_sql_type')->get() ) },
  action        TINYINT,
  text          MEDIUMBLOB,
  _sq           INT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE )";
}


sub sql_drop_textsearch_tables {
  my ( $index, $textsearch_name ) = @_;
  my $dbh = $index->get_dbh();
  my $sth = $dbh->prepare ( "SELECT table_name FROM index_tables WHERE textsearch=${ \( $dbh->quote($textsearch_name) ) }" );
  $sth->execute();
  while ( my $row = $sth->fetchrow_arrayref() ) {
    my $table_name = $row->[0];
    $dbh->do ( "DROP TABLE $table_name" );
    $dbh->do ( "DELETE FROM index_tables WHERE table_name=${ \( $dbh->quote($table_name) ) }" );
  }
}

sub sql_get_textsearch_tables {
  my ( $index, $textsearch_name ) = @_;
  my $dbh = $index->get_dbh();
  my $sth = $dbh->prepare ( "SELECT table_name FROM index_tables WHERE textsearch=${ \( $dbh->quote($textsearch_name) ) } ORDER BY table_type" );
  $sth->execute();
  return map { $_->[0] } @{$sth->fetchall_arrayref()};
}

sub sql_textsearch_word_lock {
  my ( $index, $i_table_name, $word ) = @_;
  my $dbh = $index->get_dbh();
  my $q_lock_name = $dbh->quote ( $i_table_name . $word );
  $dbh->do ( "SELECT GET_LOCK($q_lock_name,1800)" );
}

sub sql_textsearch_word_unlock {
  my ( $index, $i_table_name, $word ) = @_;
  my $dbh = $index->get_dbh();
  my $q_lock_name = $dbh->quote ( $i_table_name . $word );
  $dbh->do ( "SELECT RELEASE_LOCK($q_lock_name)" );
}

sub sql_textsearch_pack_seq_list {
  shift();
  return pack ( "L*", @_ );
}

sub sql_textsearch_unpack_seq_list {
  return unpack ( "L*", $_[1] );
}

# pass EITHER a single doc_id or a list of doc_seqs.
sub sql_update_in_textsearch_index_table {
  my ( $index, $i_table_name, $word, $doc_id, $clobber, @doc_seqs ) = @_;
  my $dbh = $index->get_dbh();
  my $q_word = $dbh->quote ( $word );
  # generate a sequence if we were passed an id
  if ( $doc_id ) {
    @doc_seqs = ( $index->sql_get_sq_from_data_table($doc_id) );
  }
  # just return without doing anything if we turn out not to have any
  # @doc_seqs. unless we're in $clobber mode, in which case we want to
  # enter an empty record.
  return if ! @doc_seqs and ! $clobber;
  my $packed = $index->sql_textsearch_pack_seq_list ( @doc_seqs );
  $index->sql_textsearch_word_lock ( $i_table_name, $word );
  # modify row
  my $sth =
    $dbh->prepare ( "SELECT seqs FROM $i_table_name WHERE word=$q_word" );
  $sth->execute();
  my $result = $sth->fetchrow_arrayref();
  $sth->finish();
  if ( $result ) {
    # if found, update
    my $new_seqs_string;
    if ( $result->[0] and ! $clobber ) {
      $new_seqs_string = $dbh->quote ( $result->[0] . $packed);
    } else {
      $new_seqs_string = $dbh->quote ( $packed );
    }
    $dbh->do ( "UPDATE $i_table_name SET seqs=$new_seqs_string WHERE word=$q_word" );
  } else {
    # else insert
    $dbh->do ( "INSERT INTO $i_table_name ( word, seqs ) VALUES ( $q_word, ${ \( $dbh->quote($packed) ) } )" );
  }
  $index->sql_textsearch_word_unlock ( $i_table_name, $word );
}

sub sql_get_sq_from_data_table {
  my ( $index, @doc_ids ) = @_;
  my @list;
  my $dbh = $index->get_dbh();
  my $data_table_name = $index->data_table_name();
  foreach my $id ( @doc_ids ) {
    my $q_id = $dbh->quote ( $id );
    my $sth = $dbh->prepare ( "SELECT _sq from $data_table_name WHERE doc_id=$q_id" );
    $sth->execute();
    my $result = $sth->fetchrow_arrayref();
    push ( @list, $result->[0] )  if  $result;
  }
  return @list;
}

sub sql_delete_from_textsearch_index_table {
  my ( $index, $ts_table_name, $doc_id ) = @_;
  my ( $sq ) = $index->sql_get_sq_from_data_table($doc_id);
  # shortcut to return if this doc isn't indexed
  return if ! $sq;
  my $packed_sq = $index->sql_textsearch_pack_seq_list ( $sq );
  # loop over all entries conatining $doc's id
  #dbg 'trying to delete', $doc_id, $ts_table_name;
  my $dbh = $index->get_dbh();
  my $sth = $dbh->prepare ( "SELECT word FROM $ts_table_name WHERE seqs LIKE ${ \( $dbh->quote('%'.$packed_sq.'%') ) }" );
  $sth->execute();
  while ( my $row = $sth->fetchrow_arrayref() ) {
    my $word = $row->[0];
    my $q_word = $dbh->quote ( $word );
    # get lock
    $index->sql_textsearch_word_lock ( $ts_table_name, $word );
    # fetch seqs column now that we have lock
    my $locked_sth =
      $dbh->prepare ( "SELECT seqs FROM $ts_table_name WHERE word=$q_word" );
    $locked_sth->execute();
    my $result = $locked_sth->fetchrow_arrayref();
    $locked_sth->finish();
    # remove the seq in question and re-put
    my %seqs = map { $_=>1 }
      $index->sql_textsearch_unpack_seq_list ( $result->[0] );
    delete $seqs{$sq};
    my $q_packed_seqs = $dbh->quote
      ( $index->sql_textsearch_pack_seq_list(keys %seqs) );
    $dbh->do ( "UPDATE $ts_table_name SET seqs=$q_packed_seqs WHERE word=$q_word" );
    # release lock
    $index->sql_textsearch_word_unlock ( $ts_table_name, $word );
  }
}

# DEFER DELETE ACTION CONST = 1;
# DEFER UPDATE ACTION CONST = 2;

sub sql_textsearch_defer_delete {
  my ( $index, $d_table_name, $doc_id ) = @_;
  my $dbh = $index->get_dbh();
  my $q_doc_id = $dbh->quote ( $doc_id );
  $dbh->do ( "INSERT INTO $d_table_name ( doc_id, action ) VALUES ( $q_doc_id, 1 )" );
}

sub sql_textsearch_defer_update {
  my ( $index, $d_table_name, $doc_id, $frozen_words ) = @_;
  my $dbh = $index->get_dbh();
  my $q_doc_id = $dbh->quote ( $doc_id );
  my $q_text = $dbh->quote ( $frozen_words );
  $dbh->do ( "INSERT INTO $d_table_name ( doc_id, action, text ) VALUES ( $q_doc_id, 2, $q_text )" );
}

sub sql_get_textsearch_defers_sth {
  my ( $index, $d_table_name ) = @_;
  my $sth = $index->get_dbh()->prepare ( "SELECT doc_id, action, _sq, text FROM $d_table_name ORDER BY _sq" );
  $sth->execute();
  return $sth;
}

sub sql_delete_from_textsearch_defers_table {
  my ( $index, $d_table_name, $doc_id, $seq ) = @_;
  my $dbh = $index->get_dbh();
  my $q_doc_id = $dbh->quote ( $doc_id );
  $index->get_dbh()->do ( "DELETE FROM $d_table_name WHERE doc_id=$q_doc_id AND _sq <= $seq" );
}

sub sql_get_textsearch_indexed_words {
  my ( $index, $i_table_name ) = @_;
  my $sth = $index->get_dbh()->prepare ( "SELECT word FROM $i_table_name" );
  $sth->execute();
  return map { $_->[0] } @{$sth->fetchall_arrayref()};
}

sub sql_get_textsearch_index_packed {
  my ( $index, $i_table_name, $word ) = @_;
  my $dbh = $index->get_dbh();
  my $q_word = $dbh->quote ( $word );
  my $sth = $dbh->prepare ( "SELECT seqs FROM $i_table_name WHERE word=$q_word");
  $sth->execute();
  my $result = $sth->fetchrow_arrayref();
  return  $result ? $result->[0] : '';
}

# returns count
sub sql_id_indexed_p {
  my ( $index, $id ) = @_;
  my $dbh = $index->get_dbh();
  my $sth = $dbh->prepare ( "SELECT count(*) from ${ \( $index->data_table_name() ) } WHERE doc_id = ${ \( $dbh->quote($id) ) }" );
  $sth->execute();
  return $sth->fetchrow_arrayref->[0];
}

# returns count
sub sql_seq_indexed_p {
  my ( $index, $seq ) = @_;
  my $dbh = $index->get_dbh();
  my $sth = $dbh->prepare ( "SELECT count(*) from ${ \( $index->data_table_name() ) } WHERE _sq = ${ \( $dbh->quote($seq) ) }" );
  $sth->execute();
  return $sth->fetchrow_arrayref->[0];
}

# args: $index, $table_name
sub sql_simple_rows_count {
  my ( $index, $table_name ) = @_;
  my $sth = $index->get_dbh()->prepare ( "SELECT count(*) from $table_name" );
  $sth->execute();
  return $sth->fetchrow_arrayref()->[0];
}

# both drops the table and removes the index_tables entry
sub sql_drop_table {
  my ( $index, $table_name ) = @_;
  my $dbh = $index->get_dbh();
  $dbh->do ( "DROP TABLE $table_name" );
  $dbh->do ( 'DELETE FROM index_tables WHERE table_name=' .
             $dbh->quote ($table_name) );
}

sub sql_update_timestamp {
my ( $index, $table_name ) = @_;
$index->get_dbh()->do (
"UPDATE index_tables SET last_modified=${ \( time() ) } WHERE table_name = '$table_name'" );
}

# returns timestamp -- (also used to check whether a table exists)
sub sql_get_timestamp {
my ( $index, $table_name ) = @_;
my $sth = $index->get_dbh()->prepare (
"SELECT last_modified FROM index_tables WHERE table_name = '$table_name'" );
$sth->execute();
my $result = $sth->fetchrow_arrayref();
return  $result ? $result->[0] : '';
}


# returns flag value
sub sql_get_table_comma_flag {
my ( $index, $table_name ) = @_;
my $sth = $index->get_dbh()->prepare ( 
"SELECT _comma_flag FROM index_tables WHERE table_name = '$table_name'" );
$sth->execute();
my $result = $sth->fetchrow_arrayref();
return $result ? $result->[0] : '';
}

sub sql_set_table_comma_flag {
my ( $index, $table_name, $flag_value ) = @_;
$index->get_dbh()->do ( 
"UPDATE index_tables SET _comma_flag=$flag_value WHERE table_name = '$table_name'" );
}

sub sql_set_all_table_comma_flags_politely {
my ( $index, $flag_value ) = @_;
my $dbh = $index->get_dbh();
my $index_name = $dbh->quote( $index->element('name')->get() );
$dbh->do (
"UPDATE index_tables SET _comma_flag=$flag_value WHERE index_name=$index_name AND _comma_flag=0" );
}

sub sql_get_all_tables_with_comma_flags_set {
my ( $index, $ignore_flag ) = @_;
my $dbh = $index->get_dbh();
my $index_name = $dbh->quote( $index->element('name')->get() );
my $sth = $dbh->prepare (
"SELECT table_name FROM index_tables WHERE index_name=$index_name AND ((_comma_flag != 0) AND (_comma_flag != $ignore_flag))" );
$sth->execute();
return  map { $_->[0] } @{$sth->fetchall_arrayref()};
}

sub sql_unset_all_table_comma_flags {
my ( $index ) = @_;
my $dbh = $index->get_dbh();
my $index_name = $dbh->quote( $index->element('name')->get() );
$dbh->do (
"UPDATE index_tables SET _comma_flag=0 WHERE index_name=$index_name" );
}

sub sql_unset_table_comma_flag {
my ( $index, $table_name ) = @_;
$index->get_dbh()->do ( "UPDATE index_tables SET _comma_flag=0 WHERE table_name = '$table_name'" );
}

sub sql_set_all_comma_flags {
my ( $index, $table_name, $flag_value ) = @_;
$index->get_dbh()->do ( "UPDATE $table_name SET _comma_flag=$flag_value" );
}

sub sql_clear_all_comma_flags {
my ( $index, $table_name ) = @_;
$index->get_dbh()->do ( "UPDATE $table_name SET _comma_flag=0" );
}

sub sql_clean_find_orphans {
  my ( $index, $table_name, $data_table_name ) = @_;
  return "SELECT $table_name.doc_id from $table_name LEFT JOIN $data_table_name ON $table_name.doc_id = $data_table_name.doc_id WHERE $data_table_name.doc_id is NULL";
}

sub sql_set_comma_flags_for_clean {
  my ( $index, $table_name, $sort_name, $sort_string, $order_by,
       $size_limit, $erase_where_clause, $flag_value ) = @_;

  my $dbh = $index->get_dbh();

  ## first we want to deal with orphan rows in the sort tables. these
  ## can be created in small numbers by the normal fact of entries
  ## being cleaned from the data table before they are removed from
  ## the sort tables. orphans can be created in large numbers by an
  ## aborted rebuild() or other large operation.
  my $data_table_name = $index->data_table_name();
  if ( $table_name ne $data_table_name ) {
    my $sth = $dbh->prepare
      ( $index->sql_clean_find_orphans ($table_name,
                                        $data_table_name) );
    $sth->execute();
    while ( my $row = $sth->fetchrow_arrayref() ) {
      my $orphan_id = $row->[0];
      # print ( "orphan($table_name:$orphan_id)..." );
      $dbh->do ( "UPDATE $table_name SET _comma_flag=$flag_value WHERE doc_id="
                 . $dbh->quote($orphan_id) );
    }
  }

  my $sort_spec = '';
  if ( $sort_name && $sort_string ) {
    $sort_spec = "$sort_name:$sort_string";
  }

  # first set the clean flag for an erase_where_clause, if there is one
  if ( $erase_where_clause ) {
    $dbh->do
 ("UPDATE $table_name SET _comma_flag=$flag_value WHERE $erase_where_clause");
  }

  # now set the flag for everything after the first size_limit entries
  if ( $size_limit ) {
    my $i = $index->iterator ( order_by => $order_by,
                               sort_spec => $sort_spec );
    $i->iterator_refresh ( 0xffffff, $size_limit ); # blech, hack
    while ( $i->iterator_next() ) {
      my $id = $i->doc_id();
      $dbh->do
        ("UPDATE $table_name SET _comma_flag=$flag_value WHERE doc_id='$id'");
    }
  }
}

sub sql_delete_where_not_comma_flags {
  my ( $index, $table_name, $flag_value ) = @_;
  $index->get_dbh->do ( 
"DELETE FROM $table_name WHERE _comma_flag != $flag_value" );
}


sub sql_delete_where_comma_flags {
  my ( $index, $table_name, $flag_value ) = @_;
  $index->get_dbh()->do (
"DELETE FROM $table_name WHERE _comma_flag = $flag_value" );
}


sub sql_select_aggregate {
my ( $index, $aggregate, $field_name, $table_name ) = @_;
my $sth = $index->get_dbh()->prepare (
"SELECT $aggregate($field_name) FROM $table_name" );
$sth->execute();
my $result = $sth->fetchall_arrayref();
return $result ? $result->[0]->[0] : '';
}

##
# complex select statement build -- for iterator
#
sub sql_select_from_data {
  my ( $self, $order_by_expressions, $from_tables, $where_clause,
       $sort_spec, $order_by, $limit_number, $limit_offset, $collection_spec,
       $textsearch_spec,
       $do_count_only, $aggregate_function ) = @_;

  # the core part of the statement
  my $select;
  if ( $aggregate_function ) {
    $select = "SELECT $aggregate_function"  if  $aggregate_function;
  } else {
    if ( $do_count_only ) {
      $select = 
        "SELECT COUNT(${ \( $self->data_table_name() ) }.doc_id)";
    } else {
      $select = join
        ( ',',
          "SELECT " . $self->data_table_name() . '.doc_id',
          $self->columns(),
          "${ \( $self->data_table_name() ) }.record_last_modified" );
    }
  }

  # extra expressions to select for (the Iterator would have determined
  # that these are used in the order_by)
  my @evalled_order_by_list;
  foreach my $el ( @{$order_by_expressions} ) {
    my $expr = $el->element('expression')->get();
    my $evalled = eval $expr;
    if ( $@ ) {
      die "error while eval'ing order_by '$expr': $@\n";
    }
    push @evalled_order_by_list, [ $el->element('name')->get(), $evalled ];
  }
  my $extra_order_by = join ( ',' , map {
    ' (' . $_->[1] . ') as ' . $_->[0]
  } @evalled_order_by_list );
  $extra_order_by = ',' . $extra_order_by  if  $extra_order_by;

  # from tables
  my $from = ' FROM ' . join ( ',', @{$from_tables} );

  # where clause
  my $where = ' WHERE 1=1';
  $where .= " AND ($sort_spec)"        if  $sort_spec;
  $where .= " AND ($where_clause)"     if  $where_clause;
  $where .= " AND ($collection_spec)"  if  $collection_spec;
  $where .= " AND ($textsearch_spec)"  if  $textsearch_spec;

  # order by clause
  my $order = '';
  if ( $order_by ) {
    $order =  " ORDER BY $order_by";
  }

  # limit what the db server gives back
  my $limit = $self->sql_limit_clause ( $limit_number, $limit_offset );

  # return either a regular statement, a count() statement, or an
  # aggregate statement
  if ( $aggregate_function ) {
    # aggregate ignores limit stuff
    return $select . $from . $where;
  } elsif ( $do_count_only ) {
    # count_only ignores limit stuff
    return $select. $from . $where;
  } else {
    # my ( $package, $filename, $line ) = caller(2);
    #print $select.$extra_order_by.$from.$where.$order.$limit . "\n";
    return $select . $extra_order_by . $from . $where . $order . $limit;
  }
}
#
##

sub sql_limit_clause {
  my ( $index, $limit_number, $limit_offset ) = @_;
  if ( $limit_number ) {
    if ( $limit_offset ) {
      return " LIMIT $limit_offset, $limit_number";
    } else {
      return " LIMIT $limit_number";
    }
  } else {
    return '';
  }
}

sub sql_create_textsearch_temp_table {
  my ( $index, $ts_index_table_name, $word ) = @_;
  my $dbh = $index->get_dbh();
  my $packed =
    $index->sql_get_textsearch_index_packed ( $ts_index_table_name, $word ) ||
      return ( '', 0 );

  my ($temp_fh, $temp_filename ) = File::Temp::tempfile
    ( 'comma_db_XXXXXX', DIR => XML::Comma->tmp_directory() );
  my @unpacked = $index->sql_textsearch_unpack_seq_list($packed);
  print $temp_fh join ( "\n", @unpacked ) . "\n";
  close ( $temp_fh );
  chmod 0644, $temp_filename;

  my $temp_table_name = $index->sql_create_textsearch_temp_table_stmt ( $dbh );
  $index->sql_load_data ( $dbh, $temp_table_name, $temp_filename );

  unlink ( $temp_filename );

  #dbg 'tt/s', $temp_table_name, $count;
  return ( $temp_table_name, $#unpacked );
}

sub sql_create_textsearch_temp_table_stmt {
  my ( $index, $dbh ) = @_;
  my $temp_table_name = '_temp_' . $$ . '_' . int(rand(0xffffffff));
  $dbh->do ( "CREATE TEMPORARY TABLE $temp_table_name ( id VARCHAR(255) PRIMARY KEY ) TYPE=HEAP" );
  return $temp_table_name;
}

sub sql_load_data {
  my ( $index, $dbh, $temp_table_name, $temp_filename ) = @_;
  $dbh->do ( "LOAD DATA LOCAL INFILE \"$temp_filename\" REPLACE INTO TABLE $temp_table_name" );
}

sub sql_drop_any_temp_tables {
  my ( $index, @tables_list ) = @_;
  my $dbh = $index->get_dbh();
  foreach my $t ( grep { /^_temp/ } @tables_list ) {
    $dbh->do ( "drop table $t" );
  }
}

1;

