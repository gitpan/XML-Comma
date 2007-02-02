use strict;
$|++;

use lib ".test/lib/";

use XML::Comma;
use XML::Comma::Util qw( dbg );

print "1..10\n";


# erase everything, so that we start fresh
my $index = XML::Comma::Def->_test_index_only->get_index ( "main" );
print "ok 1\n";

my $it = $index->iterator();
while ( ++$it ) {
  my $doc = $it->retrieve_doc();
  dbg 'id', $doc->doc_id();
  $doc->erase();
}
print "ok 2\n";

my $second_index = XML::Comma::Def->_test_index_only->get_index ( "second" );

my $second_it = $second_index->iterator();
while ( ++$second_it ) {
  my $doc = $second_it->retrieve_doc();
  dbg 'id', $doc->doc_id();
  $doc->erase();
}

my $doc = XML::Comma::Doc->new ( type => '_test_index_only' );
print "ok 3\n";

$doc->time ( time );
$doc->string ( "foo" );
$doc->store ( store => 'main' );
print "ok 4\n";

my $id = $doc->doc_id();
print "id: $id\n";

undef $doc;
$doc = XML::Comma::Doc->read ( "_test_index_only|main|$id" );
print "ok 5\n";
print "ok 6\n"  if  $doc->string() eq 'foo';

$doc->get_lock();
$doc->erase();
print "ok 7\n";

undef $doc;
eval {
  $doc = XML::Comma::Doc->read ( "_test_index_only|main|$id" );
}; if ( $@ ) {
  print "ok 8\n";
}

# let's see how long it takes to create these things
my $how_many = 150;
my $stop_id = $id + $how_many;
my $first_time = time;

while ( $id < $stop_id ) {
  $doc = XML::Comma::Doc->new ( type => '_test_index_only' );
  $doc->time ( time );
  $doc->string ( "bar" );
  $doc->store ( store => 'main' );
  $id = $doc->doc_id();
}
print "ok 9\n";

$doc = XML::Comma::Doc->read ( "_test_index_only|main|$id" );
my $last_time = $doc->time();
my $seconds = $last_time - $first_time;

print "ok 10\n";

print "  (note: we created and stored $how_many docs in $seconds seconds)\n";

foreach my $id ( 1 .. 10 ) {
  $doc = XML::Comma::Doc->new( type => '_test_index_only' );
  $doc->time( time );
  $doc->string( $id );
  $doc->store( store => 'second' );
  # warn $doc->doc_id();
}

