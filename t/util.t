use strict;

use Test::More tests => 18;

use lib ".test/lib/";

use XML::Comma::Util qw( trim
                         array_includes
                         arrayref_remove_dups
                         arrayref_remove
                         flatten_arrayrefs
                         XML_basic_escape
                         XML_basic_unescape
                         XML_smart_escape
                         random_an_string
                         urlsafe_ascify_32bits
                         urlsafe_deascify_32bits
                       );

# flatten_arrayrefs
my @fl_list = flatten_arrayrefs ( 0, [ 1,2,3,4 ], (5,6,7,8), [9,10], 11 );

ok("flatten_arrayrefs") if ( "@fl_list" eq '0 1 2 3 4 5 6 7 8 9 10 11' );


# trim
my @lista = ( '  one  ', 'two   ', '    three',  'four' );
my @listb = ( 'one', 'two', 'three', 'four' );
my @listc = trim ( @lista );
my $failed = 0;
foreach ( 0 .. $#listc ) {
  if ( $listc[$_] ne $listb[$_] ) {
    $failed = 1;
  }
}
ok("trim") unless $failed;


# array_includes
my @list_inc = qw( foo bar baz bash me my );
ok("array_includes foo")  if  array_includes ( @list_inc, 'foo' );
ok("array_includes bash")  if  array_includes ( @list_inc, 'bash' );
ok("array_includes me")  if  array_includes ( @list_inc, 'me' );


# arrayref_remove_dups
my @list_dups = qw( 1 1 1 2 3 4 1 4 4 3 5 6 7 8 8 1 9 );
arrayref_remove_dups \@list_dups;
ok("arrayref_remove_dups")  if  "@list_dups" eq '1 2 3 4 5 6 7 8 9';

# arrayref_remove
my @list_pr = qw( 1 2 3 4 5 6 7 8 9 );
arrayref_remove ( \@list_pr, 1, 7, 8, 9 );
ok("arrayref_remove")  if  "@list_pr" eq '2 3 4 5 6';

# escape
my $str = XML_basic_escape ( 'foo&bar' );
ok("XML_basic_escape 1")  if  $str eq 'foo&amp;bar';
ok("XML_basic_unescape 1")  if  XML_basic_unescape('foo&amp;bar') eq 'foo&bar';

$str = XML_basic_escape ( 'foo & bar' );
ok("XML_basic_escape 2")  if  $str eq 'foo &amp; bar';
ok("XML_basic_unescape 2")  if  XML_basic_unescape('foo &amp; bar') eq 'foo & bar';

$str = XML_basic_escape ( 'foo &amp; bar' );
ok("XML_basic_escape 3")  if  $str eq 'foo &amp;amp; bar';

$str = XML_smart_escape ( '<foo>&amp;<bar>' );
ok("XML_smart_escape")  if  $str eq '&lt;foo&gt;&amp;&lt;bar&gt;';

$str = XML_basic_escape ( '<foo>&amp;<bar>' );
ok("XML_basic_escape 4")  if  $str eq '&lt;foo&gt;&amp;amp;&lt;bar&gt;';
ok("XML_basic_escape 4")  if  XML_basic_unescape( $str ) eq '<foo>&amp;<bar>';

# base 64 stuff
ok("base64 random_an_string length")  if  length(random_an_string(12)) == 12;
my $time = time;
my $b64_time = urlsafe_ascify_32bits ( $time );
ok("base64 time length")  if  length($b64_time) == 6;
my $time2 = urlsafe_deascify_32bits ( $b64_time );
ok("urlsafe_deascify_32bits")  if  $time eq $time2;
