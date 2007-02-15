use strict;
use File::Path;

#TODO: convert test::more numbers to useful strings
use Test::More tests => 108;

use lib ".test/lib/";

use XML::Comma;
use XML::Comma::Util qw( dbg );

my $doc_block = <<END;
<_test_validation>
  <sing>blah blah</sing>

  <plu>blah</plu>
  <plu>blah</plu>
  <plu>blah</plu>

  <nested>
    <nested_sing>nah</nested_sing>
    <nested_plu>nah</nested_plu><nested_plu>nah</nested_plu>
  </nested>

</_test_validation>
END

###########

## make def
my $def = XML::Comma::Def->read ( name => '_test_validation' );
ok("1")  if  $def;

## create the doc (which tests permitting plural creation)
my $doc = XML::Comma::Doc->new ( block=>$doc_block );
ok("2") if $doc;

## shouldn't be able to add more to singular elements
eval { $doc->add_element('sing') };
ok("3")  if  $@;
eval { $doc->element('nested')->add_element('nested_sing') }; 
ok("4")  if  $@;
## but should be able to add a plural one
$doc->element('nested')->add_element('nested_plu')->set('added and set');
ok("5");

## date8
my @apms = $doc->element('d8')->applied_macros();
ok("6")  if  $apms[0] eq 'date_8';
@apms = $doc->element('d8')->def()->applied_macros();
ok("7")  if  $apms[0] eq 'date_8';

ok("8")  if  $doc->element('d8')->applied_macros() == 1;

ok("9")  if  $doc->element('d8')->applied_macros ( 'date_8' );
ok("10")  unless  $doc->element('d8')->applied_macros ( 'integer' );

$doc->element('d8')->set('20001122');
ok("11")  if  $doc->element('d8')->get() eq '20001122';
# too short, too long, non-digits
eval { $doc->element('d8')->set('2000112') };
ok("12")  if  $@;
eval { $doc->element('d8')->set('200011222') };
ok("13")  if  $@;
eval { $doc->element('d8')->set('2000112a') };
ok("14")  if  $@;
# invalid date (according to calendar-checking)
eval { $doc->element('d8')->set('20001322') };
ok("15")  if  $@;
eval { $doc->element('d8')->set('20000931') };
ok("16")  if  $@;
ok("17") if $doc->element('d8')->set('16000229');
eval { $doc->element('d8')->set('17000229') };
ok("18")  if  $@;

## unix_time
ok("19")  if  $doc->element('ut')->applied_macros ( 'unix_time' );
$doc->element('ut')->set('975712009');
ok("20")  if  $doc->element('ut')->get() eq '975712009';
eval { $doc->element('ut')->set('975a') };
ok("21")  if  $@;

## one_to_ten
ok("22")  if  $doc->element('ot')->applied_macros ( 'range', 'integer' );
ok("23")  if  $doc->element('ot')->applied_macros ( 'range' );
ok("24")  if  $doc->element('ot')->applied_macros ( 'integer' );
ok("25")  if  $doc->element('ot')->applied_macros() == 2;
ok("26")  unless
  $doc->element('ot')->applied_macros ( 'range', 'date_8' );


$doc->element('ot')->set(1);
$doc->element('ot')->set(9);
$doc->element('ot')->set(10);
ok("27")  if  $doc->element('ot')->get() == 10;
eval { $doc->element('ot')->set('15') }; 
ok("28")  if  $@;
eval { $doc->element('ot')->set('2.4') };
ok("29")  if  $@;
ok("30")  if  $doc->element('ot')->range_low() == 1;
ok("31")  if  $doc->element('ot')->range_high() == 10;
# now test to make sure we can do a 'method' call from the def, too.
ok("32")  if  $doc->element('ot')->def()->method('range_low') == 1;
ok("33")  if  $doc->element('ot')->def()->range_low() == 1;

## enum
ok("34")  if  $doc->element('en')->set('foo');
ok("35")  if  $doc->element('en')->get() eq 'foo';
ok("36")  if  $doc->element('en')->set('kazzam');
ok("37")  if  $doc->element('en')->get() eq 'kazzam';
ok("38")  if  $doc->element('en')->set('bar');
ok("39")  if  $doc->element('en')->get() eq 'bar';
eval { $doc->element('en')->set('15') };
ok("40")  if  $@;
my @choices = $doc->element('en')->enum_options();
#dbg 'choices', join ( "--", sort @choices );
ok("41")  if  'foo--bar--kazzam' eq join ( "--", @choices );

eval { $doc->element('en')->set('') };
ok("42")  if  $@;

ok("43")  if  $doc->element('en_with_default')->get()  eq  'foo';
ok("44")  if  $doc->element('en_with_default')->set('foo');
ok("45")  if  $doc->element('en_with_default')->set('kazzam');
ok("46")  if  $doc->element('en_with_default')->set('bar');
ok("47")  if  $doc->element('en_with_default')->get() eq 'bar';
$doc->element('en_with_default')->set();
ok("48")  if  $doc->element('en_with_default')->get()  eq  'foo';
eval { $doc->element('en')->set('15') }; 
ok("49")  if  $@;

ok("50")  if  $doc->element('en_with_empty')->set('foo');
ok("51")  if  $doc->element('en_with_empty')->get()  eq  'foo';
$doc->element('en_with_empty')->set('');
ok("52")  if  $doc->element('en_with_empty')->get()  eq  '';

## arbritrary content set hook
$doc->element('capitalized')->set('Hello');
ok("53");
eval { $doc->element('capitalized')->set('hello') };
ok("54")  if  $@;

## unparseable content in element
eval { $doc->element('sing')->set( "& that's simple" ); };
ok("55") if $@;

## arg'ed escape
$doc->element('sing')->set ( "& that's simple", escape=>1 );
ok("56");
ok("57")  if  $doc->element('sing')->get() eq "&amp; that's simple";
ok("58")  if  $doc->element('sing')->get(unescape=>1) 
  eq "& that's simple";

# escape configs
$doc->all_basic_escaped ( "<foo>" );
ok("59")  if
  $doc->element('all_basic_escaped')->get_without_default() eq '&lt;foo&gt;';
ok("60")  if
  $doc->element('all_basic_escaped')->get(unescape=>0) eq '&lt;foo&gt;';
ok("61")  if
  $doc->element('all_basic_escaped')->get() eq '<foo>';
ok("62")  if
  $doc->element('all_basic_escaped')->get(unescape=>1) eq '<foo>';

eval { $doc->all_basic_escaped ( "<foo>", escape => 0 ); };
ok("63")  if  $@ and $@ =~ /BAD_CONTENT/;
$doc->all_basic_escaped ( "<foo>", escape => 1 );
ok("64")  if
  $doc->element('all_basic_escaped')->get(unescape=>0) eq '&lt;foo&gt;';

$doc->esc_basic_escaped ( "<foo>" );
ok("65")  if
  $doc->element('esc_basic_escaped')->get() eq '&lt;foo&gt;';
ok("66")  if
  $doc->element('esc_basic_escaped')->get(unescape=>0) eq '&lt;foo&gt;';
ok("67")  if
  $doc->element('esc_basic_escaped')->get(unescape=>1) eq '<foo>';

$doc->unesc_basic_escaped ( "&lt;foo&gt;" );
ok("68")  if
  $doc->element('unesc_basic_escaped')->get() eq '<foo>';
ok("69")  if
  $doc->element('unesc_basic_escaped')->get(unescape=>0) eq '&lt;foo&gt;';
ok("70")  if
  $doc->element('unesc_basic_escaped')->get(unescape=>1) eq '<foo>';

$doc->all_specify_escaped ( "X hello X" );
ok("71")  if
  $doc->element('all_specify_escaped')->get(unescape=>0) eq '--x-- hello --x--';
ok("72")  if
  $doc->element('all_specify_escaped')->get() eq 'X hello X';

## structure validate hook
$doc->element('sing')->set( "innocuous" );
ok("73");
$doc->element('sing')->set( "un-typical test" );
eval { $doc->validate(); };
ok("74") if $@;

my $d2 = XML::Comma::Doc->new ( type=>'_test_validation' );
# should fail because of plu (and nested, and nested_sing inside nested)
eval { $doc->validate(); };
ok("75") if $@;
$d2->element('plu')->set('foo');
# should fail because of nested (and nested_sing inside it)
eval { $doc->validate(); };
ok("76") if $@;
$d2->element('nested');
# should fail because of nested_sing inside nested
eval { $doc->validate(); };
ok("77") if $@;
# now fill nested_sing, and the validate should work
$d2->element('nested')->element('nested_sing')->set('foo');
$d2->validate_structure();
ok("78");

# default value
ok("79")  if  $doc->element('with_default')->get eq 'default stuff';
$doc->element('with_default')->set ( 'something different' );
ok("80")  if  $doc->element('with_default')->get eq 
  'something different';
# and the empty string, too?
$doc->element('with_default')->set ( '' );
ok("81")  if  $doc->element('with_default')->get eq '';
# and re-undef to get back where we started;
$doc->element('with_default')->set ( undef );
ok("82")  if  $doc->element('with_default')->get eq 'default stuff';

# hash test -- take a few hashes, while changing one of the elements,
# and make sure they match or not as expected
$doc->element('sing')->set ( 'hash test value 1' );
ok("83")  if  my $hash1 = $doc->comma_hash();
ok("84")  if  my $hash2 = $doc->comma_hash();
$doc->element('sing')->set ( 'hash test value 2' );
ok("85")  if  my $hash3 = $doc->comma_hash();
$doc->element('sing')->set ( 'hash test value 1' );
ok("86")  if  my $hash4 = $doc->comma_hash();
ok("87")  if  $hash1 eq $hash2;
ok("88")  if  $hash1 ne $hash3;
ok("89")  if  $hash1 eq $hash4;
# now change the one that the hash isn't supposed to take into account
$doc->element('not_hashificated')->set ( 'not hashed test value 1' );
ok("90")  if  my $hash5 = $doc->comma_hash();
ok("91")  if  $hash5 eq $hash4;

# check is_required
ok("92")  if  $doc->element_is_required ( 'plu' );
ok("93")  if  $doc->element_is_required ( 'nested' );
ok("94")  if  ! $doc->element_is_required ( 'with_default' );

# boolean macro
ok("95")  if $doc->bool() == 0; # default 0

$doc->element('bool')->toggle;
ok("96")  if  $doc->bool() == 1;
$doc->element('bool')->toggle;
ok("97")  if  $doc->bool() == 0;

$doc->bool ( 1 );
ok("98")  if  $doc->bool() == 1;
$doc->bool ( 'true' );
ok("99")  if  $doc->bool() == 1;
$doc->bool ( 'TRUE' );
ok("100")  if  $doc->bool() == 1;

$doc->bool ( 0 );
ok("101")  if  $doc->bool() == 0 and $doc->bool() eq '0';
$doc->bool ( 'false' );
ok("102")  unless  $doc->bool();
$doc->bool ( 'FALSE' );
ok("103")  unless $doc->bool();

ok("104")  if $doc->bool_default_true();
$doc->bool_default_true ( 'false' );
ok("105")  unless  $doc->bool_default_true();
$doc->bool_default_true ( 1 );
ok("106")  if  $doc->bool_default_true();

my $long_to_truncate = "abcdefghijklmnop";
$doc->truncated ( $long_to_truncate );
ok("107")  if  $doc->truncated() eq 'abcdefg';
my $short_to_truncate = "abc";
$doc->truncated ( $short_to_truncate );
ok("108")  if  $doc->truncated() eq 'abc';
