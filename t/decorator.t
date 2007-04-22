use strict;

use lib ".test/lib/";

use XML::Comma;
use XML::Comma::Pkg::DecoratorTest::Talker;
use XML::Comma::Pkg::DecoratorTest::Shouter;
use XML::Comma::Pkg::DecoratorTest::Whisperer;
use XML::Comma::Pkg::DecoratorTest::OverTalker;
use XML::Comma::Pkg::DecoratorTest::ConfigTalker;
use XML::Comma::Pkg::DecoratorTest::SimpleTest;

use Test::More tests => 20;

# make a doc
my $doc = XML::Comma::Doc->new ( type => '_test_decorator' );
my $def = $doc->def;
ok($doc and $def);

# we should no longer be a simple Doc
ok(ref($doc) ne 'XML::Comma::Doc');

# make sure we're still a doc, even after becoming something more.
ok($doc->isa('XML::Comma::Doc'));

# make sure we're a Talker
ok($doc->isa('XML::Comma::Pkg::DecoratorTest::Talker'));

# can we say hello? 
ok($doc->say_hello eq 'hello');

# test a plain element
my $el = $doc->element('el_plain');
ok($el->say_hello eq 'HELLO');
$doc->el_plain ( "foo" );
ok($doc->el_plain eq 'foo');

# test a nested element and a child plain element
$el = $doc->element('el_nested');
ok($el->say_hello eq 'hello');
my $cel = $el->element('el_plain');
ok($cel->say_hello eq '.....');
$doc->el_nested->el_plain ( "bar" );
ok($doc->el_nested->el_plain eq 'bar');

# test a blob element
ok($doc->el_blob->say_hello eq '.....');
$doc->el_blob->set ( "blob set" );
ok($doc->el_blob->get eq 'blob set');

# test multiple decorators and "super"
ok($doc->element('multi')->say_hello eq '...--HEY');
$doc->multi ( "brown fox" );
ok($doc->multi eq 'bro--HEY');

# test config
ok($doc->element('configurable')->say_hello eq 'marhaban');

# stuff for testing DefModule
$doc = XML::Comma::Pkg::DecoratorTest::SimpleTest->new;
$def = $doc->def;
ok($doc and $def);

# make sure we get the same location in memory if we load anew
ok($def == XML::Comma::Def->SimpleTest);
ok($def == XML::Comma::Pkg::DecoratorTest::SimpleTest->load_def());
ok($def == XML::Comma::Pkg::DecoratorTest::SimpleTest->def());
ok($def == XML::Comma::Pkg::DecoratorTest::SimpleTest->new()->def());
