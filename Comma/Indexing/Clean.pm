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
  # set flags using an (optional) order_by and a (non-optional) limit
  my $order_by = $self->element('order_by')->get() ||
    $index->element('default_order_by')->get();
  sql_set_comma_flags_for_clean( $index,
                                 $table_name,
                                 $self->{_Clean_sort_name},
                                 $self->{_Clean_sort_string},
                                 $order_by,
                                 $self->element('to_size')->get(),
                                 $self->element('erase_where_clause')->get(),
                                 $clean_flag );
  # delete rows with flags set
  sql_delete_where_comma_flags ( $index, $table_name, $clean_flag );
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
}

1;
