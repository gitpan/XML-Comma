#!/usr/bin/perl -w

use strict;
use FindBin;
use File::Path;


my $test_dir =  '/usr/local/comma/docs/test';

print "1..157\n";

use XML::Comma;
use XML::Comma::Util qw( dbg );



my $doc_block = <<END;
<_test_indexing>
  <foo>foo stuff</foo>
  <bar>ha</bar>
</_test_indexing>
END

###########

my $def = XML::Comma::Def->read ( name => '_test_indexing' );
rmtree ( $def->get_store('main')->base_directory() );
rmtree ( $def->get_store('other')->base_directory() );
print "ok 1\n"  if  $def;


## test getting index objects out by name
my $index_main = $def->get_index ( 'main' );
my $index_other = $def->get_index ( 'other' );
eval {
  $def->get_index ( 'doesnt exist' );
}; my $error = $@;
print "ok 2\n"  if  $index_main && $index_other && $error;

## ping (twice, just to make sure we're not doing something silly)
$index_main->ping();
$index_main->ping();
print "ok 3\n";

## create the doc
my $doc = XML::Comma::Doc->new ( block=>$doc_block );
print "ok 4\n" if $doc;

## check introspection helpers
print "ok 5\n"  if  join('/',$index_main->field_names()) eq
  'foo/bar/id_as_number/extra1/buried';
print "ok 6\n"  if  join('/',$index_main->collection_names()) eq
  'many/another_many';
print "ok 7\n"  if  join('/',$index_main->sort_names()) eq 'many';
print "ok 8\n"  if  join('/',$index_main->textsearch_names()) eq 'paragraph';

## add to the index
$doc->many( 'a', 'a', 'b', 'c', 'd' ); # add a twice to check that sort is okay
                                       # with multiple occurences
$doc->id_as_number(1);
$doc->foo ( 'foo 1' );
$doc->paragraph ( 'the quick brown fox' );
$doc->store(store=>'main',keep_open=>1);
#
$doc->elements_group_delete ( 'many' );
$doc->many ( 'a' );
$doc->id_as_number(2);
$doc->foo ( 'foo 2' );
$doc->bar ( 'a special string' );
$doc->paragraph ( 'jumped over the dog' );
$doc->copy(keep_open=>1);
#
$doc->elements_group_delete ( 'many', 'a' );
$doc->many ( 'e' );
$doc->id_as_number(3);
$doc->foo ( 'foo 3' );
$doc->bar ( 'ha ha' );
$doc->paragraph ( 'foxes and dogs in one sentence' );
$doc->element('nel')->element('buried')->set ( 'deep down value' );
$doc->copy(keep_open=>1);
#$doc->paragraph ( '' );
#
print "ok 9\n";

# set is_as_number to 0, so that we can play with the ordering of
# later sorts whever we want to
$doc->id_as_number ( 0 );

# simple iteration
my $i = $index_main->iterator ( order_by => 'doc_id' );
print "ok 10\n"  if  $i && $i->iterator_refresh();
#  dbg 'id', $i->doc_id();
#  dbg 'key', $i->doc_key();
#  dbg 'foo', $i->foo();
#  dbg 'bar', $i->bar();
#  exit ( 0 );

print "ok 11\n"  if
  $i->doc_id() eq '0001' and $i->doc_key() eq '_test_indexing|main|0001' and
  $i->foo() eq 'foo 1' and
  $i->bar() eq 'ha';
print "ok 12\n"  if  $i->iterator_next();
print "ok 13\n"  if
  $i->doc_id() eq '0002' and $i->doc_key() eq '_test_indexing|main|0002' and
  $i->foo() eq 'foo 2' and
  $i->bar() eq 'a special string';
print "ok 14\n"  if  $i->iterator_next();
print "ok 15\n"  if
  $i->doc_id() eq '0003' and
  $i->foo() eq 'foo 3' and
  $i->bar() eq 'ha ha';
print "ok 16\n" if  ! $i->iterator_next();

#  exit (0 );

# a where'd iteration
$i = $index_main->iterator( where_clause=>"bar = 'a special string'" );
print "ok 17\n"  if  $i->bar() eq 'a special string';
print "ok 18\n"  if  $i->record_last_modified() > time() - 30;
print "ok 19\n"  if  ! $i->iterator_next();

# low-limited iteration
$i = $index_main->iterator ( order_by => 'doc_id' );
print "ok 20\n"  if  $i->iterator_refresh ( 2 );
print "ok 21\n"  if  $i->doc_id() eq '0001';
print "ok 22\n"  if  $i->iterator_next();
print "ok 23\n"  if  $i->doc_id() eq '0002';
print "ok 24\n"  if  ! $i->iterator_next();

# range-limited iteration
$i = $index_main->iterator(); # note: default, reverse order
print "ok 25\n"  if  $i->iterator_refresh ( 1, 2 );
print "ok 26\n"  if  $i->doc_id() eq '0001';
print "ok 27\n"  if  ! $i->iterator_next();

# sort-ed iteration -- test distinct-ness and default order by
$i = $index_main->iterator ( sort_spec=>'many:a' );
print "ok 28\n"  if  $i->doc_id() eq '0002';
print "ok 29\n"  if  $i->iterator_next();
print "ok 30\n"  if  $i->doc_id() eq '0001';
print "ok 31\n"  if  ! $i->iterator_next();

# iteration ordered_by an expression (or three), rather than a field
$i = $index_main->iterator ( order_by => 'constant_exp,test_eval,id_mod_3' );
print "ok 32\n"  if  $i->doc_id() eq '0003';
print "ok 33\n"  if  $i->iterator_next();
print "ok 34\n"  if  $i->doc_id() eq '0001';
print "ok 35\n"  if  $i->iterator_next();
print "ok 36\n"  if  $i->doc_id() eq '0002';
print "ok 37\n"  if  ! $i->iterator_next();

# iteration with the code'ed field
$i = $index_main->iterator( where_clause=>"buried = 'deep down value'" );
print "ok 38\n"  if  $i->doc_id() eq '0003';
print "ok 39\n"  if  ! $i->iterator_next();

# iteration with a collections search
$i = $index_main->iterator ( collection_spec => 'many:a' );
print "ok 40\n"  if  $i->doc_id() eq '0002';
print "ok 41\n"  if  $i->iterator_next();
print "ok 42\n"  if  $i->doc_id() eq '0001';
print "ok 43\n"  if  ! $i->iterator_next();
# same thing, just making sure where_clause works, too
$i = $index_main->iterator ( where_clause => 'foo LIKE \'foo%\'',
                             collection_spec => 'many:a' );
print "ok 44\n"  if  $i->doc_id() eq '0002';
print "ok 45\n"  if  $i->iterator_next();
print "ok 46\n"  if  $i->doc_id() eq '0001';
print "ok 47\n"  if  ! $i->iterator_next();
# and check to make sure that the other one is retreivable, too
$i = $index_main->iterator ( collection_spec => 'many:e' );
print "ok 48\n"  if  $i->doc_id() eq '0003';
print "ok 49\n"  if  ! $i->iterator_next();

# and repeat the last collections search with a collection that has a
# code block
$i = $index_main->iterator ( collection_spec => 'another_many:a' );
print "ok 50\n"  if  $i->doc_id() eq '0002';
print "ok 51\n"  if  $i->iterator_next();
print "ok 52\n"  if  $i->doc_id() eq '0001';
print "ok 53\n"  if  ! $i->iterator_next();
$i = $index_main->iterator ( where_clause => 'foo LIKE \'foo%\'',
                             collection_spec => 'another_many:a' );
print "ok 54\n"  if  $i->doc_id() eq '0002';
print "ok 55\n"  if  $i->iterator_next();
print "ok 56\n"  if  $i->doc_id() eq '0001';
print "ok 57\n"  if  ! $i->iterator_next();
$i = $index_main->iterator ( collection_spec => 'another_many:e' );
print "ok 58\n"  if  $i->doc_id() eq '0003';
print "ok 59\n"  if  ! $i->iterator_next();

# exit ( 0 );

# a couple of textsearch iterators
$i = $index_main->iterator ( textsearch_spec => 'paragraph:fox',
                             order_by => 'doc_id' );
print "ok 60\n"  if  $i->doc_id() eq '0001';
print "ok 61\n"  if  $i->iterator_next();
#dbg '1', $i->doc_id();
print "ok 62\n"  if  $i->doc_id() eq '0003';
print "ok 63\n"  if  ! $i->iterator_next();
#dbg '2', $i->doc_id();
$i = $index_main->iterator ( textsearch_spec => 'paragraph:dog',
                             order_by => 'doc_id' );
print "ok 64\n"  if  $i->doc_id() eq '0002';
print "ok 65\n"  if  $i->iterator_next();
print "ok 66\n"  if  $i->doc_id() eq '0003';
print "ok 67\n"  if  ! $i->iterator_next();

$i = $index_main->iterator ( textsearch_spec => 'paragraph:foxes dog',
                             order_by => 'doc_id' );
print "ok 68\n"  if  $i->doc_id() eq '0003';
print "ok 69\n"  if  ! $i->iterator_next();

# get the doc from the iterator and compare it to our current doc
$i = $index_main->iterator ( where_clause => "doc_id='0003'" );
$doc->doc_unlock();
my $doc_revivified = $i->retrieve_doc();
print "ok 70\n"  if  $doc_revivified;
# adjust id_as_number in the pulled doc to match what we set it to, above...
$doc_revivified->id_as_number(0);
print "ok 71\n"  if  $doc_revivified->to_string() eq $doc->to_string();
$doc_revivified->doc_unlock();

# now, do a delete and check a couple of the iterations, again
$doc->get_lock();
$doc->index_remove ( index => 'main' );
$i = $index_main->iterator ( order_by => 'constant_exp,id_mod_3' );
print "ok 72\n"  if  $i->doc_id() eq '0001';
print "ok 73\n"  if  $i->iterator_next();
print "ok 74\n"  if  $i->doc_id() eq '0002';
print "ok 75\n"  if  ! $i->iterator_next();
$i = $index_main->iterator ( textsearch_spec => 'paragraph:dog',
                             order_by => 'doc_id' );
print "ok 76\n"  if  $i->doc_id() eq '0002';
print "ok 77\n"  if  ! $i->iterator_next();

# new let's set add and do the iterations, one more time
$doc->index_update ( index => 'main' );
$i = $index_main->iterator ( order_by => 'constant_exp,id_mod_3' );
print "ok 78\n"  if  $i->doc_id() eq '0003';
print "ok 79\n"  if  $i->iterator_next();
print "ok 80\n"  if  $i->doc_id() eq '0001';
print "ok 81\n"  if  $i->iterator_next();
print "ok 82\n"  if  $i->doc_id() eq '0002';
print "ok 83\n"  if  ! $i->iterator_next();

# check some counts
print "ok 84\n"  if
  $index_main->count( where_clause => "doc_id='0003'" ) == 1;
print "ok 85\n"  if
  $index_main->count() == 3;
print "ok 86\n"  if
  $index_main->count ( sort_spec=>'many:a' ) == 2;

# and delete -- then check the counts again
$doc->index_remove ( index=>'main' );
print "ok 87\n"  if
  $index_main->count( where_clause => "doc_id='0003'" ) == 0;
print "ok 88\n"  if
  $index_main->count() == 2;

# now try to update a doc that will cause the index_hook to die
# (and check the counts, again)
$doc->foo ( 'do not index' );
print "ok 89\n"  if  ! $doc->index_update( index => 'main');
print "ok 90\n"  if
  $index_main->count( where_clause => "doc_id='0003'" ) == 0;
print "ok 91\n"  if
  $index_main->count() == 2;

# and unset that element, so that we can use doc later
$doc->foo ( 'whatever' );

# single() -- iterator that returns only first row
print "ok 92\n"  if
  $index_main->single(where_clause => "doc_id='0002'")->doc_id() == 2;
print "ok 93\n"  if
  $index_main->single(where_clause => "doc_id='0001'")->doc_id() == 1;
print "ok 94\n"  if
  $index_main->single_retrieve(where_clause => "doc_id='0002'")->doc_id() == 2;
print "ok 95\n"  if
  $index_main->single_retrieve(where_clause => "doc_id='0001'")->doc_id() == 1;
print "ok 96\n"  if
  $index_main->single_read(where_clause => "doc_id='0002'")->doc_id() == 2;
print "ok 97\n"  if
  $index_main->single_read(where_clause => "doc_id='0001'")->doc_id() == 1;
print "ok 98\n"  if ! $index_main->single(where_clause => "doc_id='xx--xx'");

##
# BAD MOJO -- don't do this outside TESTS 
#
# test adding a field
my $new_field = $index_main->add_element('field');
$new_field->element('name')->set('extra2');
$new_field->element('sql_type')->set('VARCHAR(40)');
$index_main->{_Index_columns} = {};
$index_main->_init_Index_variables();
$index_main->_check_db();
print "ok 99\n";
# test adding a new field that's a duplicate -- should fail
$new_field = $index_main->add_element('field');
$new_field->element('name')->set('extra1');
$new_field->element('sql_type')->set('VARCHAR(40)');
$index_main->{_Index_columns} = {};
eval { $index_main->_init_Index_variables(); };
print "ok 100\n"  if  $@;
$index_main->delete_element ( $new_field );
# test changing a field's type
$new_field->element('sql_type')->set('CHAR(10)');
$index_main->{_Index_columns} = {};
$index_main->_init_Index_variables();
$index_main->_check_db();
print "ok 101\n";
# test dropping a field
$index_main->delete_element($new_field);
$index_main->{_Index_columns} = {};
$index_main->_init_Index_variables();
$index_main->_check_db();
print "ok 102\n";
#
###

# timestamps
my $data_mt = $index_main->last_modified_time();
# data update
sleep ( 1 );
$doc->copy();
print "ok 103\n"  if  $index_main->last_modified_time() > $data_mt;
$data_mt = $index_main->last_modified_time();
# data delete
sleep ( 1 );
XML::Comma::Doc->retrieve($doc->doc_key())->erase();
print "ok 104\n"  if  $index_main->last_modified_time() > $data_mt;
# sort timestamps
$doc->get_lock();
$doc->elements_group_delete('many');
$doc->many ( 'a','b' );
$doc->copy();
$doc = XML::Comma::Doc->retrieve($doc->doc_key());
my $a_mt = $index_main->last_modified_time('many','a');
my $b_mt = $index_main->last_modified_time('many','b');
my $c_mt = $index_main->last_modified_time('many','c');
my $d_mt = $index_main->last_modified_time('many','d');
sleep ( 1 );
#dbg 'mtimes', time(), $a_mt, $b_mt, $c_mt, $d_mt;

$doc->elements_group_delete('many');
$doc->many ( 'a','c' );
$doc->store();
# sort not effected -- doesn't change
print "ok 105\n"  if  $index_main->last_modified_time('many','d') == $d_mt;
# sort simply present -- changes
print "ok 106\n"  if  $index_main->last_modified_time('many','a') > $a_mt;
# sort added -- changes
print "ok 107\n"  if  $index_main->last_modified_time('many','c') > $c_mt;
# sort removed -- changes
print "ok 108\n"  if  $index_main->last_modified_time('many','b') > $b_mt;


# test clean -- should have 3 entries in data, 3 in a and 1 in b. The
# three entries are 0001, 0002 and 0005. only 0001 and 0002 have an
# id_as_number, and only 0001 is in b. (whew)
$doc->get_lock();
$doc->elements_group_delete ( 'many' ); # store 0006 with id_as_number=4
$doc->many('a');
$doc->id_as_number ( 4 );

# store twice, but reset id_as_number after first time -- should
# trigger 'a' clean
$doc->copy(keep_open=>1);
$doc->id_as_number ( 0 );
$doc->copy();

# data should have 5 items
print "ok 109\n"  if  $index_main->count() == 5;
# and a should have 3 items: 0006,0002,0001
$i = $index_main->iterator ( sort_spec=>'many:a' );
print "ok 110\n"  if  $i->doc_id() eq '0006';
print "ok 111\n"  if  $i->iterator_next();
print "ok 112\n"  if  $i->doc_id() eq '0002';
print "ok 113\n"  if  $i->iterator_next();
print "ok 114\n"  if  $i->doc_id() eq '0001';
print "ok 115\n"  if  ! $i->iterator_next();
print "ok 116\n"  if  $index_main->count( sort_spec=>'many:a' ) == 3;

# store twice more (4 total) -- should trigger 'a' clean
$doc->copy();
$doc->copy();

# data should have 7 items, a should be the same as last time
print "ok 117\n"  if  $index_main->count() == 7;
$i = $index_main->iterator ( sort_spec=>'many:a' );
print "ok 118\n"  if  $i->doc_id() eq '0006';
print "ok 119\n"  if  $i->iterator_next();
print "ok 120\n"  if  $i->doc_id() eq '0002';
print "ok 121\n"  if  $i->iterator_next();
print "ok 122\n"  if  $i->doc_id() eq '0001';
print "ok 123\n"  if  ! $i->iterator_next();
print "ok 124\n"  if  $index_main->count( sort_spec=>'many:a' ) == 3;

#exit ( 0 );

# store three more times (7 total) -- should trigger 'a' clean (then
# +1), and should trigger data clean, which does another 'a' clean, too
$doc->copy();
$doc->copy();
# set the id_as_number, so that after the data clean is triggered, here, we'll have this last item still in data (otherwise, it will get sorted out, and even though it's in 'a', it won't show up in the sort.
$doc->get_lock();
$doc->id_as_number ( 100 );
$doc->copy();
$doc = XML::Comma::Doc->retrieve($doc->doc_key());

# data should have 5 items
print "ok 125\n"  if  $index_main->count() == 5;
# a should have 3 items, because it gets clean()ed, too.
$i = $index_main->iterator ( sort_spec=>'many:a' );
print "ok 126\n"  if  $i->doc_id() eq '0012';
print "ok 127\n"  if  $i->iterator_next();
print "ok 128\n"  if  $i->doc_id() eq '0006';
print "ok 129\n"  if  $i->iterator_next();
print "ok 130\n"  if  $i->doc_id() eq '0002';

print "ok 131\n"  if  ! $i->iterator_next();
print "ok 132\n"  if  $index_main->count( sort_spec=>'many:a' ) == 3;

# test a couple of other ways of invoking/traversing iterators -- this
# doesn't have anything to do with the above, but we can use the
# current state to make sure that the dwim stuff in Iterator doesn't
# fail. these are in no particular order; we're just hammering on the
# create/refresh logic a little.
$i = $index_main->iterator ( sort_spec => 'many:a' );
print "ok 133\n"  if  $i->doc_id() eq '0012';
$i = $index_main->iterator ( sort_spec => 'many:a' );
my $counter = 0;
while ( $i->iterator_next() ) { $counter++ };
print "ok 134\n"  if  $counter == 3;
# now do what we just did but using overloaded bool and ++
$i = $index_main->iterator ( sort_spec => 'many:a' );
$counter = 0;
while ( $i ) { $counter++; $i++ };
print "ok 135\n"  if  $counter == 3;
# again, but using ++ in such a way that the =/copy overload will be
# called (and, incidentally, testing that our dwim iterator_next()
# approach works
$i = $index_main->iterator ( sort_spec => 'many:a' );
$counter = 0;
while ( $i++ ) { $counter++; };
print "ok 136\n"  if  $counter == 3;
# and let's just try one more time after a refresh
$i->iterator_refresh();
$counter = 0;
while ( $i++ ) { $counter++; };
print "ok 137\n"  if  $counter == 3;
# okay, nothing to see here, moving right along
$i = $index_main->iterator ( sort_spec => 'many:a' )->iterator_refresh ( 2, 0 );
$counter = 0;
while ( $i->iterator_next() ) { $counter++ };
print "ok 138\n"  if  $counter == 2;
print "ok 139\n"  if  ! $i->iterator_has_stuff();
$i->iterator_refresh ( 2, 0 );
print "ok 140\n"  if  $i->iterator_has_stuff();
print "ok 141\n"  if  $i->doc_id() eq '0012';
print "ok 142\n"  if  $i->iterator_has_stuff();
$counter = 1; # because we've implicitly next-ed when we grabbed the id
while ( $i->iterator_next() ) { $counter++ };
print "ok 143\n"  if  $counter == 2;
print "ok 144\n"  if  ! $i->iterator_has_stuff();

# now test an erase_where_clause clean -- set one of these to be clean()'ed based on an erase_where_clause, and make sure that that happens.
$doc->foo ( 'erase this one' );
$doc->store();
print "ok 145\n"  if  $index_main->count() == 5;
$index_main->clean();
print "ok 146\n"  if  $index_main->count() == 4;
$i = $index_main->iterator();
print "ok 147\n"  if  $i->iterator_refresh();
print "ok 148\n"  if  $i->doc_id() eq '0011';
print "ok 149\n"  if  $i->iterator_next();
print "ok 150\n"  if  $i->doc_id() eq '0006';
print "ok 151\n"  if  $i->iterator_next();
print "ok 152\n"  if  $i->doc_id() eq '0002';
print "ok 153\n"  if  $i->iterator_next();

print "ok 154\n"  if  $i->doc_id() eq '0001';
print "ok 155\n"  if  ! $i->iterator_next();


# try cleaning the 'other' index, which has no clean defined, to make
# sure that we just silently move along
$index_other->update ( $doc );
eval {
  $index_other->rebuild();
};
print "$@\n"  if  $@;
print "ok 156\n"  if  ! $@;


#exit ( 0 );


#$index_main->drop_all_tables();
## delete everything in the index from the index, to start fresh (we
## nixed drop_all_tables, which used to make this unnecessary)
my $iterator = $index_main->iterator();
while ( $iterator->iterator_has_stuff() ) {
  $iterator->retrieve_doc()->index_remove(index=>'main');
  $iterator->retrieve_doc()->index_remove(index=>'other');
  $iterator->iterator_next();
}


rmtree ( $test_dir );
print "ok 157\n";
