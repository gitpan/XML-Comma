#!/usr/bin/perl -w
$|++;

use strict;
use FindBin;
use File::Path;


my $test_dir =  '/usr/local/comma/docs/test';

print "1..89\n";

use XML::Comma;
use XML::Comma::Util qw( dbg );



my $doc_block_a = <<END;
<_test_indexing>
  <foo>foo!</foo>
  <bar>bar!</bar>
  <many1>a</many1><many1>b</many1><many1>c</many1>
  <many2>a a</many2><many2>b b</many2><many2>c c</many2>
    <many2>d d</many2>
  <paragraph>The quick brown fox JUMPED over a goldfish and a
             lazy brown dog</paragraph>
  <nel><buried>hello</buried></nel>
</_test_indexing>
END

my $doc_block_b = <<END;
<_test_indexing>
  <foo>foo2</foo>
  <bar>bar2</bar>
  <many1>d</many1><many1>d</many1>
  <many2>d d</many2><many2>d d</many2>
  <paragraph>a stitch in time saves goldfish</paragraph>
  <nel><buried>oo-oo-oo</buried></nel>
</_test_indexing>
END

###########

my $def = XML::Comma::Def->read ( name => '_test_indexing' );
rmtree ( $def->get_store('main')->base_directory() );
rmtree ( $def->get_store('other')->base_directory() );
print "ok 1\n"  if  $def;

## test getting all index names
my $names_string = join ( ',', sort $def->index_names() );
print "ok 2\n"  if  $names_string eq 'main,other';

## test getting index objects out by name
my $index_main = $def->get_index ( 'main' );
my $index_other = $def->get_index ( 'other' );
eval {
  $def->get_index ( 'doesnt exist' );
}; my $error = $@;
print "ok 3\n"  if  $index_main && $index_other && $error;

## ping. twice (just to make sure we don't have a
## connection/instantiation problem. pinging causes a dbh->connect(),
## which triggers the index object initting-and-casting
$index_main->ping();
$index_main->ping();
$index_other->ping();
print "ok 4\n";

####
## Test the indexing of three docs (two copies of "doc_block_a" and
## one of "doc_block_b"), with a few different iterator retrieves.
####

my $i;
# create and store
my $doc = XML::Comma::Doc->new ( block=>$doc_block_a );
print "ok 5\n" if $doc;
$doc->store ( store=>'main', keep_open => 1 );
print "ok 6\n" if $doc->doc_id() eq '0001';
$doc->copy ( store=>'main' );
print "ok 7\n" if $doc->doc_id() eq '0002';
undef $doc;
$doc = XML::Comma::Doc->new ( block=>$doc_block_b );
print "ok 8\n" if $doc;
$doc->store ( store=>'main' );
print "ok 9\n" if $doc->doc_id() eq '0003';

# how many?
print "ok 10\n" if $index_main->count() == 3;

# iterator with no clauses
$i = $index_main->iterator();
print "ok 11\n"  if  $i->doc_id() eq '0003';
print "ok 12\n"  if  $i->foo() eq 'foo2' and $i->bar() eq 'bar2';
print "ok 13\n"  if  join ( '/', sort @{$i->many1_c()} ) eq 'd/d';
print "ok 14\n"  if  join ( '/', sort @{$i->many2_c()} ) eq 'd d/d d';
print "ok 15\n"  if  $i->buried eq 'oo-oo-oo';
$i++;
print "ok 16\n"  if  $i->doc_id() eq '0002';
print "ok 17\n"  if  $i->foo() eq 'foo!' and $i->bar() eq 'bar!';
print "ok 18\n"  if  join ( '/', sort @{$i->many1_c()} ) eq 'a/b/c';
print "ok 19\n"  if  join ( '/', sort @{$i->many2_c()} ) eq 'a a/b b/c c/d d';
print "ok 20\n"  if  $i->buried eq 'hello';
$i++;
print "ok 21\n"  if  $i->doc_id() eq '0001';
$i++;
print "ok 22\n"  unless $i;

# same iterator with fields restricted
$i = $index_main->iterator ( fields => [ 'foo', 'buried' ] );
print "ok 23\n"  if  $i->doc_id() eq '0003';
print "ok 24\n"  if  $i->foo() eq 'foo2';
print "ok 25\n"  if  $i->buried() eq 'oo-oo-oo';
eval { $i->bar() }; print "ok 26\n"  if  $@;

# test asking for a field that doesn't exist
eval { $i = $index_main->iterator ( fields => [ 'okoe' ] ) };
print "ok 27\n"  if  $@;

# get 0001 and 0002 in various ways
sub _chk_0002_0001 {
  my $iterator = shift;
  return unless $iterator->doc_id() eq '0002'; $iterator++;
  return unless $iterator->doc_id() eq '0001'; $iterator++;
  return if $iterator;
  return 1;
}

$i = $index_main->iterator ( where_clause => "foo='foo!'" );
print "ok 28\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_c:a' );
print "ok 29\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_c:b' );
print "ok 30\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_c:c' );
print "ok 31\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_b:a' );
print "ok 32\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_b:b' );
print "ok 33\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_b:c' );
print "ok 34\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_s:a' );
print "ok 35\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_s:b' );
print "ok 36\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_s:c' );
print "ok 37\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_c:b b'" );
print "ok 38\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_c:b%'" );
print "ok 39\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_c:%b'" );
print "ok 40\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_b:b b'" );
print "ok 41\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_b:b%'" );
print "ok 42\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_b:%b'" );
print "ok 43\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_b:b%b'" );
print "ok 44\n"  if  _chk_0002_0001($i);


$i = $index_main->iterator ( collection_spec => "'many2_s:b b'" );
print "ok 45\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "NOT 'many1_c:d'" );
print "ok 46\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "NOT 'many1_s:d'" );
print "ok 47\n"  if  _chk_0002_0001($i);

$i = $index_main->iterator ( textsearch_spec => "paragraph:jumped" );
print "ok 48\n"  if  _chk_0002_0001($i);


# get all 3 in various ways
sub _chk_0003_0002_0001 {
  my $iterator = shift;
  return unless $iterator->doc_id() eq '0003'; $iterator++;
  return unless $iterator->doc_id() eq '0002'; $iterator++;
  return unless $iterator->doc_id() eq '0001'; $iterator++;
  return if $iterator;
  return 1;
}


$i = $index_main->iterator ( collection_spec => "NOT 'many1_c:abcdef'" );
print "ok 49\n"  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "NOT 'many1_s:abcdef'" );
print "ok 50\n"  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_c:b OR many1_c:d" );
print "ok 51\n"  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_s:b OR many1_s:d" );
print "ok 52\n"  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_s:b OR many1_b:d" );
print "ok 53\n"  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_b:b OR many1_s:d" );
print "ok 54\n"  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_c:b OR many1_b:d" );
print "ok 55\n"  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_b:b OR many1_c:d" );
print "ok 56\n"  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_b:%" );
print "ok 57\n"  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( textsearch_spec => "paragraph:goldfish" );
print "ok 58\n"  if  _chk_0003_0002_0001($i);

# test retrieving nothing
$i = $index_main->iterator ( collection_spec => "'many1_c:abcdefg'" );
print "ok 59\n"  unless $i;

$i = $index_main->iterator ( collection_spec => "'many1_b:abcdefg'" );
print "ok 60\n"  unless $i;

$i = $index_main->iterator ( collection_spec => "'many1_s:abcdefg'" );
print "ok 61\n"  unless $i;

$i = $index_main->iterator ( where_clause => "1=0" );
print "ok 62\n"  unless $i;

# test partial get and then refresh
$i = $index_main->iterator();
print "ok 63\n" if (++$i)->doc_id() eq '0003';
$i->iterator_refresh();
print "ok 64\n" if (++$i)->doc_id() eq '0003' and
                   (++$i)->doc_id() eq '0002' and
                   (++$i)->doc_id() eq '0001' and ! (++$i);

# using the same iterator, make sure that advancing off the end of the
# iterator doesn't seem to have any wierd side-effects
$i++;
print "ok 65\n"  unless $i;
print "ok 66\n"  unless defined $i->doc_id();
$i++;
print "ok 67\n"  unless $i;
print "ok 68\n"  unless defined $i->doc_id();

# test "iterator select return value"
$i = $index_main->iterator();
print "ok 69\n" if $i->iterator_select_returnval() == 3;

# key, read_doc and retrieve_doc methods
$i->iterator_refresh();
print "ok 70\n" if $i->doc_key eq '_test_indexing|main|0003';
my $read = $i->read_doc();
print "ok 71\n" if $read->doc_id eq '0003' and $read->foo() eq 'foo2';
undef $read;
my $retrieved = $i->retrieve_doc();
print "ok 72\n" if $retrieved->doc_id eq '0003' and $retrieved->foo() eq 'foo2';
undef $retrieved;


# an aggregate
my $sum = $index_main->aggregate ( function=>"SUM(id_as_number)" );
print "ok 73\n" if $sum == 6;
$sum = $index_main->aggregate ( function=>"SUM(id_as_number)",
                                collection_spec=>"'many1_b:a' OR many1_s:d" );
print "ok 74\n" if $sum == 6;
$sum = $index_main->aggregate ( function=>"SUM(id_as_number)",
                                collection_spec=>"'many2_b:d d'" );
print "ok 75\n" if $sum == 6;
$sum = $index_main->aggregate ( function=>"SUM(id_as_number)",
                                collection_spec=>"'many1_s:c'" );
print "ok 76\n" if $sum == 3;

##
# order_by expressions
$i = $index_main->iterator ( order_by=>'id_mod_3' );
print "ok 77\n" if (++$i)->doc_id() eq '0003' and
                   (++$i)->doc_id() eq '0001' and
                   (++$i)->doc_id() eq '0002' and ! (++$i);

$i = $index_main->iterator ( order_by=>'constant_exp, doc_id' );
print "ok 78\n" if (++$i)->doc_id() eq '0001' and
                   (++$i)->doc_id() eq '0002' and
                   (++$i)->doc_id() eq '0003' and ! (++$i);

$i = $index_main->iterator ( order_by=>'test_eval, doc_id' );
print "ok 79\n" if (++$i)->doc_id() eq '0001' and
                   (++$i)->doc_id() eq '0002' and
                   (++$i)->doc_id() eq '0003' and ! (++$i);


##
# deletion
$i = $index_main->iterator ( where_clause => "foo='foo!'" );
while ( $i++ ) {
  $i->retrieve_doc()->erase();
}
$i = $index_main->iterator();
print "ok 80\n" if $i->doc_id() eq '0003' and ! (++$i);

$i->iterator_refresh();
$i->retrieve_doc()->erase();

$i = $index_main->iterator();
print "ok 81\n" if ! $i;

###
##
## we should have an empty store/index now
##
###

##
## Clean stuff
##

# Both many1_s and many2_s have to_size=3 and size_trigger=5. Let's
# setup to clean the 'a' and 'b' tables. We'll store one common
# document, and then three of each.

my $doc_common = XML::Comma::Doc->new ( type=>'_test_indexing' );
$doc_common->many1 ( 'a', 'b' );
$doc_common->store ( store=>'main', keep_open=>1 );

my $doc_a = XML::Comma::Doc->new ( type=>'_test_indexing' );
$doc_a->many1 ( 'a' );
$doc_a->store ( store=>'main', keep_open=>1);
$doc_a->copy ( keep_open=>1 ); $doc_a->copy ( keep_open=>1 );

my $doc_b = XML::Comma::Doc->new ( type=>'_test_indexing' );
$doc_b->many1 ( 'b' );
$doc_b->store ( store=>'main', keep_open=>1);
$doc_b->copy ( keep_open=>1 ); $doc_b->copy ( keep_open=> 1 );

# now storing one more a document should trigger an 'a' table clean
$doc_a->copy();
$i = $index_main->iterator ( collection_spec=>"many1_s:a",
                             order_by=>'doc_id' );
print "ok 82\n" if (++$i)->doc_id() eq '0006' and
                   (++$i)->doc_id() eq '0007' and
                   (++$i)->doc_id() eq '0011' and ! (++$i);
# but 'b' table should be unchanged
$i = $index_main->iterator ( collection_spec=>"many1_s:b",
                             order_by=>'doc_id' );
print "ok 83\n" if (++$i)->doc_id() eq '0004' and
                   (++$i)->doc_id() eq '0008' and
                   (++$i)->doc_id() eq '0009' and
                   (++$i)->doc_id() eq '0010' and ! (++$i);

# and storing one more common document should trigger a 'b' table clean
$doc_common->copy();
$i = $index_main->iterator ( collection_spec=>"many1_s:b",
                             order_by=>'doc_id' );
print "ok 84\n" if (++$i)->doc_id() eq '0009' and
                   (++$i)->doc_id() eq '0010' and
                   (++$i)->doc_id() eq '0012' and ! (++$i);
# and 'a' table should have one new member
$i = $index_main->iterator ( collection_spec=>"many1_s:a",
                             order_by=>'doc_id' );
print "ok 85\n" if (++$i)->doc_id() eq '0006' and
                   (++$i)->doc_id() eq '0007' and
                   (++$i)->doc_id() eq '0011' and
                   (++$i)->doc_id() eq '0012' and ! (++$i);

# We've stored nine docs (0004-0012). Storing one more doc (0013)
# should trigger an everything-clean. Let's store a 'b' doc, but first
# set a string that will trigger the erase_where_clause, so that this
# doc (0013) gets erased in the clean.
$doc_b->foo ( 'erase this one' );
$doc_b->copy();

# our overall set should now have six docs, 0007-0012
$i = $index_main->iterator ( order_by=>'doc_id' );
print "ok 86\n" if (++$i)->doc_id() eq '0007' and
                   (++$i)->doc_id() eq '0008' and
                   (++$i)->doc_id() eq '0009' and
                   (++$i)->doc_id() eq '0010' and
                   (++$i)->doc_id() eq '0011' and
                   (++$i)->doc_id() eq '0012' and ! (++$i);

# 'a' table should have three docs
$i = $index_main->iterator ( collection_spec=>"many1_s:a",
                             order_by=>'doc_id' );
print "ok 87\n" if (++$i)->doc_id() eq '0007' and
                   (++$i)->doc_id() eq '0011' and
                   (++$i)->doc_id() eq '0012' and ! (++$i);

# as should 'b' table (unhanged, since 0013 matches the
# erase_where_clause and gets dropped during the "first" clean pass)
$i = $index_main->iterator ( collection_spec=>"many1_s:b",
                             order_by=>'doc_id' );
print "ok 88\n" if (++$i)->doc_id() eq '0009' and
                   (++$i)->doc_id() eq '0010' and
                   (++$i)->doc_id() eq '0012' and ! (++$i);

##
## DONE
##

# delete all the docs from the index
$i = $index_main->iterator();
while ( $i++ ) {
  $i->retrieve_doc()->erase();
}

$i = $index_main->iterator();
print "ok 89\n"  unless  $i;
