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

package XML::Comma::SQL::Lock;

@ISA = qw( XML::Comma::SQL::DBH_User );

use strict;
use XML::Comma;
use XML::Comma::Util qw( dbg );
use XML::Comma::SQL::DBH_User;
use XML::Comma::SQL::Base;

my $LOCK_LOOP_WAIT_SECONDS = 3;

BEGIN {
  # suppress warnings (subroutine redefined warnings are expected)
  local $^W = 0;
  if ( my $syntax = XML::Comma::SQL::DBH_User->db_struct()->{sql_syntax} ) {
    # try to use()
    eval "use XML::Comma::SQL::$syntax";
    # report failure
    if ( $@ ) {
      XML::Comma::Log->err ( 'SQL_IMPORT_ERROR',
                             "trouble importing $syntax: $@\n" );
    }
  }
}

sub new {
  my $class = shift();
  my $self = {};
  bless $self, $class;
  my $dbh = $self->get_dbh();
  # check for hold table -- setup if necessary
  eval { sql_get_hold($self, '_startup_test_hold_');
         sql_release_hold($self, '_startup_test_hold_'); };
  if ( $@ ) {
    # dbg 'hold error', $@;
    # release hold to "commit" the aborted transaction
    sql_create_hold_table($dbh);
    sql_release_hold($self,'_startup_test_hold_');
  }
  # check for lock table -- setup if necessary
  eval { sql_get_lock_record($dbh,'++') };
  if ( $@ ) {
    sql_get_hold($self, '_startup_create_lock_');
    # check again
    eval { sql_get_lock_record($dbh,'++') };
    if ( $@ ) {
      sql_create_lock_table($dbh);
    }
    sql_release_hold($self, '_startup_create_lock_');
  }
  return $self;
}

# $self, $key, $no_block
sub lock {
  my ( $self, $key, $no_block, $timeout ) = @_;
  # dbg 'locking', $key;
  my $dbh = $self->get_dbh();
  my $locked = sql_doc_lock ( $dbh, $key );
  if ( $locked || $no_block ) {
    return $locked;
  }
  my $waited = 0;
  my $lr = sql_get_lock_record ( $dbh, $key );
  while ( ! defined $timeout or $waited < $timeout ) {
    # check to see if we're allowed to treat this lock as expired
    $self->maybe_unlock ( $lr->{pid}, $key );
    # try to lock again
    if ( sql_doc_lock($dbh,$key) ) { return 1; }
    # sleep and keep going round and round
    sleep $LOCK_LOOP_WAIT_SECONDS;
    $waited += $LOCK_LOOP_WAIT_SECONDS;
  }
  XML::Comma::Log->err ( 'LOCK_TIMEOUT', "timed out waiting for lock on $key" );
}

# $self, $key
sub unlock {
  # dbg 'unlocking', $_[1];
  sql_doc_unlock ( $_[0]->get_dbh(), $_[1] );
}

sub maybe_unlock {
  my ( $self, $pid, $key ) = @_;
  my $lr = sql_get_lock_record($self->get_dbh(), $key);
  return unless $lr;
  if ( $lr->{info} eq Sys::Hostname::hostname ) {
    my $plist = Proc::ProcessTable->new();
    foreach my $p ( @{$plist->table()} ) {
      return  if  $p->pid() == $pid;
    }
    $self->unlock ( $key );
  }
}


####
##
## DEPRECATED -- the string-based hold methods don't really work as
## intended, given some futziness with the mysql implementation.
##
##

# generic, string-based "hold". this can be used to implement a
# temporary lock without using the special doc lock table.
sub wait_for_hold {
  sql_get_hold ( $_[0], $_[1] );
}

sub release_hold {
  sql_release_hold ( $_[0], $_[1] );
}

sub release_all_my_locks {
  sql_delete_locks_held_by_this_pid ( $_[0]->get_dbh() );
}

##
##
####


# FIX: make destroy unlock all locks held by this pid?
sub DESTROY {
  # print 'D: ' . $_[0] . "\n";
  $_[0]->disconnect();
}







