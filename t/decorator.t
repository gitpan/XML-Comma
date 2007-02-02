use strict;

use XML::Comma;
use XML::Comma::Pkg::DecoratorTest::Talker;
use XML::Comma::Pkg::DecoratorTest::Shouter;
use XML::Comma::Pkg::DecoratorTest::Whisperer;
use XML::Comma::Pkg::DecoratorTest::OverTalker;
use XML::Comma::Pkg::DecoratorTest::ConfigTalker;

print "1..15\n";

# make a doc
my $doc = XML::Comma::Doc->new ( type => '_test_decorator' );
my $def = $doc->def;
print "ok 1\n"  if  $doc and $def;

# we should no longer be a simple Def
print "ok 2\n"  unless  ref($doc) eq 'XML::Comma::Doc';

# make sure we're still a def, even after becoming something more.
print "ok 3\n"  if  $doc->isa('XML::Comma::Doc');

# make sure we're a Talker
print "ok 4\n"  if  $doc->isa('XML::Comma::Pkg::DecoratorTest::Talker');

# can we say hello? 
print "ok 5\n"  if  $doc->say_hello eq 'hello';

# test a plain element
my $el = $doc->element('el_plain');
print "ok 6\n"  if  $el->say_hello eq 'HELLO';
$doc->el_plain ( "foo" );
print "ok 7\n"  if  $doc->el_plain eq 'foo';

# test a nested element and a child plain element
$el = $doc->element('el_nested');
print "ok 8\n"  if  $el->say_hello eq 'hello';
my $cel = $el->element('el_plain');
print "ok 9\n"  if  $cel->say_hello eq '.....';
$doc->el_nested->el_plain ( "bar" );
print "ok 10\n"  if  $doc->el_nested->el_plain eq 'bar';

# test a blob element
print "ok 11\n"  if  $doc->el_blob->say_hello eq '.....';
$doc->el_blob->set ( "blob set" );
print "ok 12\n"  if  $doc->el_blob->get eq 'blob set';

# test multiple decorators and "super"
print "ok 13\n"  if  $doc->element('multi')->say_hello eq '...--HEY';
$doc->multi ( "brown fox" );
print "ok 14\n"  if  $doc->multi eq 'bro--HEY';

# test config
print "ok 15\n"  if  $doc->element('configurable')->say_hello eq 'marhaban';



