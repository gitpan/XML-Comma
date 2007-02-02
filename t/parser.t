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

print "1..39\n";

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
' ) }; if ( ! $@ ) { print "ok 1\n" }

# unclosed element
eval {
  XML::Comma->parser()->parse ( block=>'<a>' );
}; if ( $@ ) { print "ok 2\n" }

# another unclosed element
eval {
  XML::Comma->parser()->parse ( block=>'<a>foo' );
}; if ( $@ ) { print "ok 3\n" }

# unclosed tag
eval {
  XML::Comma->parser()->parse ( block=>'<a' );
}; if ( $@ ) { print "ok 4\n" }

# unclosed comment
eval {
  XML::Comma->parser()->parse ( block=>'<a><!-- foo </a>' );
}; if ( $@ ) { print "ok 5\n" }

# unclosed cdata
eval {
  XML::Comma->parser()->parse ( block=>'<a><![CDATA[ foo </a>' );
}; if ( $@ ) { print "ok 6\n" }

# unclosed processing instruction
eval {
  XML::Comma->parser()->parse ( block=>'<a><? ... </a>' );
}; if ( $@ ) { print "ok 7\n" }

# unclosed close tag
eval {
  XML::Comma->parser()->parse ( block=>'<a>foo</a' );
}; if ( $@ ) { print "ok 8\n" }

# another unclosed close tag (trailing whitespace)
eval {
  XML::Comma->parser()->parse ( block=>'<a>foo</a  ' );
}; if ( $@ ) { print "ok 9\n" }

# mismatched tag
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo</a></b>' );
}; if ( $@ ) { print "ok 10\n" }

# unclosed envelope el
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo</b>' );
}; if ( $@ ) { print "ok 11\n" }

# bad entity
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo &amp no semicolon</b></a>' );
}; if ( $@ ) { print "ok 12\n" }

# bad entity right up against a tag
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo &amp</b></a>' );
}; if ( $@ ) { print "ok 13\n" }

# bad <
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo < oops</b></a>' );
}; if ( $@ ) { print "ok 14\n" }

# good entity
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo &amp; with semi</b></a>' );
}; if ( ! $@ ) { print "ok 15\n"; }

# bad entity and < okay because inside comment
eval {
  XML::Comma->parser()->parse ( block=>'<a><b><!-- foo & < --></b></a>' );
}; if ( ! $@ ) { print "ok 16\n" }

# -- inside comment
eval {
  XML::Comma->parser()->parse ( block=>'<a><!-- illegal -- oops --></a>' );
}; if ( $@ ) { print "ok 17\n" }

eval {
  XML::Comma->parser()->parse ( block=>'<a><!-  and other things' );
}; if ( $@ ) { print "ok 18\n" }

# cdata
eval {
  XML::Comma->parser()->parse (block=>'<a><![CDATA[ hmmm & > < <foo> ]]></a>');
}; if ( ! $@ ) { print "ok 19\n" }
else { print "$@\n"; }

# tricky cdata ending
eval {
  XML::Comma->parser()->parse (block=>'<a><![CDATA[ hmmm & > < <foo> ]   ]]]></a>');
}; if ( ! $@ ) { print "ok 20\n" }
else { print "$@\n"; }

# trailing junk after root element
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo</b></a> more' );
}; if ( $@ ) { print "ok 21\n" }

# trailing comment after root element
eval {
  XML::Comma->parser()->parse ( block=>'<a><b>foo</b></a> <!-- comment --> ' );
}; if ( ! $@ ) { print "ok 22\n" }


##
# now some simple actual document parsing
##

## try to make a def with a bunch of stuff in it
my $def = XML::Comma::Def->read ( name => '_test_parser' );
XML::Comma::DefManager->add_def ( $def );
print "ok 23\n"  if  $def;

## create a doc, so we can test what we get in elements
my $doc = XML::Comma::Doc->new ( block=>$doc_block );
print "ok 24\n" if $doc;
print "ok 25\n" if $doc->sing() eq '<a href="/foo">some link text</a>';
# and attributes
print "ok 26\n" if $doc->element('sing')->get_attr('attr1') eq 'foo';
print "ok 27\n" if $doc->element('sing')->get_attr('attr2') eq 'bar';

my $doc_cd = XML::Comma::Doc->new ( block=>$doc_cdata_block );
print "ok 28\n" if $doc_cd->sing() eq 'a cdata string';

$doc->element ( 'included_element_one' )->set ( 'foo bar' );
print "ok 29\n";
print "ok 30\n"  if
  $doc->element ( 'included_element_one' )->get() eq 'foo bar';

$doc->element ( 'included_element_two' )->set ( 'b' );
print "ok 31\n";
print "ok 32\n"  if
  $doc->element ( 'included_element_two' )->get() eq 'b';

print "ok 33\n"  if
  join ( ',', sort $doc->element ( 'included_element_two' )->enum_options() ) eq 'a,b,c';


$doc->element ( 'dynamic_include_element_one' )->set ( 'hello di' );
print "ok 34\n"  if  $doc->dynamic_include_element_one() eq 'hello di';

$doc->element ( 'dyn_arg_el_one' )->set ( 'hello da1' );
print "ok 35\n"  if  $doc->dyn_arg_el_one() eq 'hello da1';

$doc->element ( 'dyn_arg_el_two' )->set ( 'hello da2' );
print "ok 36\n"  if  $doc->dyn_arg_el_two() eq 'hello da2';

# messy collection of files -- this should be cleaned up and made
# pretty and regular

eval {
  $def = XML::Comma::Def->read ( name => '_test_parser_di_lst_eval_err' ); 
}; print "ok 37\n" if  $@ and $@ =~ m|error while evaling args list|;

eval { 
  $def = XML::Comma::Def->read ( name => '_test_parser_di_sub_eval_err' );
}; print "ok 38\n"  if  $@ and $@ =~ m|error while evaling|;

eval { 
  $def = XML::Comma::Def->read ( name => '_test_parser_di_sub_exe_err' );
}; print "ok 39\n"  if  $@ and $@ =~ m|ouch|;

# mixin parsing/instantiation

# my $mdoc = XML::Comma::Doc->new ( type => '_test_parser_mixin' );
# my $mel = $mdoc->element('mixed_in');
