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
#    http://xml-comma.org, or read the tutorial included
#    with the XML::Comma distribution at docs/guide.html
#
##

package XML::Comma::SQL::mysql;

use XML::Comma::Util qw( dbg );
use MIME::Base64;

require Exporter;
@ISA = qw ( Exporter );

@EXPORT = qw(
  sql_create_hold_table
  sql_get_hold
  sql_release_hold

  sql_create_index_tables_table
  sql_data_table_definition
  sql_sort_table_definition
  sql_bcollection_table_definition
  sql_textsearch_index_table_definition
  sql_textsearch_defers_table_definition
  sql_index_only_doc_id_type

  sql_textsearch_word_lock
  sql_textsearch_word_unlock
  sql_textsearch_pack_seq_list
  sql_textsearch_unpack_seq_list

  sql_clean_find_orphans
  sql_limit_clause
  sql_create_textsearch_temp_table_stmt
  sql_load_data
  sql_select_returns_count
);

sub sql_create_hold_table {
# mysql doesn't need a hold table -- uses internal get_lock() and
# release_lock()
}

sub sql_get_hold {
  my ( $lock_singlet, $key ) = @_;
  my $dbh = $lock_singlet->get_dbh();
  my $q_lock_name = $dbh->quote ( $key );
  my $sth = $dbh->prepare ( "SELECT GET_LOCK($q_lock_name,86400)" );
  $sth->execute();
  $sth->finish();
}

sub sql_release_hold {
  my ( $lock_singlet, $key ) = @_;
  my $dbh = $lock_singlet->get_dbh();
  my $q_lock_name = $dbh->quote ( $key );
  my $sth = $dbh->prepare ( "SELECT RELEASE_LOCK($q_lock_name)" );
  $sth->execute();
  $sth->finish();
}

sub sql_create_index_tables_table {
my $index = shift();
my $sth = $index->get_dbh()->prepare (
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
    collection     VARCHAR(255),
    index_def      TEXT )"
);
$sth->execute();
$sth->finish();
}

sub sql_data_table_definition {
  return
"CREATE TABLE $_[1] (
  _comma_flag             TINYINT,
  record_last_modified    INT,
  _sq                     INT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
  doc_id ${ \( $_[0]->element('doc_id_sql_type')->get() ) } PRIMARY KEY )";
}

sub sql_sort_table_definition {
  return
"CREATE TABLE $_[1] (
  _comma_flag  TINYINT,
  doc_id ${ \( $_[0]->element('doc_id_sql_type')->get() ) } PRIMARY KEY )";
}

sub sql_bcollection_table_definition {
  my ( $index, $name, %arg ) = @_;
  my $extra_column = '';
  if ( @{$arg{bcoll_el}->elements('field')} ) {
    $extra_column = " extra " .
      $arg{bcoll_el}->element('field')->element('sql_type')->get() . ',';
  }

  return
"CREATE TABLE $name (
  _comma_flag  TINYINT,
  doc_id ${ \( $index->element('doc_id_sql_type')->get() ) },
  value  ${ \( $arg{bcoll_el}->element('sql_type')->get() ) },
  $extra_column
  INDEX(value),
  UNIQUE INDEX(doc_id,value) )";
}

sub sql_textsearch_index_table_definition {
  use XML::Comma::Pkg::Textsearch::Preprocessor;
  my $max_length = $XML::Comma::Pkg::Textsearch::Preprocessor::max_word_length;
  return
"CREATE TABLE $_[1] (
  word  CHAR($max_length)  PRIMARY KEY,
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

sub sql_index_only_doc_id_type {
  return 'INT UNSIGNED';
}

sub sql_textsearch_word_lock {
  my ( $index, $i_table_name, $word ) = @_;
  my $dbh = $index->get_dbh();
  my $q_lock_name = $dbh->quote ( $i_table_name . $word );
  my $sth = $dbh->prepare ( "SELECT GET_LOCK($q_lock_name,1800)" );
  $sth->execute();
  $sth->finish();
}

sub sql_textsearch_word_unlock {
  my ( $index, $i_table_name, $word ) = @_;
  my $dbh = $index->get_dbh();
  my $q_lock_name = $dbh->quote ( $i_table_name . $word );
  my $sth = $dbh->prepare ( "SELECT RELEASE_LOCK($q_lock_name)" );
  $sth->execute();
  $sth->finish();
}

sub sql_textsearch_pack_seq_list {
  shift();
  return pack ( "L*", @_ );
}

sub sql_textsearch_unpack_seq_list {
  return unpack ( "L*", $_[1] );
}

sub sql_clean_find_orphans {
  my ( $table_name, $data_table_name ) = @_;
  return "SELECT $table_name.doc_id from $table_name LEFT JOIN $data_table_name ON $table_name.doc_id = $data_table_name.doc_id WHERE $data_table_name.doc_id is NULL";
}


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

sub sql_create_textsearch_temp_table_stmt {
  my ( $index, $dbh ) = @_;
  my $temp_table_name = '_temp_' . $$ . '_' . int(rand(0xffffffff));
  my $sth = $dbh->prepare ( "CREATE TEMPORARY TABLE $temp_table_name ( id VARCHAR(255) PRIMARY KEY ) TYPE=HEAP" );
  $sth->execute();
  $sth->finish();
  return $temp_table_name;
}

sub sql_load_data {
  my ( $index, $dbh, $temp_table_name, $temp_filename ) = @_;
  my $sth = $dbh->prepare ( "LOAD DATA LOCAL INFILE \"$temp_filename\" REPLACE INTO TABLE $temp_table_name" );
  $sth->execute();
  $sth->finish();
}

sub sql_select_returns_count {
  return 1;
}

1;
