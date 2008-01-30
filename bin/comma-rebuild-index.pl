#!/usr/bin/perl -w
use strict;
use XML::Comma;
use XML::Comma::Util qw( dbg );

use Getopt::Long;
my $doc_type;
my $index_name;
my %args = ( 'type=s', \$doc_type,
             'index=s', \$index_name );
&GetOptions ( %args );

if ( ! $doc_type or ! $index_name ) {
  die "usage: rebuild-index.pl -type <document_type> -index <index_name>\n"
}

my $index = XML::Comma::Def->read(name=>$doc_type)->get_index($index_name);
$index->rebuild( verbose=> 1, workers=> 1 );
