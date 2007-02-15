use strict;
use File::Path;

use Test::More tests => 10;

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
ok("created stays the same")  if  $doc->created eq $created;
ok("last modified increases")  if  $doc->last_modified > $last_modified;
$last_modified = $doc->last_modified;

sleep 1;

$doc->store ( keep_open => 1, no_mtime => 1 );
ok("no_mtime works")  if  $doc->last_modified == $last_modified;

$created = $doc->created();
$last_modified = $doc->last_modified();

sleep 1;

#TODO: better document this case, it's confusing
$doc->store ( store => 'two', keep_open => 1 );
ok("created stays the same #2")  if  $doc->created eq $created;
ok("last modified increases #2")  if  $doc->last_modified > $last_modified;

$created = $doc->created();
$last_modified = $doc->last_modified();

sleep 1;

# shouldn't change, for 'other' store
$doc->store ( store => 'other' );
ok("created stays the same on store to other")  if  $doc->created eq $created;
ok("last modified stays the same with store to another store")  if  $doc->last_modified eq $last_modified;

undef $doc;
$doc = XML::Comma::Doc->read ( $doc_key );
ok("created defined and non-zero")  if  $doc->created();
ok("last_modified defined and non-zero")  if  $doc->last_modified();

# test whether simple output of a non-writable doc causes problems
$doc->to_string();
ok("to_string of r/o doc")
