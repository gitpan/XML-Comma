use strict;
use File::Path;

use Test::More tests => 7;

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
ok("doc created") if $doc;

## test writing and reading back in
$doc->nel()->foo ( '-' ); # set foo, so we can test its read_hook
$doc->store ( store=>'main' );
my $filename = $doc->doc_location();
ok("doc written")  if  $filename;
my $doc2 = XML::Comma::Doc->new ( file => $filename );
ok("doc read from file")  if  $doc2;

## and test that the document write hook did the correct thing
ok("write_hook wrote correctly")  if  $doc2->element('second')->get() eq 'written';

# test initial_read_hook (s)
ok("read_hook test 1")  if  $doc->doc_setonread() eq 'setted';
ok("read_hook test 2")  if  $doc->element('first')->def_pnotes->{read_setted} eq 'ok';
ok("read_hook test 3")  if  $doc2->nel()->foo() eq 'foo-setted';

## and clean up
rmtree ( $doc->doc_store()->base_directory() );


