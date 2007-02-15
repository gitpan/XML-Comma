use strict;
use File::Path;

use lib ".test/lib/";

use XML::Comma;
use XML::Comma::Util qw( dbg );

my $doc_block = <<END;
<?xml version="1.0"?>
<!-- dummy comment -->
<_test_parser>
  <sing attr1="foo" attr2="bar"><a href="/foo">some link text</a></sing>
</_test_parser>
END

my $doc_cdata_block = <<END;
<?xml version="1.0"?>
<!-- dummy comment -->
<_test_parser>
  <sing><![CDATA[ a cdata string ]]></sing>
</_test_parser>
END

###########

use Test::More tests => 39;

##
# a bunch of simple parser tests
##

# well-formed root element
eval {
  XML::Comma->parser()->parse ( block=>
'<a>
<b>
<c foo="foo" bar="bar">some link text</c>
</b>
</a>
' ) }; if ( ! $@ ) { ok("1") }

# unclosed element
eval {
  XML::Comma->parser()->parse ( block=>'<a>' );
}; if ( $@ ) { ok("2") }

# another unclosed element
eval {
  XML::Comma->parser()->parse ( block=>'<a>foo' );
}; if ( $@ ) { ok("3") }

# unclosed tag
eval {
  XML::Comma->parser()->parse ( block=>'<a' );
}; if ( $@ ) { ok("4") }

# unclosed comment
eval {
  XML::Comma->parser()->parse ( block=>'<a><!-- foo </a>' );
}; if ( $@ ) { ok("5") }

# unclosed cdata
eval {
  XML::Comma->parser()->parse ( block=>'<a><![CDATA[ foo </a>' );
}; if ( $@ ) { ok("6") }

# unclosed processing instruction
eval {
  XML::Comma->parser()->parse ( block=>'<a><? ... </a>' );
}; if ( $@ ) { ok("7") }

# unclosed close tag
eval {
  XML::Comma->parser()->parse ( block=>'<a>foo</a' );
}; if ( $@ ) { ok("8") }

# another unclosed close tag (trailing whitespace)
eval {
  XML::Comma->parser()->parse ( block=>'<a>foo</a  ' );
}; if ( $@ ) { ok("9") }

# mismatched tag
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo</a></b>' );
}; if ( $@ ) { ok("10") }

# unclosed envelope el
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo</b>' );
}; if ( $@ ) { ok("11") }

# bad entity
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo &amp no semicolon</b></a>' );
}; if ( $@ ) { ok("12") }

# bad entity right up against a tag
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo &amp</b></a>' );
}; if ( $@ ) { ok("13") }

# bad <
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo < oops</b></a>' );
}; if ( $@ ) { ok("14") }

# good entity
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo &amp; with semi</b></a>' );
}; if ( ! $@ ) { ok("15"); }

# bad entity and < okay because inside comment
eval {
  XML::Comma->parser()->parse ( block=>'<a><b><!-- foo & < --></b></a>' );
}; if ( ! $@ ) { ok("16") }

# -- inside comment
eval {
  XML::Comma->parser()->parse ( block=>'<a><!-- illegal -- oops --></a>' );
}; if ( $@ ) { ok("17") }

eval {
  XML::Comma->parser()->parse ( block=>'<a><!-  and other things' );
}; if ( $@ ) { ok("18") }

# cdata
eval {
  XML::Comma->parser()->parse (block=>'<a><![CDATA[ hmmm & > < <foo> ]]></a>');
}; if ( ! $@ ) { ok("19") }
else { warn "$@"; }

# tricky cdata ending
eval {
  XML::Comma->parser()->parse (block=>'<a><![CDATA[ hmmm & > < <foo> ]   ]]]></a>');
}; if ( ! $@ ) { ok("20") }
else { warn "$@"; }

# trailing junk after root element
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo</b></a> more' );
}; if ( $@ ) { ok("21") }

# trailing comment after root element
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo</b></a> <!-- comment --> ' );
}; if ( ! $@ ) { ok("22") }


##
# now some simple actual document parsing
##

## try to make a def with a bunch of stuff in it
my $def = XML::Comma::Def->read ( name => '_test_parser' );
XML::Comma::DefManager->add_def ( $def );
ok("23")  if  $def;

## create a doc, so we can test what we get in elements
my $doc = XML::Comma::Doc->new ( block=>$doc_block );
ok("24") if $doc;
ok("25") if $doc->sing() eq '<a href="/foo">some link text</a>';
# and attributes
ok("26") if $doc->element('sing')->get_attr('attr1') eq 'foo';
ok("27") if $doc->element('sing')->get_attr('attr2') eq 'bar';

my $doc_cd = XML::Comma::Doc->new ( block=>$doc_cdata_block );
ok("28") if $doc_cd->sing() eq 'a cdata string';

$doc->element ( 'included_element_one' )->set ( 'foo bar' );
ok("29");
ok("30")  if
  $doc->element ( 'included_element_one' )->get() eq 'foo bar';

$doc->element ( 'included_element_two' )->set ( 'b' );
ok("31");
ok("32")  if
  $doc->element ( 'included_element_two' )->get() eq 'b';

ok("33")  if
  join ( ',', sort $doc->element ( 'included_element_two' )->enum_options() ) eq 'a,b,c';


$doc->element ( 'dynamic_include_element_one' )->set ( 'hello di' );
ok("34")  if  $doc->dynamic_include_element_one() eq 'hello di';

$doc->element ( 'dyn_arg_el_one' )->set ( 'hello da1' );
ok("35")  if  $doc->dyn_arg_el_one() eq 'hello da1';

$doc->element ( 'dyn_arg_el_two' )->set ( 'hello da2' );
ok("36")  if  $doc->dyn_arg_el_two() eq 'hello da2';

# messy collection of files -- this should be cleaned up and made
# pretty and regular

eval {
  $def = XML::Comma::Def->read ( name => '_test_parser_di_lst_eval_err' ); 
}; ok("37") if  $@ and $@ =~ m|error while evaling args list|;

eval { 
  $def = XML::Comma::Def->read ( name => '_test_parser_di_sub_eval_err' );
}; ok("38")  if  $@ and $@ =~ m|error while evaling|;

eval { 
  $def = XML::Comma::Def->read ( name => '_test_parser_di_sub_exe_err' );
}; ok("39")  if  $@ and $@ =~ m|ouch|;

# mixin parsing/instantiation

# my $mdoc = XML::Comma::Doc->new ( type => '_test_parser_mixin' );
# my $mel = $mdoc->element('mixed_in');
