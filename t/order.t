use strict;

print "1..50\n";

use XML::Comma;
use XML::Comma::Util qw( dbg );

my $doc_block = <<END;
<_test_order>
  <a>0</a>
  <b>1</b>
  <a>2</a>
  <b>3</b>
  <a>4</a>
  <b>5</b>
</_test_order>
END

###########

my $def = XML::Comma::Def->read ( name => '_test_order' );
print "ok 1\n"  if  $def;

## create the doc (which tests permitting plural creation)
my $doc = XML::Comma::Doc->new ( block=>$doc_block );
print "ok 2\n" if $doc;

my @elements = $doc->elements ( 'a', 'b' );
print "ok 3\n"  if  scalar(@elements) == 6;

for ( my $i=0; $i < scalar(@elements); $i++ ) {
  if ( ! $elements[$i]->get() == $i ) {
    die "did not match\n";
  }
}
print "ok 4\n";

$doc->group_elements();
print "ok 5\n";

@elements = $doc->elements ( 'a', 'b' );
print "ok 6\n"  if  $elements[0]->get()  == 0;
print "ok 7\n"  if  $elements[1]->get()  == 2;
print "ok 8\n"  if  $elements[2]->get()  == 4;
print "ok 9\n"  if  $elements[3]->get()  == 1;
print "ok 10\n"  if  $elements[4]->get()  == 3;
print "ok 11\n"  if  $elements[5]->get()  == 5;


my @sorted_as = $doc->sort_elements('a');
print "ok 12\n"  if  $sorted_as[0]->get() == 4;
print "ok 13\n"  if  $sorted_as[1]->get() == 2;
print "ok 14\n"  if  $sorted_as[2]->get() == 0;
print "ok 15\n"  if  ! $sorted_as[3];

my @as_again = $doc->elements('a');
print "ok 16\n"  if  $as_again[0]->get() == 4;
print "ok 17\n"  if  $as_again[1]->get() == 2;
print "ok 18\n"  if  $as_again[2]->get() == 0;
print "ok 19\n"  if  ! $as_again[3];

@elements = $doc->elements();
print "ok 20\n"  if  $elements[0]->get()  == 4;
print "ok 21\n"  if  $elements[1]->get()  == 2;
print "ok 22\n"  if  $elements[2]->get()  == 0;
print "ok 23\n"  if  $elements[3]->get()  == 1;
print "ok 24\n"  if  $elements[4]->get()  == 3;
print "ok 25\n"  if  $elements[5]->get()  == 5;
print "ok 26\n"  if  ! $elements[6];

@elements = $doc->sort_elements();
print "ok 27\n"  if  $elements[0]->get()  == 5;
print "ok 28\n"  if  $elements[1]->get()  == 4;
print "ok 29\n"  if  $elements[2]->get()  == 3;
print "ok 30\n"  if  $elements[3]->get()  == 2;
print "ok 31\n"  if  $elements[4]->get()  == 1;
print "ok 32\n"  if  $elements[5]->get()  == 0;
print "ok 33\n"  if  ! $elements[6];

@elements = $doc->elements();
print "ok 34\n"  if  $elements[0]->get()  == 5;
print "ok 35\n"  if  $elements[1]->get()  == 4;
print "ok 36\n"  if  $elements[2]->get()  == 3;
print "ok 37\n"  if  $elements[3]->get()  == 2;
print "ok 38\n"  if  $elements[4]->get()  == 1;
print "ok 39\n"  if  $elements[5]->get()  == 0;
print "ok 40\n"  if  ! $elements[6];

$doc->add_element('ranked')->rank(0);
$doc->add_element('ranked')->rank(1);
$doc->add_element('ranked')->rank(2);
$doc->add_element('ranked')->rank(3);

@elements = $doc->sort_elements('ranked');
print "ok 41\n"  if  $elements[0]->rank()  == 3;
print "ok 42\n"  if  $elements[1]->rank()  == 2;
print "ok 43\n"  if  $elements[2]->rank()  == 1;
print "ok 44\n"  if  $elements[3]->rank()  == 0;
print "ok 45\n"  if  ! $elements[4];

@elements = $doc->elements('ranked');
print "ok 46\n"  if  $elements[0]->rank()  == 3;
print "ok 47\n"  if  $elements[1]->rank()  == 2;
print "ok 48\n"  if  $elements[2]->rank()  == 1;
print "ok 49\n"  if  $elements[3]->rank()  == 0;
print "ok 50\n"  if  ! $elements[4];

