use strict;

print "1..33\n";

use XML::Comma;
use XML::Comma::Util qw( dbg );

my $doc_block = <<END;
<_test_virtual_element>
  <first>foo</first>
  <second>bar</second>
</_test_virtual_element>
END

###########

## make def
my $def = XML::Comma::Def->read ( name=>'_test_virtual_element' );
XML::Comma::DefManager->add_def ( $def );
print "ok 1\n"  if  $def;

## create the doc
my $doc = XML::Comma::Doc->new ( block=>$doc_block );
print "ok 2\n" if $doc;

## test our virtual get
print "ok 3\n" if  $doc->method('both') eq 'foobar' and 
  $doc->both() eq 'foobar';

## test our virtual set
print "ok 4\n" if  $doc->test_args("a", "b");
print "ok 5\n" if  $doc->method('both') eq 'ab';

# test illegal autoload
eval { $doc->sadf(); };
print "ok 6\n" if $@;

# test elements_group_add and elements_group_get
$doc->elements_group_add ( 'plu', '1', '2', '3' );
$doc->elements_group_add ( 'plu', '23', '35', '59' );
print "ok 7\n"
  if  '1/2/3/23/35/59' eq (join '/', @{$doc->elements_group_get('plu')});

# test elements_group_delete and elements_group_lists
$doc->elements_group_delete ( 'plu', 1, 3, 35, 59 );
print "ok 8\n"  if  '2/23' eq (join '/', @{$doc->elements_group_get('plu')});
print "ok 9\n"  if  $doc->elements_group_lists ( 'plu', 23 );
print "ok 10\n" if  ! $doc->elements_group_lists ( 'plu', 1 );

# test elements_group_clear
$doc->elements_group_delete ( 'plu' );
print "ok 11\n"  if  ! @{$doc->elements_group_get('plu')};

# test non-nested singular
$doc->element('first')->set('hello');
print "ok 12\n"  if  $doc->first() eq 'hello';
$doc->first('goodbye');
print "ok 13\n"  if  $doc->first() eq 'goodbye';

# test non-nested plural
$doc->elements_group_add ( 'plu', '1', '2', '3' );
print "ok 14\n"  if  '1/2/3' eq (join '/', @{$doc->elements_group_get('plu')});
print "ok 15\n"  if  '1/2/3' eq (join '/', @{$doc->plu()});
$doc->plu ( '12','19' );
print "ok 16\n" if  '1/2/3/12/19' eq (join '/', @{$doc->plu()});

# test nested singular
$doc->element('nested_sing')->element('ns_inside')->set('foo');
if (
    $doc->element('nested_sing')->element('ns_inside')->get() eq
    $doc->nested_sing->element('ns_inside')->get()
   ) { print "ok 17\n"; }

# test nested plural
my $nel1 = $doc->element('nested_plu');
my $nel2 = $doc->add_element('nested_plu');
my $nel3 = $doc->add_element('nested_plu');
my @nels = $doc->nested_plu();
print "ok 18\n"  if
  $nels[0] == $nel1  and  $nels[1] == $nel2  and  $nels[2] == $nel3;

# test delete_element() -- use elements just added
# delete 3
my $deleted = $doc->delete_element('nested_plu');
print "ok 19\n"  if  $deleted == 1;
@nels = $doc->nested_plu();
print "ok 20\n"
  if $nels[0] == $nel1  and  $nels[1] == $nel2;
# delete 2
$deleted = $doc->delete_element('nested_plu');
print "ok 21\n"  if  $deleted == 1;
@nels = $doc->nested_plu();
print "ok 22\n"  if
  $nels[0] == $nel1;
# delete 1
$deleted = $doc->delete_element('nested_plu');
print "ok 23\n"  if  $deleted == 1;
@nels = $doc->nested_plu();
#@nels = $doc->elements('nested_plu');
print "ok 24\n"  if  ! @nels;
# delete non-existent
$deleted = $doc->delete_element('nested_plu');
print "ok 25\n"  if  ! defined $deleted;

# test elements_group_add_uniq
$doc->elements_group_delete ( 'plu' );
$doc->elements_group_add_uniq ( 'plu', 'a', 'b' );
my ( $a, $b, $c, $d ) = $doc->elements_group_get ( 'plu' );
print "ok 26\n"  if  $a eq 'a' and $b eq 'b' and ! defined $c;
$doc->elements_group_add_uniq ( 'plu', 'a', 'b', 'c' );
( $a, $b, $c, $d ) = $doc->elements_group_get ( 'plu' );
print "ok 27\n"  if  $a eq 'a' and $b eq 'b' and $c eq 'c' and ! defined $d;

# test set hook
$doc->third ( "foo", value=>'bar' );
print "ok 28\n"  if  $doc->third() eq 'bar';
$doc->third ( "something else", value=>'fish' );
print "ok 29\n"  if  $doc->third() eq 'fish';

# test pnotes
print "ok 30\n"  if  $doc->def()->def_pnotes()->{test} eq 'ok';
$doc->def()->def_pnotes()->{foo} = 'bar';
print "ok 31\n"  if  $doc->def()->def_pnotes()->{foo} eq 'bar';
print "ok 32\n"  if
  $doc->element('looks_at_firsts_pnotes')->pn->{first_value} eq 'plop';
print "ok 33\n"  if
  XML::Comma->pnotes('_test_virtual_element:first')->{first_value} eq 'plop';
