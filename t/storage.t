use strict;
use FindBin;
use File::Path;

use XML::Comma;
use XML::Comma::Util qw( dbg );
use File::Spec;
$|++;

print "1..101\n";

my $def = XML::Comma::Def->read ( name => '_test_storage' );

## test getting storage names from the def
my $names_string = join ( ',', sort $def->store_names() );
print "ok 1\n"  if  $names_string eq 
  'eight,eleven,five,four,nine,one,seven,six,ten,three,two';

#####
# test storage one -- two sequential_dirs and a sequential_file
#
my $storage_one = $def->get_store ( 'one' );
rmtree ( $storage_one->base_directory(), 0 );

my $doc = XML::Comma::Doc->new ( type => '_test_storage' );
print "ok 2\n"  if  $doc;

# write a doc and check the storage key and locked status
$doc->element('el')->set(1);
print "ok 3\n"  if  $doc->store( store => 'one', keep_open => 1 )->doc_key()
  eq '_test_storage|one|1101';
print "ok 4\n"  if  $doc->doc_is_locked(); # because we "kept_open"
print "ok 5\n"  if  ! $doc->get_read_only(); # ditto

# do some blob setting and checking
$doc->element('bl')->set("basic set");
print "ok 6\n"  if  $doc->element('bl')->get() eq 'basic set';
my $tempfile = File::Spec->catfile( XML::Comma->tmp_directory(), 'sttest.tmp' );
open ( FILE, ">$tempfile" ) || die "couldn't open temp file: $!\n";
print FILE "temp file set";
close FILE;
$doc->element('bl')->set_from_file ( $tempfile );
unlink $tempfile;
print "ok 7\n"  if  $doc->element('bl')->get() eq 'temp file set';
my $blob_location = $doc->element('bl')->get_location();
print "ok 8\n"  if  (-r $blob_location);
print "ok 9\n"  if  $blob_location =~ /1101-.+\.b$/;
$doc->element('bl')->set();
print "ok 10\n"  if  ! (-r $blob_location);
$doc->element('bl')->set("another set for bl");
print "ok 11\n"  if  $doc->element('bl')->get_location() ne $blob_location;
$blob_location = $doc->element('bl')->get_location();
$doc->element('bl2')->set("first set for bl2");
print "ok 12\n"  if  $doc->element('bl')->get() eq 'another set for bl';
print "ok 13\n"  if  $doc->element('bl2')->get() eq 'first set for bl2';
# store to write the changed links to the blobs
$doc->store(keep_open=>1);

# copy, and make sure the copy looks okay
$doc->element('el')->set(2);
print "ok 14\n"  if
  $doc->copy(keep_open=>1)->doc_key() eq '_test_storage|one|1102';
print "ok 15\n"  if  $doc->element('bl')->get_location() ne $blob_location;
print "ok 16\n"  if  $doc->element('bl')->get() eq 'another set for bl';
print "ok 17\n"  if  $doc->element('bl2')->get() eq 'first set for bl2';

# now unset the blobs, do one more copy and check to make sure there
# are no blobs
$doc->element('bl')->set();
$doc->element('bl2')->set();
$doc->store(keep_open=>1); # remember to sync the blob refs
$doc->element('el')->set(3);
print "ok 18\n"  if  $doc->copy()->doc_key() eq '_test_storage|one|1103';
print "ok 19\n"  if  ! defined  $doc->element('bl')->get();
print "ok 20\n"  if  ! defined  $doc->element('bl2')->get();
print "ok 21\n"  if  $doc->element('bl2')->get_location() eq '';

# read the three docs in and check that 'el' is correct
print "ok 22\n"  if  XML::Comma::Doc->retrieve('_test_storage|one|1101')->el()
  eq '1';
print "ok 23\n"  if  XML::Comma::Doc->retrieve('_test_storage|one|1102')->el()
  eq '2';
print "ok 24\n"  if  XML::Comma::Doc->retrieve('_test_storage|one|1103')->el()
  eq '3';

# now let's make a couple of iterators, and check that they work
my $it = $storage_one->iterator();
print "ok 25\n"  if  $it->prev_id() eq '1103';
print "ok 26\n"  if  $it->prev_id() eq '1102';
print "ok 27\n"  if  $it->prev_id() eq '1101';
print "ok 28\n"  if  ! $it->prev_id();

$it = $storage_one->iterator( pos => '-' );
print "ok 29\n"  if  $it->next_id() eq '1101';
print "ok 30\n"  if  $it->next_id() eq '1102';
print "ok 31\n"  if  $it->next_id() eq '1103';
print "ok 32\n"  if  ! $it->next_id();

$it = $storage_one->iterator( size=>2 );
print "ok 33\n"  if  $it->prev_id() eq '1103';
print "ok 34\n"  if  $it->prev_id() eq '1102';
print "ok 35\n"  if  ! $it->prev_id();

$it = $storage_one->iterator( size=>2, pos=>'-' );
print "ok 36\n"  if  $it->next_id() eq '1101';
print "ok 37\n"  if  $it->next_id() eq '1102';
print "ok 38\n"  if  ! $it->next_id();

# now we should check one of these, to make sure it's in the right place
$doc = XML::Comma::Doc->retrieve ( '_test_storage|one|1103' );

my $filename = File::Spec->catfile ( $storage_one->base_directory(),
                                     '1', '1', '03.one' );
print "ok 39\n"  if  $doc->doc_location() eq $filename;
print "ok 40\n"  if  (-w $filename);

# erase
$doc->erase();
print "ok 41\n"  if  ! (-w $filename);

# move
$doc = XML::Comma::Doc->retrieve ( '_test_storage|one|1102' );
$doc->move();
print "ok 42\n"  if  $doc->doc_key() eq '_test_storage|one|1104';
print "ok 43\n"  if  ! ( -w File::Spec->catfile($storage_one->base_directory,
                                                '1','1','02.one') );

# change and store
$doc = XML::Comma::Doc->retrieve ( $doc->doc_key() );
$doc->el(4);
$doc->store();
print "ok 44\n"  if
  XML::Comma::Doc->retrieve($doc->doc_key())->el() eq '4';
print "ok 45\n"  if  $doc->doc_key() eq '_test_storage|one|1104';

# loop storing 40 docs -- 36 since we've stored 4 in the above tests
foreach ( 1..36 ) {
  $doc->copy();
}
print "ok 46\n";
# store the 21st and get a storage full error
eval { $doc->copy(); }; print "ok 47\n"  if  $@;

#
# test looping forwards through id-space
my $n = '0000'; my $counter = 0;
while ( $n = $storage_one->next_id($n) ) {
  $counter++;
}
print "ok 48\n"  if  $counter == 38;

# test first_id and last_id
print "ok 49\n"  if  $storage_one->first_id() eq '1101';
print "ok 50\n"  if  $storage_one->last_id() eq '2210';

# and the + and - id syntaxes for first and last stored
print "ok 51\n"  if
  XML::Comma::Doc->retrieve ( '_test_storage|one|-' )->el()  eq  '1';
print "ok 52\n"  if
  XML::Comma::Doc->retrieve ( '_test_storage|one|+' )->el()  eq  '4';

# test the exported method from Storage_file
print "ok 53\n"  if   $storage_one->extension() eq '.one';

# test touch and last_modified
my $lm = $doc->doc_last_modified();
sleep ( 1 );
my $nm = $storage_one->touch ( $doc->doc_location() );
print "ok 54\n"  if  $nm gt $lm and $nm == $doc->doc_last_modified();

# test locking
$doc = XML::Comma::Doc->retrieve ( "_test_storage|one|-" );
print "ok 55\n"  if  $doc;
print "ok 56\n"  if  $doc->doc_is_locked();
my $ro = XML::Comma::Doc->read ( "_test_storage|one|-" );
print "ok 57\n"  if  ! $ro->doc_is_locked();
print "ok 58\n"  if
  ! defined XML::Comma::Doc->retrieve_no_wait ( "_test_storage|one|-" );
eval {
  XML::Comma::Doc->retrieve ( "_test_storage|one|-", timeout=>0 );
}; print "ok 59\n"  if  $@;
eval {
  XML::Comma::Doc->retrieve ( "_test_storage|one|-", timeout=>1 );
}; print "ok 60\n"  if  $@;
eval {
  $doc->get_lock ( timeout=>0 );
}; print "ok 61\n"  if  $@;
# should not be able to store ro
eval { $ro->store() }; print "ok 62\n"  if  $@;
# try to store with keep open
$doc->store ( keep_open=>1 );
print "ok 63\n"  if  $doc->doc_is_locked();
# and now store again and we should be unlocked
$doc->store ();
print "ok 64\n"  if  ! $doc->doc_is_locked();
$doc->get_lock();
print "ok 65\n"  if  $doc->doc_is_locked();
print "ok 66\n"  if  ! defined $ro->get_lock_no_wait();
print "ok 67\n"  if  ! $ro->doc_is_locked();

#
#
####

####
# storage six -- Derived_file (with a Sequential_dir thrown in for excitement)

$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->el('first');
$doc->store ( store=>'six' );
my $doc2 = XML::Comma::Doc->new ( type => '_test_storage' );
$doc2->el('second');
$doc2->store ( store=>'six' );
$doc = XML::Comma::Doc->read ( '_test_storage|six|1first' );
print "ok 68\n"  if  $doc->el() eq 'first';
$doc = XML::Comma::Doc->read ( '_test_storage|six|1second' );
print "ok 69\n"  if  $doc->el() eq 'second';
# now modify the derive_from
$doc->get_lock();
$doc->el('modified');
$doc->store();
$doc = XML::Comma::Doc->read ( '_test_storage|six|1second' );
print "ok 70\n"  if  $doc->el() eq 'modified';
#
print "ok 71\n"  if  $doc->doc_location eq
  File::Spec->catfile ( $doc->doc_store()->base_directory(), '1',
                        'second' . $doc->doc_store()->extension() );

my $storage_six = $def->get_store ( 'six' );
my $six_first_id = $storage_six->first_id();
print "ok 72\n"  if  $six_first_id eq '1first';

#
#
####


####
# storage eleven -- Derived_GMT_3layer_dir (in a sandwich)

$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->el('20020416'); $doc->el2('foo');
$doc->store ( store=>'eleven' );
$doc2 = XML::Comma::Doc->new ( type => '_test_storage' );
$doc2->el('20020416'); $doc2->el2('bar');
$doc2->store ( store=>'eleven' );
$doc = XML::Comma::Doc->read ( '_test_storage|eleven|120020416foo' );
print "ok 73\n"  if  $doc->el2() eq 'foo';
$doc = XML::Comma::Doc->read ( '_test_storage|eleven|120020416bar' );
print "ok 74\n"  if  $doc->el2() eq 'bar';
# now modify the derive_from
$doc->get_lock();
$doc->el('19990101');
$doc->store();
$doc = XML::Comma::Doc->read ( '_test_storage|eleven|120020416bar' );
print "ok 75\n"  if  $doc->el() eq '19990101';
#
print "ok 76\n"  if  $doc->doc_location eq
  File::Spec->catfile ( $doc->doc_store()->base_directory(), '1',
                        '2002', '04', '16',
                        'bar' . $doc->doc_store()->extension() );

my $storage_eleven = $def->get_store ( 'eleven' );
my $eleven_first_id = $storage_eleven->first_id();
print "ok 77\n"  if  $eleven_first_id eq '120020416bar';

#
#
####

####
# storage seven -- Derived_dir (with other stuff thrown in for excitement)
$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->el ( '1' ); # too short
$doc->store ( store=>'seven' );
print "ok 78\n"  if  $doc->doc_key() eq '_test_storage|seven|10011';
$doc2 = XML::Comma::Doc->read ( $doc->doc_key() );
print "ok 79\n"  if  $doc2->el() eq '1';
#
$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->el ( '11111' ); # too long
$doc->store ( store=>'seven' );
print "ok 80\n"  if  $doc->doc_key() eq '_test_storage|seven|111111111';
$doc2 = XML::Comma::Doc->read ( $doc->doc_key() );
print "ok 81\n"  if  $doc2->el() eq '11111';
#
#
####

####
# storage two - gmt dir and a sequential file

my $storage_two = $def->get_store ( 'two' );
my $two_base_loc = File::Spec->catdir 
  ( $storage_two->base_directory(),
    XML::Comma::Storage::Util->gmt_yyy_mm_dd() );
my $two_base_id = join ( '', XML::Comma::Storage::Util->gmt_yyy_mm_dd() );

rmtree ( $storage_two->base_directory(), 0 );

# simple set and store
$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->element('el')->set ( 'first gmt 3 layer doc' );
print "ok 82\n"  if
  $doc->store(store=>'two',keep_open=>1)->doc_key()
  eq "_test_storage|two|$two_base_id".'01';

# change the element, and retrieve
$doc->element('el')->set ( 'changed' );
$doc->doc_unlock();
$doc = XML::Comma::Doc->retrieve ( "_test_storage|two|$two_base_id".'01' );
print "ok 83\n"  if  $doc->el() eq 'first gmt 3 layer doc';

# only nine more should fit
for ( 1..9 ) {
  $doc->copy();
}
print "ok 84\n";
eval { $doc->copy(); }; print "ok 85\n"  if  $@;

# check blob and blob's read hook
$doc = XML::Comma::Doc->retrieve ( "_test_storage|two|$two_base_id".'01' );
print "ok 86\n"  if  $doc->element('bl')->def_pnotes()->{read_setted} eq 'ok';
$doc->element('bl')->set ( 'a blob thing' );
print "ok 87\n"  if  $doc->element('bl')->get() eq 'a blob thing';

#
#
####


####
# output chains

rmtree  $def->get_store('three')->base_directory();
rmtree  $def->get_store('four')->base_directory();
rmtree  $def->get_store('five')->base_directory();

# gzip
$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->element('el')->set(45);
print "ok 88\n"  if  $doc->store( store => 'three' )->doc_key()
  eq '_test_storage|three|01';
$doc2 = XML::Comma::Doc->read ( '_test_storage|three|01' );
print "ok 89\n"  if  $doc2->element('el')->get() == 45;

# twofish
$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->element('el')->set(79);
print "ok 90\n"  if  $doc->store( store => 'four' )->doc_key()
  eq '_test_storage|four|01';
$doc2 = XML::Comma::Doc->read ( '_test_storage|four|01' );
print "ok 91\n"  if  $doc2->element('el')->get() == 79;

# gzip then twofish
$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->element('el')->set(223);
print "ok 92\n"  if  $doc->store( store => 'five' )->doc_key()
  eq '_test_storage|five|01';
$doc2 = XML::Comma::Doc->read ( '_test_storage|five|01' );
print "ok 93\n"  if  $doc2->element('el')->get() == 223;

# exit ( 0 );

####
# hooks
####

$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->store ( store => 'eight' );
print "ok 94\n"  if  $doc->el() eq 'one-hook;two-hooks;three-hooks';
my $key = $doc->doc_key();
print "ok 95\n"  if
  XML::Comma::Doc->read( $key )->el() eq 'one-hook;two-hooks;three-hooks';
$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->store ( store => 'eight', no_hooks => 1 );
print "ok 96\n"  if  $doc->el() eq '';
$doc = 1;


####
# Derived file directory "balancing"
####
my $nine_base = $def->get_store('nine')->base_directory();
my $ten_base = $def->get_store('ten')->base_directory();
#
$doc = XML::Comma::Doc->new ( type => '_test_storage' );
$doc->el ( 'abcd' );
$doc->store ( store => 'nine' );
print "ok 97\n"  if  $doc->doc_key() eq '_test_storage|nine|abcd';
print "ok 98\n"  if  $doc->doc_location() eq
  File::Spec->catfile ( $nine_base, 'cd', 'abcd.comma' );
$doc = XML::Comma::Doc->retrieve ( '_test_storage|nine|abcd' );
$doc->store ( store => 'ten' );
print "ok 99\n"  if  $doc->doc_key() eq '_test_storage|ten|0001abcd';
print "ok 100\n"  if  $doc->doc_location() eq
  File::Spec->catfile ( $ten_base, '0001', 'ab', 'abcd.comma' );
$doc = XML::Comma::Doc->retrieve ( '_test_storage|ten|0001abcd' );
print "ok 101\n"  if  $doc->el() eq 'abcd';


#  ####
#  # test next_in_list function
#  my @list = ( 'a', 'b', 'c', 'd',   'f', 'g', 'h', 'i' );
#  # simple
#  print "ok 102\n"  if
#    'b' eq XML::Comma::Storage::FileUtil->next_in_list ( \@list, 'a' );
#  print "ok 103\n"  if
#    'g' eq XML::Comma::Storage::FileUtil->next_in_list ( \@list, 'f' );
#  print "ok 104\n"  if
#    'h' eq XML::Comma::Storage::FileUtil->next_in_list ( \@list, 'i', -1 );
#  print "ok 105\n"  if
#    'c' eq XML::Comma::Storage::FileUtil->next_in_list ( \@list, 'd', -1 );
#  # past ends
#  print "ok 106\n"  if
#    ! defined XML::Comma::Storage::FileUtil->next_in_list ( \@list, 'i' );
#  print "ok 107\n"  if
#    ! defined XML::Comma::Storage::FileUtil->next_in_list ( \@list, 'a', -1 );
#  # into ends
#  print "ok 108\n"  if
#    'a' eq XML::Comma::Storage::FileUtil->next_in_list ( \@list, '0' );
#  print "ok 109\n"  if
#    'i' eq XML::Comma::Storage::FileUtil->next_in_list ( \@list, 'z', -1 );
#  # over gap
#  print "ok 110\n"  if
#    'f' eq XML::Comma::Storage::FileUtil->next_in_list ( \@list, 'd' );
#  print "ok 111\n"  if
#    'd' eq XML::Comma::Storage::FileUtil->next_in_list ( \@list, 'f', -1 );
