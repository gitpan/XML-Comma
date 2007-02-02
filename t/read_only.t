#!/usr/bin/perl -w

use strict;
use File::Path;

print "1..8\n";

use XML::Comma;
use XML::Comma::Util qw( dbg random_an_string );

sub modify {
  my $doc = shift();
  $doc->element('a')->set( random_an_string(8) );
  $doc->b()->element('b_1')->set ( random_an_string(8) );
  $doc->b()->b_2()->element('b_2_1')->set ( random_an_string(8) );
  $doc->c()->set ( random_an_string(8) );

  $doc->a ( 'some', 'more', 'elements' );
  $doc->delete_element ( $doc->elements('a')->[-1] );

  $doc->b()->b_1 ( 'some', 'more', 'elements' );
  $doc->b()->delete_element ( $doc->b()->elements('b_1')->[-1] );

  $doc->b()->b_2()->b_2_1 ( 'some', 'more', 'elements' );
  $doc->b()->b_2()->delete_element 
    ( $doc->b()->b_2()->elements('b_2_1')->[-1] );
}

my $doc = XML::Comma::Doc->new ( type => '_test_read_only' );

rmtree ( $doc->def()->get_store('main')->base_directory(), 0 );

# store keeping open
$doc->store ( store=>'main', keep_open => 1 );
&modify ( $doc );
print "ok 1\n";

# copy keeping open
$doc->copy( keep_open => 1 );
&modify ( $doc );
print "ok 2\n";

# store again
$doc->store();
eval { &modify ( $doc ); };
print "ok 3\n"  if  $@;


$doc = XML::Comma::Doc->new ( type => '_test_read_only' );

# store
$doc->store( store=>'main' );
eval { &modify ( $doc ); };
print "ok 4\n"  if  $@;

# get lock
$doc->get_lock();
&modify ( $doc );
print "ok 5\n";

# copy
$doc->copy();
eval { &modify ( $doc ); };
print "ok 6\n"  if  $@;

# get lock
$doc->get_lock();
&modify ( $doc );
print "ok 7\n";

# unlock
$doc->doc_unlock();
eval { &modify ( $doc ); };
print "ok 8\n"  if  $@;

# aaah
