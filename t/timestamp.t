use strict;
use File::Path;

print "1..10\n";

use lib ".test/lib/";

use XML::Comma;
use XML::Comma::Util qw( dbg );


####
my $def = XML::Comma::Def->read ( name => '_test_timestamp' );
rmtree $def->get_store('one')->base_directory, 0;
rmtree $def->get_store('two')->base_directory, 0;
rmtree $def->get_store('other')->base_directory, 0;
####

my $doc = XML::Comma::Doc->new ( type => '_test_timestamp' );
$doc->store ( store => 'one', keep_open => 1 );
my $doc_key = $doc->doc_key();
my $created = $doc->created();
my $last_modified = $doc->last_modified();

sleep 1;

$doc->store ( keep_open => 1 );
print "ok 1\n"  if  $doc->created eq $created;
print "ok 2\n"  if  $doc->last_modified > $last_modified;
$last_modified = $doc->last_modified;

sleep 1;

$doc->store ( keep_open => 1, no_mtime => 1 );
print "ok 3\n"  if  $doc->last_modified == $last_modified;

$created = $doc->created();
$last_modified = $doc->last_modified();

sleep 1;

$doc->store ( store => 'two', keep_open => 1 );
print "ok 4\n"  if  $doc->created eq $created;
print "ok 5\n"  if  $doc->last_modified > $last_modified;

$created = $doc->created();
$last_modified = $doc->last_modified();

sleep 1;

# shouldn't change, for 'other' store
$doc->store ( store => 'other' );
print "ok 6\n"  if  $doc->created eq $created;
print "ok 7\n"  if  $doc->last_modified eq $last_modified;

undef $doc;
$doc = XML::Comma::Doc->read ( $doc_key );
print "ok 8\n"  if  $doc->created();
print "ok 9\n"  if  $doc->last_modified();

# test whether simple output of a non-writable doc causes problems
$doc->to_string();
print "ok 10\n"
