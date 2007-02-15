use strict;

#TODO: convert test::more numbers to useful strings
use Test::More tests => 50;

use lib ".test/lib/";

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
ok("1")  if  $def;

## create the doc (which tests permitting plural creation)
my $doc = XML::Comma::Doc->new ( block=>$doc_block );
ok("2") if $doc;

my @elements = $doc->elements ( 'a', 'b' );
ok("3")  if  scalar(@elements) == 6;

for ( my $i=0; $i < scalar(@elements); $i++ ) {
  if ( ! $elements[$i]->get() == $i ) {
    die "did not match\n";
  }
}
ok("4");

$doc->group_elements();
ok("5");

@elements = $doc->elements ( 'a', 'b' );
ok("6")  if  $elements[0]->get()  == 0;
ok("7")  if  $elements[1]->get()  == 2;
ok("8")  if  $elements[2]->get()  == 4;
ok("9")  if  $elements[3]->get()  == 1;
ok("10")  if  $elements[4]->get()  == 3;
ok("11")  if  $elements[5]->get()  == 5;


my @sorted_as = $doc->sort_elements('a');
ok("12")  if  $sorted_as[0]->get() == 4;
ok("13")  if  $sorted_as[1]->get() == 2;
ok("14")  if  $sorted_as[2]->get() == 0;
ok("15")  if  ! $sorted_as[3];

my @as_again = $doc->elements('a');
ok("16")  if  $as_again[0]->get() == 4;
ok("17")  if  $as_again[1]->get() == 2;
ok("18")  if  $as_again[2]->get() == 0;
ok("19")  if  ! $as_again[3];

@elements = $doc->elements();
ok("20")  if  $elements[0]->get()  == 4;
ok("21")  if  $elements[1]->get()  == 2;
ok("22")  if  $elements[2]->get()  == 0;
ok("23")  if  $elements[3]->get()  == 1;
ok("24")  if  $elements[4]->get()  == 3;
ok("25")  if  $elements[5]->get()  == 5;
ok("26")  if  ! $elements[6];

@elements = $doc->sort_elements();
ok("27")  if  $elements[0]->get()  == 5;
ok("28")  if  $elements[1]->get()  == 4;
ok("29")  if  $elements[2]->get()  == 3;
ok("30")  if  $elements[3]->get()  == 2;
ok("31")  if  $elements[4]->get()  == 1;
ok("32")  if  $elements[5]->get()  == 0;
ok("33")  if  ! $elements[6];

@elements = $doc->elements();
ok("34")  if  $elements[0]->get()  == 5;
ok("35")  if  $elements[1]->get()  == 4;
ok("36")  if  $elements[2]->get()  == 3;
ok("37")  if  $elements[3]->get()  == 2;
ok("38")  if  $elements[4]->get()  == 1;
ok("39")  if  $elements[5]->get()  == 0;
ok("40")  if  ! $elements[6];

$doc->add_element('ranked')->rank(0);
$doc->add_element('ranked')->rank(1);
$doc->add_element('ranked')->rank(2);
$doc->add_element('ranked')->rank(3);

@elements = $doc->sort_elements('ranked');
ok("41")  if  $elements[0]->rank()  == 3;
ok("42")  if  $elements[1]->rank()  == 2;
ok("43")  if  $elements[2]->rank()  == 1;
ok("44")  if  $elements[3]->rank()  == 0;
ok("45")  if  ! $elements[4];

@elements = $doc->elements('ranked');
ok("46")  if  $elements[0]->rank()  == 3;
ok("47")  if  $elements[1]->rank()  == 2;
ok("48")  if  $elements[2]->rank()  == 1;
ok("49")  if  $elements[3]->rank()  == 0;
ok("50")  if  ! $elements[4];

