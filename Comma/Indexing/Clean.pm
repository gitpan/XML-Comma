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

package XML::Comma::Indexing::Clean;

@ISA = ( 'XML::Comma::NestedElement' );

use XML::Comma::Util qw( dbg );
use XML::Comma::SQL::Base;

use Carp ();
use strict;

# what to stick in the _comma_flag slots while we work
my $clean_flag = 2;

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


# _Clean_Index
# _Clean_table_name
# _Clean_sort_name
# _Clean_sort_string
# _Clean_in_progress

sub init_and_cast {
  my ( $class, %args ) = @_;
  my $self = $args{element} || die "need an element";
  $self->{_Clean_Index} = $args{index} || die "need an index";
  $self->{_Clean_table_name} = $args{table_name} || die "need a table name";
  $self->{_Clean_bcollection_table_names} =
    $args{bcollection_table_names} || [];
  $self->{_Clean_sort_name} = $args{sort_name};
  $self->{_Clean_sort_string} = $args{sort_string};
  bless ( $self, $class );
  return $self;
}

sub clean {
  my $self = shift();
  my $index = $self->{_Clean_Index};
  my $table_name = $self->{_Clean_table_name};
  my $dbh = $index->get_dbh();
  my $erase_where_clause = eval { $self->element('erase_where_clause')->get() };
  # don't clean if table _comma flag is set
  if ( sql_get_table_comma_flag($index, $table_name) ) {
    print "skipping clean on $table_name...";
    return;
  }
  $self->{_Clean_in_progress} = 1;
  # set table _comma flag
  sql_set_table_comma_flag ( $index, $table_name, $clean_flag );
  # dbg 'cleaning', $table_name;
  # for table we care about: clear all _comma flags
  sql_clear_all_comma_flags ( $index, $table_name );
  # first pass clean: for sort tables removes orphan entries, for data
  # tables removes rows matching any erase_where_clause
  sql_set_comma_flags_for_clean_first_pass
    ( $index,
      $table_name,
      $erase_where_clause,
      $clean_flag );
  sql_delete_where_comma_flags ( $index, $table_name, $clean_flag );
  # second pass clean: arranges rows in order and removes rows above
  # our to_size limit
  if ( my $size_limit = $self->element('to_size')->get() ) {
    sql_set_comma_flags_for_clean_second_pass
      ( $index,
        $table_name,
        $self->element('order_by')->get() ||
          $index->element('default_order_by')->get(),
        $self->{_Clean_sort_name}, $self->{_Clean_sort_string},
        $size_limit,
        $clean_flag );
    sql_delete_where_comma_flags ( $index, $table_name, $clean_flag );
  }
  # and if we have any bcollection tables to clean, do them, too. it's
  # pretty kludgy to do this here rather than in a separate chunk of
  # code, but that's okay. at least we know everything's already set
  # up if we just go ahead and clean the bcollection tables inside our
  # data table clean "envelope". so we're not going to set the table
  # comma flags, etc. the sql looping in here also ought to be
  # combined with the nearly-identical loop in
  # sql_set_comma_flags_for_clean_second_pass. finally, we assume that
  # there are bcollection_table_names in our local slot only if this
  # Clean was created to work on the data table (but we don't check
  # that, to make sure). so our $table_name is the data table
  # name. (see, I told you it was kludgy)
  foreach my $bctn ( @{$self->{_Clean_bcollection_table_names}} ) {
    sql_clear_all_comma_flags ( $index, $bctn );
    my $sth = $dbh->prepare
      ( $index->sql_clean_find_orphans ($bctn, $table_name) );
    $sth->execute();
    while ( my $row = $sth->fetchrow_arrayref() ) {
      my $orphan_id = $row->[0];
      $dbh->do ( "UPDATE $bctn SET _comma_flag=$clean_flag WHERE doc_id="
                 . $dbh->quote($orphan_id) );
    }
    sql_delete_where_comma_flags ( $index, $bctn, $clean_flag );
  }
  # unset comma flag
  sql_unset_table_comma_flag ( $index,$table_name );
  $self->{_Clean_in_progress} = 0;
}

sub DESTROY {
  my $self = shift();
  if ( $self->{_Clean_in_progress} && $self->{_Clean_Index} ) {
    # un-set table _comma flag
    sql_unset_table_comma_flag( $self->{_Clean_Index},
                                $self->{_Clean_table_name} );
  }
  undef $self->{_Clean_Index};
}

1;
