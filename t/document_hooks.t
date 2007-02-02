use strict;
use File::Path;

print "1..7\n";

use lib ".test/lib/";

use XML::Comma;
use XML::Comma::Util qw( dbg );

my $doc_block = <<END;
<_test_document_hooks>
  <first>foo</first>
  <second>bar</second>
</_test_document_hooks>
END

###########



## create the doc
my $doc = XML::Comma::Doc->new ( block=>$doc_block );
print "ok 1\n" if $doc;

## test writing and reading back in
$doc->nel()->foo ( '-' ); # set foo, so we can test its read_hook
$doc->store ( store=>'main' );
my $filename = $doc->doc_location();
print "ok 2\n"  if  $filename;
my $doc2 = XML::Comma::Doc->new ( file => $filename );
print "ok 3\n"  if  $doc2;

## and test that the document write hook did the correct thing
print "ok 4\n"  if  $doc2->element('second')->get() eq 'written';

# test initial_read_hook (s)
print "ok 5\n"  if  $doc->doc_setonread() eq 'setted';
print "ok 6\n"  if  $doc->element('first')->def_pnotes->{read_setted} eq 'ok';
print "ok 7\n"  if  $doc2->nel()->foo() eq 'foo-setted';

## and clean up
rmtree ( $doc->doc_store()->base_directory() );


