use strict;
use FindBin;
use File::Path;

my $test_dir = $FindBin::Bin . "/test-docs";

print "1..22\n";

use XML::Comma;
use XML::Comma::Util qw( dbg );

my $doc_block = <<END;
<_test_document_hooks>
  <first>foo</first>
  <second>bar</second>
  <nel><foo>-</foo></nel>
</_test_document_hooks>
END

###########



## create the doc
my $doc = XML::Comma::Doc->new ( block=>$doc_block );
print "ok 1\n" if $doc;

# test initial_read_hook (s)
print "ok 2\n"  if  $doc->doc_setonread() eq 'setted';
print "ok 3\n"  if  $doc->element('first')->def_pnotes->{read_setted} eq 'ok';
print "ok 4\n"  if  $doc->nel()->foo() eq 'foo-setted';
$doc->doc_setonread(''); $doc->nel()->foo('bar');
$doc->element('first')->def_pnotes->{read_setted} = '';

## test writing and reading back in
$doc->store ( store=>'main' );
my $filename = $doc->doc_location();
my $base_directory = $doc->doc_store()->base_directory();
my $key = $doc->doc_key();
print "ok 5\n"  if  $key;
my $doc2 = XML::Comma::Doc->read ( $key );
print "ok 6\n"  if  $doc2;

## and test that the document write hook did the correct thing
print "ok 7\n"  if  $doc2->element('second')->get() eq 'written';

# test initial_read_hook (s)
print "ok 8\n"  if  $doc2->doc_setonread() eq 'setted';
print "ok 9\n"  if  $doc2->element('first')->def_pnotes->{read_setted} eq 'ok';
print "ok 10\n"  if  $doc2->nel()->foo() eq 'foo-setted';

$doc->element('first')->def_pnotes->{read_setted} = '';

# and test that none of these hooks fire if a no_read_hooks arg is
# given, when read four different ways.
$doc = XML::Comma::Doc->read ( $key, no_read_hooks => 1 );
print "ok 11\n"  if  $doc->doc_setonread() ne 'setted';
print "ok 12\n"  if  $doc->element('first')->def_pnotes->{read_setted} ne 'ok';
print "ok 13\n"  if  $doc->nel()->foo() ne 'foo-setted';

$doc->element('first')->def_pnotes->{read_setted} = '';

$doc = XML::Comma::Doc->retrieve ( $key, no_read_hooks => 1 );
print "ok 14\n"  if  $doc->doc_setonread() ne 'setted';
print "ok 15\n"  if  $doc->element('first')->def_pnotes->{read_setted} ne 'ok';
print "ok 16\n"  if  $doc->nel()->foo() ne 'foo-setted';
$doc->doc_unlock();

$doc->element('first')->def_pnotes->{read_setted} = '';

$doc = XML::Comma::Doc->new ( block => $doc_block, no_read_hooks => 1 );
print "ok 17\n"  if  $doc->doc_setonread() ne 'setted';
print "ok 18\n"  if  $doc->element('first')->def_pnotes->{read_setted} ne 'ok';
print "ok 19\n"  if  $doc->nel()->foo() ne 'foo-setted';

$doc->element('first')->def_pnotes->{read_setted} = '';

$doc = XML::Comma::Doc->new ( file => $filename, no_read_hooks => 1 );
print "ok 20\n"  if  $doc->doc_setonread() ne 'setted';
print "ok 21\n"  if  $doc->element('first')->def_pnotes->{read_setted} ne 'ok';
print "ok 22\n"  if  $doc->nel()->foo() ne 'foo-setted';

## and clean up
rmtree ( $base_directory );



