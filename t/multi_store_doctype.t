#!/usr/bin/perl -w
$|++;

use lib ".test/lib/";

use XML::Comma;
use File::Path;

use strict;

use Test::More tests => 29;

my $def_one_name = "_test_multi_first";
my $def_two_name = "_test_multi_second";

#### erase tree -- start over with doc creation
my $def_one = XML::Comma::Def->read ( name => $def_one_name );
rmtree ( $def_one->get_store('one')->base_directory() );
rmtree ( $def_one->get_store('two')->base_directory() );
my $def_two = XML::Comma::Def->read ( name => $def_two_name );
rmtree ( $def_two->get_store('one')->base_directory() );
rmtree ( $def_two->get_store('two')->base_directory() );

####

# test doctype store mismatches in index declarations in the defs
eval { XML::Comma::Def->read( name => "_test_multi_bad" ) };
ok ( $@ );

# stress store within the same doctype

for ( 1 .. 3 ) {
  my $doc = XML::Comma::Doc->new( type => $def_one_name );
  $doc->element( "foo" )->set( "foo_$_" );
  $doc->bar( "bar_$_" );
  $doc->store( store => "one" ); # updates indices 'one' and 'all'
  $doc->store( store => "two" ); # updates indices 'two' and 'all'
}

ok( "stores didn't barf" );

my $index_one = XML::Comma::Def->read( name => $def_one_name )
                               ->get_index( 'one' );

my $index_two = XML::Comma::Def->read( name => $def_one_name )
                               ->get_index( 'two' );

my $index_all = XML::Comma::Def->read( name => $def_one_name )
                               ->get_index( 'all' );
my $it;

ok( $index_one->count() == 3 );

ok( $index_two->count() == 3 );

ok( $index_all->count() == 6 );

ok( $index_all->count(where_clause => 'store="one"') == 3 );

$it = $index_all->iterator ( where_clause => 'store="one"' );

ok( 
  ++$it and $it->doc_id eq '001' and $it->store eq 'one'  and
  ++$it and $it->doc_id eq '002' and $it->store eq 'one'  and
  ++$it and $it->doc_id eq '003' and $it->store eq 'one' 
  );

$it = $index_all->iterator ( where_clause => 'store="two"' );

ok( 
  ++$it and $it->doc_id eq '001' and $it->store eq 'two'  and
  ++$it and $it->doc_id eq '002' and $it->store eq 'two'  and
  ++$it and $it->doc_id eq '003' and $it->store eq 'two'
  );

my $iter_count = 0;

my $iterator_all = XML::Comma::Def->read( name => $def_one_name )
                                  ->get_index( 'all' )
                                  ->iterator();
while( ++$iterator_all ) {
  my $doc = $iterator_all->retrieve_doc();
  $doc->erase();
  ++$iter_count;
}
ok( $iter_count == 6 );

ok( $index_all->count() == 0 );

{
  my $doc = XML::Comma::Doc->new( type => $def_one_name );
  $doc->element( "foo" )->set( "foo" );
  $doc->bar( "bar" );
  $doc->store( store => "two", keep_open => 1 ); # updates indexes 'two' and 'all'

  # We shouldn't be able to update index one with something stored in store two
  eval { $doc->index_update( index => "one" ) };
  ok( $@ );

  # but updating index 'all' should be fine
  eval { $doc->index_update( index => "all" ) };
  ok( ! $@ );

  ok( $doc->erase() );
}

# okay, now we try to index across document types.

for ( 1 .. 3 ) {
  my $doc_one = XML::Comma::Doc->new( type => $def_one_name );
  $doc_one->element( "foo" )->set( "foo_$_" );
  $doc_one->bar( "bar_$_" );
  $doc_one->store( store => "one" ); # updates 'one' and 'all' in this doctype
  $doc_one->store( store => "two" ); # updates 'two' and 'all' in this doctype

  my $doc_two = XML::Comma::Doc->new( type => $def_two_name );
  $doc_two->element( "foo" )->set( "foo_$_" );
  $doc_two->bar( "bar_$_" );
  $doc_two->store( store => "one" ); # updates only "local" indexes
  $doc_two->store( store => "two" ); # updates '_test_multi_first:all'
}

ok( $index_all->count() == 9 );

$it = $index_all->iterator;


ok(  ++$it and $it->doc_key eq "_test_multi_first|one|004" );
ok(  ++$it and $it->doc_key eq "_test_multi_first|one|005" );
ok(  ++$it and $it->doc_key eq "_test_multi_first|one|006" );
ok(  ++$it and $it->doc_key eq "_test_multi_first|two|005" ); #
ok(  ++$it and $it->doc_key eq "_test_multi_first|two|006" );
ok(  ++$it and $it->doc_key eq "_test_multi_first|two|007" );
ok(  ++$it and $it->doc_key eq "_test_multi_second|two|001" );
ok(  ++$it and $it->doc_key eq "_test_multi_second|two|002" );
ok(  ++$it and $it->doc_key eq "_test_multi_second|two|003" );


$it = $index_all->iterator ( where_clause => 'doctype="_test_multi_second"' );

ok( 
  ++$it and $it->store eq 'two'                           and
            $it->doc_key eq "_test_multi_second|two|001"  and
  ++$it and $it->doc_key eq "_test_multi_second|two|002"  and
  ++$it and $it->doc_key eq "_test_multi_second|two|003"
  );

$it = $index_all->iterator ( where_clause => 'doctype="_test_multi_first" AND
                                             store="one"' );
ok( 
  ++$it and $it->store eq 'one'                          and
            $it->doc_key eq "_test_multi_first|one|004"  and
  ++$it and $it->doc_key eq "_test_multi_first|one|005"  and
  ++$it and $it->doc_key eq "_test_multi_first|one|006"
  );

my $index_all_iterator = $index_all->iterator();
$iter_count = 0;
while ( ++$index_all_iterator ) {
  my $doc = $index_all_iterator->retrieve_doc();
  $doc->index_remove( index => "$def_one_name:all" );
  ++$iter_count;
}
ok( $iter_count == 9 );

eval { $index_all->rebuild() };
ok( $@ ); # wildcards need store => [ specs ]

$index_all->rebuild( 
# stress 'doctype:store; or 'store' (implies $index->doctype()  syntax)
  stores => [ "$def_two_name:two", 'two', 'one', "$def_two_name:two" ]
);
ok( $index_all->count() == 6 );

$index_two->rebuild();
ok( $index_two->count() == 3 );

# cleanup
my $i;
$i = XML::Comma::Def->read( name => $def_one_name )->get_store( 'one' )->iterator();
while ( my $d = $i->prev_retrieve() ) { $d->erase(); }
$i = XML::Comma::Def->read( name => $def_one_name )->get_store( 'two' )->iterator();
while ( my $d = $i->prev_retrieve() ) { $d->erase(); }
$i = XML::Comma::Def->read( name => $def_two_name )->get_store( 'one' )->iterator();
while ( my $d = $i->prev_retrieve() ) { $d->erase(); }
$i = XML::Comma::Def->read( name => $def_two_name )->get_store( 'two' )->iterator();
while ( my $d = $i->prev_retrieve() ) { $d->erase(); }
