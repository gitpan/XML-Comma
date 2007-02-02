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

# PORTING NOTES: started working on making the pg stuff work with
# textsearches, and stopped when it became clear that the "seqs"
# fields need to store arrays of numbers, rather than to be packed, as in mysql.

package XML::Comma::SQL::Pg;

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
);

use strict;

sub sql_create_hold_table {
  my $dbh = shift();
  dbg 'creating hold table';
  $dbh->commit();
  my $sth = $dbh->prepare
    ( "CREATE TABLE comma_hold ( key VARCHAR(255) UNIQUE)" );
  $sth->execute();
  $sth->finish();
  $dbh->commit();
}

sub sql_get_hold {
  my ( $lock_singlet, $key ) = @_;
  my $dbh = $lock_singlet->get_dbh();
  my $q_lock_name = $dbh->quote ( $key );
  # dbg 'dbh', $dbh;
  $dbh->{AutoCommit}=0;
  $dbh->commit();
  my $sth = $dbh->prepare
    ( "INSERT INTO comma_hold (key) VALUES ($q_lock_name)" );
  $sth->execute();
  $sth->finish();
}

sub sql_release_hold {
  my ( $lock_singlet, $key ) = @_;
  my $dbh = $lock_singlet->get_dbh();
  my $q_lock_name = $dbh->quote ( $key );
  my $sth = $dbh->prepare ( "DELETE FROM comma_hold WHERE key = $q_lock_name" );
  $sth->execute();
  $sth->finish();
  $dbh->commit();
  $dbh->{AutoCommit}=1;
}

sub sql_create_index_tables_table {
my $index = shift();
my $sth = $index->get_dbh()->prepare (
"CREATE TABLE index_tables
  ( _comma_flag    INT2,
    _sq            SERIAL,
    doctype        VARCHAR(255),
    index_name     VARCHAR(255),
    table_name     VARCHAR(255),
    table_type     INT2,
    last_modified  INT,
    sort_spec      VARCHAR(255),
    textsearch     VARCHAR(255),
    collection     VARCHAR(255),
    index_def      TEXT )"
);
$sth->execute();
$sth->finish();
}


sub sql_sort_table_definition {
  return
"CREATE TABLE $_[1] (
  _comma_flag  INT2,
  doc_id ${ \( $_[0]->element('doc_id_sql_type')->get() ) } PRIMARY KEY )";
}


sub sql_data_table_definition {
  return
"CREATE TABLE $_[1] (
  _comma_flag             INT2,
  record_last_modified    INT4,
  _sq                     SERIAL,
  doc_id ${ \( $_[0]->element('doc_id_sql_type')->get() ) } PRIMARY KEY )";
}

sub sql_bcollection_table_definition {
  my ( $index, $name, %arg ) = @_;
  my $extra_column = '';
  if ( @{$arg{bcoll_el}->elements('field')} ) {
    $extra_column = ", extra " .
      $arg{bcoll_el}->element('field')->element('sql_type')->get();
  }

  return
"CREATE TABLE $name (
  _comma_flag  INT2,
  doc_id ${ \( $index->element('doc_id_sql_type')->get() ) },
  value   ${ \( $arg{bcoll_el}->element('sql_type')->get() ) }
  $extra_column
 );
 CREATE INDEX bci_$name ON $name (value)";
}


sub sql_textsearch_index_table_definition {
  my $max_length = $XML::Comma::Pkg::Textsearch::Preprocessor::max_word_length;
  return
"CREATE TABLE $_[1] (
  word  CHAR($max_length)  PRIMARY KEY,
  seqs  TEXT )";
}

sub sql_textsearch_defers_table_definition {
  return
"CREATE TABLE $_[1] (
  doc_id        ${ \( $_[0]->element('doc_id_sql_type')->get() ) },
  action        INT2,
  text          TEXT,
  _sq           SERIAL )";
}

sub sql_textsearch_word_lock {
  my ( $index, $i_table_name, $word ) = @_;
  my $dbh = $index->get_dbh();
  $dbh->{AutoCommit}=0;
  $dbh->commit();
  my $sth = $dbh->prepare
    ( "LOCK TABLE $i_table_name IN SHARE ROW EXCLUSIVE MODE" );
  $sth->execute();
  $sth->finish();
}

sub sql_textsearch_word_unlock {
  my ( $index, $i_table_name, $word ) = @_;
  my $dbh = $index->get_dbh();
  #my $q_lock_name = $dbh->quote ( $i_table_name . $word );
  $dbh->commit();
  $dbh->{AutoCommit}=1;
  #$dbh->do ( "COMMIT WORK" );
}


sub sql_index_only_doc_id_type {
  return 'INT4';
}


# yech. should we be trying to use the non-standard array *= operators
# in postgres to do this textsearch stuff?
sub sql_textsearch_pack_seq_list {
  shift();
  #return MIME::Base64::encode_base64( pack("L*", @_), '' );
  return join ( '-', @_ ) . '-';
}

sub sql_textsearch_unpack_seq_list {
  #return unpack ( "L*", MIME::Base64::decode_base64($_[1]) );
  chop ( $_[1] );
  return split ( '-', $_[1] );
}


# Postgres needs to do these the hard way -- creating a temp table and
# stuff. there is no difference between drop and modify, in the
# mechanics, and the field_name and field_type variables are not used
# (the def fields are pulled instead).
#  sub sql_alter_data_table_drop_or_modify {
#    my ( $index, $field_name, $field_type ) = @_;

#    my $temp_table_name = "t$$";
#    my $data_table_name = $index->data_table_name();

#    my $dbh = $index->get_dbh();
#    $dbh->do (
#              "CREATE TABLE $temp_table_name AS SELECT _comma_flag, doc_id, record_last_modified, _sq, ${ \( join(', ',$index->columns()) ) } FROM $data_table_name"
#             );
#    $dbh->do ( "DROP TABLE $data_table_name" );
#    $dbh->do ( "DROP SEQUENCE $data_table_name" . '__sq_seq' );
#    $index->_create_new_data_table ( $data_table_name );
#    $dbh->do (
#              "INSERT INTO $data_table_name ( _comma_flag, doc_id, record_last_modified, _sq, ${ \( join(', ',$index->columns()) ) } ) SELECT _comma_flag, doc_id, record_last_modified, _sq, ${ \( join(', ',$index->columns()) ) } FROM $temp_table_name"
#             );
#    $dbh->do ( "DROP TABLE $temp_table_name" );
#    return '';
#  }


# this update w/ subselect ought to work, but Pg won't allow the order
# by in the subselect. maybe oracle?
#
#
#  # args: index, table_name, order_by, size_limit
#  sub sql_set_comma_flags {
#    my ( $index, $table_name, $order_by, $size_limit ) = @_;
#    my $data_table_name = $index->data_table_name();
#    my $dbh = $index->get_dbh();
#    my $sel = $dbh->do
#   ("UPDATE $table_name SET _comma_flag=1 WHERE doc_id IN
#     (SELECT S.doc_id FROM $table_name AS S, $data_table_name AS D
#      WHERE S.doc_id = D.doc_id ORDER BY D.$order_by LIMIT $size_limit)");
#  }


sub sql_clean_find_orphans {
  my ( $table_name, $data_table_name ) = @_;
  return "SELECT $table_name.doc_id FROM $table_name WHERE $table_name.doc_id NOT IN (SELECT $data_table_name.doc_id FROM $data_table_name)";
}

sub sql_limit_clause {
  my ( $index, $limit_number, $limit_offset ) = @_;
  if ( $limit_number ) {
    if ( $limit_offset ) {
      return " LIMIT $limit_number OFFSET $limit_offset";
    } else {
      return " LIMIT $limit_number";
    }
  } else {
    return '';
  }
}

#  sub sql_create_textsearch_temp_table {
#    my ( $index, $ts_index_table_name, $word ) = @_;
#    my $dbh = $index->get_dbh();
#    my $packed =
#      $index->sql_get_textsearch_index_packed ( $ts_index_table_name, $word );

#    my $temp_table_name;
#    my $count;

#    if ( $packed ) {
#      $temp_table_name = '_temp_' . $$ . '_' . int(rand(0xffffff));
#      $dbh->do ( "CREATE TEMPORARY TABLE $temp_table_name ( id VARCHAR(255) PRIMARY KEY )" );
#      my %seen;
#      foreach ( $index->sql_textsearch_unpack_seq_list($packed) ) {
#        $count++;
#        next if $seen{$_}++;
#        my $value = $dbh->quote ( $_ );
#        $dbh->do ( "INSERT INTO $temp_table_name (id) VALUES ($value)" );
#      }
#    } else {
#      return ('',0);
#    }
#    #dbg 'tt/s', $temp_table_name, $count;
#    return ( $temp_table_name, $count );
#  }

sub sql_create_textsearch_temp_table_stmt {
  my ( $index, $dbh ) = @_;
  my $temp_table_name = '_temp_' . $$ . '_' . int(rand(0xffffffff));
  $dbh->do ( "CREATE TEMPORARY TABLE $temp_table_name ( id VARCHAR(255) PRIMARY KEY )" );
  return $temp_table_name;
}

sub sql_load_data {
  my ( $index, $dbh, $temp_table_name, $temp_filename ) = @_;
  $dbh->do ( "COPY $temp_table_name FROM '$temp_filename'" );
}



1;


