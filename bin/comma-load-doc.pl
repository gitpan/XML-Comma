#!/usr/bin/perl -w
use strict;

use Getopt::Long;

my $file;

my %args = ( 'file=s', \$file );
&GetOptions ( %args );

use XML::Comma;

my $doc;

if ( ! $file ) {
  my $addr = shift();
  die "usage: comma-load-doc.pl [-file <filename>] [doc-key]\n"
    if ! $addr;
  $doc = XML::Comma::Doc->retrieve ( $addr );
} else {
  $doc = XML::Comma::Doc->new ( file => $file );
}

if ( $doc ) {
  print "ok\n";
  exit ( 0 );
}
