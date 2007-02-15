#!/usr/bin/perl -w
use strict;

use Getopt::Long;

my $file;

my %args = ( 'file=s', \$file );
&GetOptions ( %args );

use XML::Comma;

my $doc;

if ( ! $file ) {
  my $key = shift();
  die "usage: comma-load-doc.pl [-file <filename>] [doc-key]\n"
    if ! $key;
  $doc = XML::Comma::Doc->retrieve ( $key );
} else {
  $doc = XML::Comma::Doc->new ( file => $file );
}

if ( $doc ) {
  print "ok\n";
  exit ( 0 );
}
