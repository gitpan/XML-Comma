use strict;

print "1..15\n";

use XML::Comma::Util qw( trim
                         array_includes
                         arrayref_remove_dups
                         arrayref_remove
                         flatten_arrayrefs
                         XML_basic_escape
                         XML_basic_unescape
                         XML_smart_escape
                       );

# flatten_arrayrefs
my @fl_list = flatten_arrayrefs ( 0, [ 1,2,3,4 ], (5,6,7,8), [9,10], 11 );

if ( "@fl_list" eq '0 1 2 3 4 5 6 7 8 9 10 11' ) {
  print "ok 1\n";
} else {
  print "not ok 1\n";
}


# trim
my @lista = ( '  one  ', 'two   ', '    three',  'four' );
my @listb = ( 'one', 'two', 'three', 'four' );
my @listc = trim ( @lista );
my $failed = 0;
foreach ( 0 .. $#listc ) {
  if ( $listc[$_] ne $listb[$_] ) {
    print "not ok 2\n";
    $failed = 1;
  }
}
print "ok 2\n"  if  ! $failed;


# array_includes
my @list_inc = qw( foo bar baz bash me my );
print "ok 3\n"  if  array_includes ( @list_inc, 'foo' );
print "ok 4\n"  if  array_includes ( @list_inc, 'bash' );
print "ok 5\n"  if  array_includes ( @list_inc, 'me' );


# arrayref_remove_dups
my @list_dups = qw( 1 1 1 2 3 4 1 4 4 3 5 6 7 8 8 1 9 );
arrayref_remove_dups \@list_dups;
print "ok 6\n"  if  "@list_dups" eq '1 2 3 4 5 6 7 8 9';

# arrayref_remove
my @list_pr = qw( 1 2 3 4 5 6 7 8 9 );
arrayref_remove ( \@list_pr, 1, 7, 8, 9 );
print "ok 7\n"  if  "@list_pr" eq '2 3 4 5 6';

# escape
my $str = XML_basic_escape ( 'foo&bar' );
print "ok 8\n"  if  $str eq 'foo&amp;bar';
print "ok 9\n"  if  XML_basic_unescape('foo&amp;bar') eq 'foo&bar';

$str = XML_basic_escape ( 'foo & bar' );
print "ok 10\n"  if  $str eq 'foo &amp; bar';
print "ok 11\n"  if  XML_basic_unescape('foo &amp; bar') eq 'foo & bar';

$str = XML_basic_escape ( 'foo &amp; bar' );
print "ok 12\n"  if  $str eq 'foo &amp;amp; bar';

$str = XML_smart_escape ( '<foo>&amp;<bar>' );
print "ok 13\n"  if  $str eq '&lt;foo&gt;&amp;&lt;bar&gt;';

$str = XML_basic_escape ( '<foo>&amp;<bar>' );
print "ok 14\n"  if  $str eq '&lt;foo&gt;&amp;amp;&lt;bar&gt;';
print "ok 15\n"  if  XML_basic_unescape( $str ) eq '<foo>&amp;<bar>';



