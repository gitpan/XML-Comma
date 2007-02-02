# A work in progress -- not yet close to functional. There are lots of
# issues with our assumptions about how to handle errors versus who
# sqlite throws them, with autocommit stuff, with the "schema has
# changed" error the sqlite throws, and with frequent mid-script
# losses of connection to the db.

#   here's a block for the Configuration file
#

# sqlite => {
#              sql_syntax  =>  'SQLite',
#              dbi_connect_info => [
#                                   'DBI:SQLite:test.db', '', '',
#                                   { RaiseError => 1,
#                                     PrintError => 1,
#                                     ShowErrorStatement => 1,
#                                     AutoCommit => 1,
#   HandleError => sub {
#     my ( $string, $handle ) = @_;
#     # print "handling error ($handle)\n";
#     if ( $string =~ m|schema has changed| ) {
#       $handle->execute();
#       return 1;
#     }
#     return;
#   }
#                                   } ],
#             },

package XML::Comma::SQL::SQLite;

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

  sql_alter_data_table_drop_or_modify
  sql_alter_data_table_add
  sql_alter_data_table_add_collection
  sql_alter_data_table_add_index
  sql_alter_data_table_drop_index

);

use strict;

sub sql_create_hold_table {
#   my $dbh = shift();
#   dbg 'creating hold table';
#   my $sth = $dbh->prepare
#     ( "CREATE TABLE comma_hold ( key VARCHAR(255) UNIQUE)" );
#   $sth->execute();
#   $sth->finish();
}

sub sql_get_hold {
#   my ( $lock_singlet, $key ) = @_;
#   my $dbh = $lock_singlet->get_dbh();
#   my $q_lock_name = $dbh->quote ( $key );
#   dbg 'getting hold', $dbh, $q_lock_name;
#   my $sth = $dbh->prepare
#     ( "INSERT INTO comma_hold (key) VALUES ($q_lock_name)" );
#   $sth->execute();
#   $sth->finish();
}

sub sql_release_hold {
#   my ( $lock_singlet, $key ) = @_;
#   my $dbh = $lock_singlet->get_dbh();
#   my $q_lock_name = $dbh->quote ( $key );
#   dbg 'releasing hold', $dbh, $q_lock_name;
#   my $sth = $dbh->prepare ( "DELETE FROM comma_hold WHERE key = $q_lock_name" );
#   my $return = $sth->execute();
#   $sth->finish();
}

sub sql_create_index_tables_table {
my $index = shift();
my $sth = $index->get_dbh()->prepare (
"CREATE TABLE index_tables
  ( _comma_flag    INTEGER,
    _sq            INTEGER PRIMARY KEY,
    doctype        VARYING CHARACTER(255),
    index_name     VARYING CHARACTER(255),
    table_name     VARYING CHARACTER(255),
    table_type     INTEGER,
    last_modified  INTEGER,
    sort_spec      VARYING CHARACTER(255),
    textsearch     VARYING CHARACTER(255),
    collection     VARYING CHARACTER(255),
    index_def      CLOB )"
);
$sth->execute();
$sth->finish();
$index->get_dbh->commit;
}


sub sql_sort_table_definition {
  return
"CREATE TABLE $_[1] (
  _comma_flag  INT2,
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
#   my ( $index, $i_table_name, $word ) = @_;
#   my $dbh = $index->get_dbh();
#   $dbh->{AutoCommit}=0;
#   $dbh->commit();
#   my $sth = $dbh->prepare
#     ( "LOCK TABLE $i_table_name IN SHARE ROW EXCLUSIVE MODE" );
#   $sth->execute();
#   $sth->finish();
}

sub sql_textsearch_word_unlock {
#   my ( $index, $i_table_name, $word ) = @_;
#   my $dbh = $index->get_dbh();
#   #my $q_lock_name = $dbh->quote ( $i_table_name . $word );
#   $dbh->commit();
#   $dbh->{AutoCommit}=1;
#   #$dbh->do ( "COMMIT WORK" );
}


sub sql_index_only_doc_id_type {
  return 'INTEGER';
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


# SQLite needs to do these the hard way -- creating a temp table and
# stuff. there is no difference between drop and modify, in the
# mechanics, and the field_name and field_type variables are not used
# (the def fields are pulled instead).
sub sql_alter_data_table_drop_or_modify {}
sub sql_alter_data_table_add            {}
sub sql_alter_data_table_add_collection {}
sub sql_alter_data_table_add_index      {}
sub sql_alter_data_table_drop_index     {}



sub sql_data_table_definition {
  my $columns = join ', ', $_[0]->columns();
  return
"CREATE TABLE $_[1] (
  $columns, 
  _comma_flag             INTEGER,
  record_last_modified    INTEGER,
  _sq                     INTEGER PRIMARY KEY,
  doc_id ${ \( $_[0]->element('doc_id_sql_type')->get() ) } )";
}

sub sql_create_data_table {
  my ( $index, $existing_table_name ) = @_;
  return $index->sql_create_a_table
    ( table_type          => XML::Comma::Indexing::Index->DATA_TABLE_TYPE(),
      index_def           => $index->to_string(),
      table_def_sub       => 'sql_data_table_definition',
      existing_table_name => $existing_table_name );
}




sub _alter_by_recreating {
  my ( $index, $field_name ) = @_;
  my $temp_table_name = "t$$" . '_' . int(rand(0xffffffff));
  my $data_table_name = $index->data_table_name();

#   my @columns = $index->columns();
#   foreach ( 0..$#columns ) {
#     if ( $columns[$_] eq $field_name ) {
#       splice @columns, $_, 1;
#       last;
#     }
#   }

  dbg "altering", $field_name;
  my $dbh = $index->get_dbh();
  $dbh->do (
            "CREATE TABLE $temp_table_name AS SELECT * FROM $data_table_name"
           );
  $dbh->do ( "DROP TABLE $data_table_name" );
  $index->_create_new_data_table ( $data_table_name );
  $dbh->do (
            "INSERT INTO $data_table_name ( _comma_flag, doc_id, record_last_modified, _sq, ${ \( join(', ',$index->columns()) ) } ) SELECT _comma_flag, doc_id, record_last_modified, _sq, ${ \( join(', ',$index->columns()) ) } FROM $temp_table_name"
           );
  $dbh->do ( "DROP TABLE $temp_table_name" );
  return '';
}




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


