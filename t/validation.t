use strict;
use File::Path;

print "1..102\n";

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
print "ok 1\n"  if  $def;

## create the doc (which tests permitting plural creation)
my $doc = XML::Comma::Doc->new ( block=>$doc_block );
print "ok 2\n" if $doc;

## shouldn't be able to add more to singular elements
eval { $doc->add_element('sing') };
print "ok 3\n"  if  $@;
eval { $doc->element('nested')->add_element('nested_sing') }; 
print "ok 4\n"  if  $@;
## but should be able to add a plural one
$doc->element('nested')->add_element('nested_plu')->set('added and set');
print "ok 5\n";

## date8
my @apms = $doc->element('d8')->applied_macros();
print "ok 6\n"  if  $apms[0] eq 'date_8';
@apms = $doc->element('d8')->def()->applied_macros();
print "ok 7\n"  if  $apms[0] eq 'date_8';

print "ok 8\n"  if  $doc->element('d8')->applied_macros() == 1;

print "ok 9\n"  if  $doc->element('d8')->applied_macros ( 'date_8' );
print "ok 10\n"  unless  $doc->element('d8')->applied_macros ( 'integer' );

$doc->element('d8')->set('20001122');
print "ok 11\n"  if  $doc->element('d8')->get() eq '20001122';
# too short, too long, non-digits
eval { $doc->element('d8')->set('2000112') };
print "ok 12\n"  if  $@;
eval { $doc->element('d8')->set('200011222') };
print "ok 13\n"  if  $@;
eval { $doc->element('d8')->set('2000112a') };
print "ok 14\n"  if  $@;
# invalid date (according to calendar-checking)
eval { $doc->element('d8')->set('20001322') };
print "ok 15\n"  if  $@;
eval { $doc->element('d8')->set('20000931') };
print "ok 16\n"  if  $@;

## unix_time
print "ok 17\n"  if  $doc->element('ut')->applied_macros ( 'unix_time' );
$doc->element('ut')->set('975712009');
print "ok 18\n"  if  $doc->element('ut')->get() eq '975712009';
eval { $doc->element('ut')->set('975a') };
print "ok 19\n"  if  $@;

## one_to_ten
print "ok 20\n"  if  $doc->element('ot')->applied_macros ( 'range', 'integer' );
print "ok 21\n"  if  $doc->element('ot')->applied_macros ( 'range' );
print "ok 22\n"  if  $doc->element('ot')->applied_macros ( 'integer' );
print "ok 23\n"  if  $doc->element('ot')->applied_macros() == 2;
print "ok 24\n"  unless
  $doc->element('ot')->applied_macros ( 'range', 'date_8' );


$doc->element('ot')->set(1);
$doc->element('ot')->set(9);
$doc->element('ot')->set(10);
print "ok 25\n"  if  $doc->element('ot')->get() == 10;
eval { $doc->element('ot')->set('15') }; 
print "ok 26\n"  if  $@;
eval { $doc->element('ot')->set('2.4') };
print "ok 27\n"  if  $@;
print "ok 28\n"  if  $doc->element('ot')->range_low() == 1;
print "ok 29\n"  if  $doc->element('ot')->range_high() == 10;
# now test to make sure we can do a 'method' call from the def, too.
print "ok 30\n"  if  $doc->element('ot')->def()->method('range_low') == 1;
print "ok 31\n"  if  $doc->element('ot')->def()->range_low() == 1;

## enum
print "ok 32\n"  if  $doc->element('en')->set('foo');
print "ok 33\n"  if  $doc->element('en')->get() eq 'foo';
print "ok 34\n"  if  $doc->element('en')->set('kazzam');
print "ok 35\n"  if  $doc->element('en')->get() eq 'kazzam';
print "ok 36\n"  if  $doc->element('en')->set('bar');
print "ok 37\n"  if  $doc->element('en')->get() eq 'bar';
eval { $doc->element('en')->set('15') };
print "ok 38\n"  if  $@;
my @choices = $doc->element('en')->enum_options();
#dbg 'choices', join ( "--", sort @choices );
print "ok 39\n"  if  'foo--bar--kazzam' eq join ( "--", @choices );

eval { $doc->element('en')->set('') };
print "ok 40\n"  if  $@;

print "ok 41\n"  if  $doc->element('en_with_default')->get()  eq  'foo';
print "ok 42\n"  if  $doc->element('en_with_default')->set('foo');
print "ok 43\n"  if  $doc->element('en_with_default')->set('kazzam');
print "ok 44\n"  if  $doc->element('en_with_default')->set('bar');
print "ok 45\n"  if  $doc->element('en_with_default')->get() eq 'bar';
$doc->element('en_with_default')->set();
print "ok 46\n"  if  $doc->element('en_with_default')->get()  eq  'foo';
eval { $doc->element('en')->set('15') }; 
print "ok 47\n"  if  $@;

print "ok 48\n"  if  $doc->element('en_with_empty')->set('foo');
print "ok 49\n"  if  $doc->element('en_with_empty')->get()  eq  'foo';
$doc->element('en_with_empty')->set('');
print "ok 50\n"  if  $doc->element('en_with_empty')->get()  eq  '';

## arbritrary content set hook
$doc->element('capitalized')->set('Hello');
print "ok 51\n";
eval { $doc->element('capitalized')->set('hello') };
print "ok 52\n"  if  $@;

## unparseable content in element
eval { $doc->element('sing')->set( "& that's simple" ); };
print "ok 53\n" if $@;

## arg'ed escape
$doc->element('sing')->set ( "& that's simple", escape=>1 );
print "ok 54\n";
print "ok 55\n"  if  $doc->element('sing')->get() eq "&amp; that's simple";
print "ok 56\n"  if  $doc->element('sing')->get(unescape=>1) 
  eq "& that's simple";

# escape configs
$doc->all_basic_escaped ( "<foo>" );
print "ok 57\n"  if
  $doc->element('all_basic_escaped')->get_without_default() eq '&lt;foo&gt;';
print "ok 58\n"  if
  $doc->element('all_basic_escaped')->get(unescape=>0) eq '&lt;foo&gt;';
print "ok 59\n"  if
  $doc->element('all_basic_escaped')->get() eq '<foo>';
print "ok 60\n"  if
  $doc->element('all_basic_escaped')->get(unescape=>1) eq '<foo>';

eval { $doc->all_basic_escaped ( "<foo>", escape => 0 ); };
print "ok 61\n"  if  $@ and $@ =~ /BAD_CONTENT/;
$doc->all_basic_escaped ( "<foo>", escape => 1 );
print "ok 62\n"  if
  $doc->element('all_basic_escaped')->get(unescape=>0) eq '&lt;foo&gt;';

$doc->esc_basic_escaped ( "<foo>" );
print "ok 63\n"  if
  $doc->element('esc_basic_escaped')->get() eq '&lt;foo&gt;';
print "ok 64\n"  if
  $doc->element('esc_basic_escaped')->get(unescape=>0) eq '&lt;foo&gt;';
print "ok 65\n"  if
  $doc->element('esc_basic_escaped')->get(unescape=>1) eq '<foo>';

$doc->unesc_basic_escaped ( "&lt;foo&gt;" );
print "ok 66\n"  if
  $doc->element('unesc_basic_escaped')->get() eq '<foo>';
print "ok 67\n"  if
  $doc->element('unesc_basic_escaped')->get(unescape=>0) eq '&lt;foo&gt;';
print "ok 68\n"  if
  $doc->element('unesc_basic_escaped')->get(unescape=>1) eq '<foo>';

$doc->all_specify_escaped ( "X hello X" );
print "ok 69\n"  if
  $doc->element('all_specify_escaped')->get(unescape=>0) eq '--x-- hello --x--';
print "ok 70\n"  if
  $doc->element('all_specify_escaped')->get() eq 'X hello X';

## structure validate hook
$doc->element('sing')->set( "innocuous" );
print "ok 71\n";
$doc->element('sing')->set( "un-typical test" );
eval { $doc->validate(); };
print "ok 72\n" if $@;

my $d2 = XML::Comma::Doc->new ( type=>'_test_validation' );
# should fail because of plu (and nested, and nested_sing inside nested)
eval { $doc->validate(); };
print "ok 73\n" if $@;
$d2->element('plu')->set('foo');
# should fail because of nested (and nested_sing inside it)
eval { $doc->validate(); };
print "ok 74\n" if $@;
$d2->element('nested');
# should fail because of nested_sing inside nested
eval { $doc->validate(); };
print "ok 75\n" if $@;
# now fill nested_sing, and the validate should work
$d2->element('nested')->element('nested_sing')->set('foo');
$d2->validate_structure();
print "ok 76\n";

# default value
print "ok 77\n"  if  $doc->element('with_default')->get eq 'default stuff';
$doc->element('with_default')->set ( 'something different' );
print "ok 78\n"  if  $doc->element('with_default')->get eq 
  'something different';
# and the empty string, too?
$doc->element('with_default')->set ( '' );
print "ok 79\n"  if  $doc->element('with_default')->get eq '';
# and re-undef to get back where we started;
$doc->element('with_default')->set ( undef );
print "ok 80\n"  if  $doc->element('with_default')->get eq 'default stuff';

# hash test -- take a few hashes, while changing one of the elements,
# and make sure they match or not as expected
$doc->element('sing')->set ( 'hash test value 1' );
print "ok 81\n"  if  my $hash1 = $doc->comma_hash();
print "ok 82\n"  if  my $hash2 = $doc->comma_hash();
$doc->element('sing')->set ( 'hash test value 2' );
print "ok 83\n"  if  my $hash3 = $doc->comma_hash();
$doc->element('sing')->set ( 'hash test value 1' );
print "ok 84\n"  if  my $hash4 = $doc->comma_hash();
print "ok 85\n"  if  $hash1 eq $hash2;
print "ok 86\n"  if  $hash1 ne $hash3;
print "ok 87\n"  if  $hash1 eq $hash4;
# now change the one that the hash isn't supposed to take into account
$doc->element('not_hashificated')->set ( 'not hashed test value 1' );
print "ok 88\n"  if  my $hash5 = $doc->comma_hash();
print "ok 89\n"  if  $hash5 eq $hash4;

# check is_required
print "ok 90\n"  if  $doc->element_is_required ( 'plu' );
print "ok 91\n"  if  $doc->element_is_required ( 'nested' );
print "ok 92\n"  if  ! $doc->element_is_required ( 'with_default' );

# boolean macro
print "ok 93\n"  if $doc->bool() == 0; # default 0

$doc->bool ( 1 );
print "ok 94\n"  if  $doc->bool() == 1;
$doc->bool ( 'true' );
print "ok 95\n"  if  $doc->bool() == 1;
$doc->bool ( 'TRUE' );
print "ok 96\n"  if  $doc->bool() == 1;

$doc->bool ( 0 );
print "ok 97\n"  if  $doc->bool() == 0 and $doc->bool() eq '0';
$doc->bool ( 'false' );
print "ok 98\n"  unless  $doc->bool();
$doc->bool ( 'FALSE' );
print "ok 99\n"  unless $doc->bool();

print "ok 100\n"  if $doc->bool_default_true();
$doc->bool_default_true ( 'false' );
print "ok 101\n"  unless  $doc->bool_default_true();
$doc->bool_default_true ( 1 );
print "ok 102\n"  if  $doc->bool_default_true();

