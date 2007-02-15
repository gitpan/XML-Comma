use strict;

use lib ".test/lib/";

use XML::Comma;
use XML::Comma::Pkg::DecoratorTest::Talker;
use XML::Comma::Pkg::DecoratorTest::Shouter;
use XML::Comma::Pkg::DecoratorTest::Whisperer;
use XML::Comma::Pkg::DecoratorTest::OverTalker;
use XML::Comma::Pkg::DecoratorTest::ConfigTalker;

use Test::More tests => 15;

# make a doc
my $doc = XML::Comma::Doc->new ( type => '_test_decorator' );
my $def = $doc->def;
ok("got doc and def ok")  if  $doc and $def;

# we should no longer be a simple Def
ok("ref(doc) ref")  unless  ref($doc) eq 'XML::Comma::Doc';

# make sure we're still a def, even after becoming something more.
ok("ref(doc) isa")  if  $doc->isa('XML::Comma::Doc');

# make sure we're a Talker
ok("isa Talker")  if  $doc->isa('XML::Comma::Pkg::DecoratorTest::Talker');

# can we say hello? 
ok("can say_hello")  if  $doc->say_hello eq 'hello';

# test a plain element
my $el = $doc->element('el_plain');
ok("get plain element")  if  $el->say_hello eq 'HELLO';
$doc->el_plain ( "foo" );
ok("set plain element")  if  $doc->el_plain eq 'foo';

# test a nested element and a child plain element
$el = $doc->element('el_nested');
ok("get nested element")  if  $el->say_hello eq 'hello';
my $cel = $el->element('el_plain');
ok("child nested element get")  if  $cel->say_hello eq '.....';
$doc->el_nested->el_plain ( "bar" );
ok("child nested element set")  if  $doc->el_nested->el_plain eq 'bar';

# test a blob element
ok("blob get")  if  $doc->el_blob->say_hello eq '.....';
$doc->el_blob->set ( "blob set" );
ok("blob set")  if  $doc->el_blob->get eq 'blob set';

# test multiple decorators and "super"
ok("super get")  if  $doc->element('multi')->say_hello eq '...--HEY';
$doc->multi ( "brown fox" );
ok("super set")  if  $doc->multi eq 'bro--HEY';

# test config
ok("test config")  if  $doc->element('configurable')->say_hello eq 'marhaban';



