#!/usr/bin/perl -w
$|++;

use strict;
use FindBin;
use File::Path;

#TODO: convert test::more numbers to useful strings
use Test::More tests => 99;

my $test_dir =  '/usr/local/comma/docs/test';

use lib ".test/lib/";

use XML::Comma;
use XML::Comma::Util qw( dbg );

#for tests on 'stringified' and 'many tables' collections
$XML::Comma::_no_deprecation_warnings = 1;

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
ok("1")  if  $def;

## test getting all index names
my $names_string = join ( ',', sort $def->index_names() );
ok("2")  if  $names_string eq 'main,other';

## test getting index objects out by name
my $index_main = $def->get_index ( 'main' );
my $index_other = $def->get_index ( 'other' );
eval {
  $def->get_index ( 'doesnt exist' );
}; my $error = $@;
ok("3")  if  $index_main && $index_other && $error;


## ping. twice (just to make sure we don't have a
## connection/instantiation problem. pinging causes a dbh->connect(),
## which triggers the index object initting-and-casting
$index_main->ping();
$index_main->ping();
$index_other->ping();
ok("4");

####
## Test the indexing of three docs (two copies of "doc_block_a" and
## one of "doc_block_b"), with a few different iterator retrieves.
####

my $i;
# create and store
my $doc = XML::Comma::Doc->new ( block=>$doc_block_a );
ok("5") if $doc;
$doc->store ( store=>'main', keep_open => 1 );
ok("6") if $doc->doc_id() eq '0001';
$doc->copy ( store=>'main' );
ok("7") if $doc->doc_id() eq '0002';
undef $doc;
$doc = XML::Comma::Doc->new ( block=>$doc_block_b );
ok("8") if $doc;
$doc->store ( store=>'main' );
ok("9") if $doc->doc_id() eq '0003';

# how many?
ok("10") if $index_main->count() == 3;
my $it_for_count_test = $index_main->iterator();
ok("11") if $it_for_count_test->select_count() == 3;

# iterator with no clauses
$i = $index_main->iterator();
ok("12")  if  $i->doc_id() eq '0003';
ok("13")  if  $i->foo() eq 'foo2' and $i->bar() eq 'bar2';
ok("14")  if  join ( '/', sort @{$i->many1_c()} ) eq 'd/d';
ok("15")  if  join ( '/', sort @{$i->many2_c()} ) eq 'd d/d d';
ok("16")  if  $i->buried eq 'oo-oo-oo';
$i++;
ok("17")  if  $i->doc_id() eq '0002';
ok("18")  if  $i->foo() eq 'foo!' and $i->bar() eq 'bar!';
ok("19")  if  join ( '/', sort @{$i->many1_c()} ) eq 'a/b/c';
ok("20")  if  join ( '/', sort @{$i->many2_c()} ) eq 'a a/b b/c c/d d';
ok("21")  if  $i->buried eq 'hello';
$i++;
ok("22")  if  $i->doc_id() eq '0001';
$i++;
ok("23")  unless $i;

# same iterator with fields restricted
$i = $index_main->iterator ( fields => [ 'foo', 'buried' ] );
ok("24")  if  $i->doc_id() eq '0003';
ok("25")  if  $i->foo() eq 'foo2';
ok("26")  if  $i->buried() eq 'oo-oo-oo';

# but now this does a lazy read of the doc, so it should pass [dug]
eval { $i->bar() }; ok("27")  unless $@;

# test asking for a field that doesn't exist
eval { $i = $index_main->iterator ( fields => [ 'okoe' ] ) };
ok("28")  if  $@;

# get 0001 and 0002 in various ways
sub _chk_0002_0001 {
  my $iterator = shift;
  return unless $iterator->doc_id() eq '0002'; $iterator++;
  return unless $iterator->doc_id() eq '0001'; $iterator++;
  return if $iterator;
  return 1;
}

$i = $index_main->iterator ( where_clause => "foo='foo!'" );
ok("29")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_c:a' );
ok("30")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_c:b' );
ok("31")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_c:c' );
ok("32")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_b:a' );
ok("33")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_b:b' );
ok("34")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_b:c' );
ok("35")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_s:a' );
ok("36")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_s:b' );
ok("37")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => 'many1_s:c' );
ok("38")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_c:b b'" );
ok("39")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_c:b%'" );
ok("40")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_c:%b'" );
ok("41")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_b:b b'" );
ok("42")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_b:b%'" );
ok("43")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_b:%b'" );
ok("44")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "'many2_b:b%b'" );
ok("45")  if  _chk_0002_0001($i);


$i = $index_main->iterator ( collection_spec => "'many2_s:b b'" );
ok("46")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "NOT 'many1_c:d'" );
ok("47")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "NOT 'many1_s:d'" );
ok("48")  if  _chk_0002_0001($i);

$i = $index_main->iterator ( textsearch_spec => "paragraph:jumped" );
# first make sure we can ask whether there's stuff and then re-refresh
if ( $i->iterator_has_stuff ) {
    ok("49")
}
$i->iterator_refresh;
# while ( $i->iterator_has_stuff ) { print $i->doc_id; print "\n"; $i++; }
# now do the normal "what's in here test?"
ok("50")  if  _chk_0002_0001($i);

ok("51")  if  $i->select_count() == 2;
$i->iterator_refresh ( 1 );
ok("52")  if  $i->doc_id eq '0002';
ok("53")  if  $i->select_count() == 2;
$i->iterator_refresh ( 10,1 );
ok("54")  if  $i->doc_id eq '0001';
ok("55")  if  $i->select_count() == 2;

# test that nonsense word doesn't return an iterator
$i = $index_main->iterator ( textsearch_spec => "paragraph:flargenblobble" );
ok("56") unless $i->iterator_has_stuff;


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
ok("57")  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "NOT 'many1_s:abcdef'" );
ok("58")  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_c:b OR many1_c:d" );
ok("59")  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_s:b OR many1_s:d" );
ok("60")  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_s:b OR many1_b:d" );
ok("61")  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_b:b OR many1_s:d" );
ok("62")  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_c:b OR many1_b:d" );
ok("63")  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_b:b OR many1_c:d" );
ok("64")  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( collection_spec => "many1_b:%" );
ok("65")  if  _chk_0003_0002_0001($i);

$i = $index_main->iterator ( textsearch_spec => "paragraph:goldfish" );
ok("66")  if  _chk_0003_0002_0001($i);

# test retrieving nothing
$i = $index_main->iterator ( collection_spec => "'many1_c:abcdefg'" );
ok("67")  unless $i;

$i = $index_main->iterator ( collection_spec => "'many1_b:abcdefg'" );
ok("68")  unless $i;

$i = $index_main->iterator ( collection_spec => "'many1_s:abcdefg'" );
ok("69")  unless $i;

$i = $index_main->iterator ( where_clause => "1=0" );
ok("70")  unless $i;

# test partial get and then refresh
$i = $index_main->iterator();
ok("71") if (++$i)->doc_id() eq '0003';
$i->iterator_refresh();
ok("72") if (++$i)->doc_id() eq '0003' and
                   (++$i)->doc_id() eq '0002' and
                   (++$i)->doc_id() eq '0001' and ! (++$i);

# using the same iterator, make sure that advancing off the end of the
# iterator doesn't seem to have any wierd side-effects
$i++;
ok("73")  unless $i;
ok("74")  unless defined $i->doc_id();
$i++;
ok("75")  unless $i;
ok("76")  unless defined $i->doc_id();

# test "iterator select return value"
$i = $index_main->iterator();
ok("77") if $i->iterator_select_returnval() == 3;

# key, read_doc and retrieve_doc methods
$i->iterator_refresh();
ok("78") if $i->doc_key eq '_test_indexing|main|0003';
my $read = $i->read_doc();
ok("79") if $read->doc_id eq '0003' and $read->foo() eq 'foo2';
undef $read;
my $retrieved = $i->retrieve_doc();
ok("80") if $retrieved->doc_id eq '0003' and $retrieved->foo() eq 'foo2';
undef $retrieved;
$read = $i->doc_read();
ok("81") if $read->doc_id eq '0003' and $read->foo() eq 'foo2';
undef $read;
$retrieved = $i->doc_retrieve();
ok("82") if $retrieved->doc_id eq '0003' and $retrieved->foo() eq 'foo2';
undef $retrieved;


# an aggregate
my $sum = $index_main->aggregate ( function=>"SUM(id_as_number)" );
ok("83") if $sum == 6;
$sum = $index_main->aggregate ( function=>"SUM(id_as_number)",
                                collection_spec=>"'many1_b:a' OR many1_s:d" );
ok("84") if $sum == 6;
$sum = $index_main->aggregate ( function=>"SUM(id_as_number)",
                                collection_spec=>"'many2_b:d d'" );
ok("85") if $sum == 6;
$sum = $index_main->aggregate ( function=>"SUM(id_as_number)",
                                collection_spec=>"'many1_s:c'" );
ok("86") if $sum == 3;

##
# order_by expressions
$i = $index_main->iterator ( order_by=>'id_mod_3' );
ok("87") if (++$i)->doc_id() eq '0003' and
                   (++$i)->doc_id() eq '0001' and
                   (++$i)->doc_id() eq '0002' and ! (++$i);

$i = $index_main->iterator ( order_by=>'constant_exp, doc_id' );
ok("88") if (++$i)->doc_id() eq '0001' and
                   (++$i)->doc_id() eq '0002' and
                   (++$i)->doc_id() eq '0003' and ! (++$i);

$i = $index_main->iterator ( order_by=>'test_eval, doc_id' );
ok("89") if (++$i)->doc_id() eq '0001' and
                   (++$i)->doc_id() eq '0002' and
                   (++$i)->doc_id() eq '0003' and ! (++$i);


##
# deletion
$i = $index_main->iterator ( where_clause => "foo='foo!'" );
while ( $i++ ) {
  $i->retrieve_doc()->erase();
}
$i = $index_main->iterator();
ok("90") if $i->doc_id() eq '0003' and ! (++$i);

$i->iterator_refresh();
$i->retrieve_doc()->erase();

$i = $index_main->iterator();
ok("91") if ! $i;

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
ok("92") if (++$i)->doc_id() eq '0006' and
                   (++$i)->doc_id() eq '0007' and
                   (++$i)->doc_id() eq '0011' and ! (++$i);
# but 'b' table should be unchanged
$i = $index_main->iterator ( collection_spec=>"many1_s:b",
                             order_by=>'doc_id' );
ok("93") if (++$i)->doc_id() eq '0004' and
                   (++$i)->doc_id() eq '0008' and
                   (++$i)->doc_id() eq '0009' and
                   (++$i)->doc_id() eq '0010' and ! (++$i);

# and storing one more common document should trigger a 'b' table clean
$doc_common->copy();
$i = $index_main->iterator ( collection_spec=>"many1_s:b",
                             order_by=>'doc_id' );
ok("94") if (++$i)->doc_id() eq '0009' and
                   (++$i)->doc_id() eq '0010' and
                   (++$i)->doc_id() eq '0012' and ! (++$i);
# and 'a' table should have one new member
$i = $index_main->iterator ( collection_spec=>"many1_s:a",
                             order_by=>'doc_id' );
ok("95") if (++$i)->doc_id() eq '0006' and
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
ok("96") if (++$i)->doc_id() eq '0007' and
                   (++$i)->doc_id() eq '0008' and
                   (++$i)->doc_id() eq '0009' and
                   (++$i)->doc_id() eq '0010' and
                   (++$i)->doc_id() eq '0011' and
                   (++$i)->doc_id() eq '0012' and ! (++$i);

# 'a' table should have three docs
$i = $index_main->iterator ( collection_spec=>"many1_s:a",
                             order_by=>'doc_id' );
ok("97") if (++$i)->doc_id() eq '0007' and
                   (++$i)->doc_id() eq '0011' and
                   (++$i)->doc_id() eq '0012' and ! (++$i);

# as should 'b' table (unhanged, since 0013 matches the
# erase_where_clause and gets dropped during the "first" clean pass)
$i = $index_main->iterator ( collection_spec=>"many1_s:b",
                             order_by=>'doc_id' );
ok("98") if (++$i)->doc_id() eq '0009' and
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
ok("99")  unless  $i;
