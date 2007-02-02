#!/usr/bin/perl -w
use strict;

use Getopt::Long;

my $file;

my %args = ( 'file=s', \$file );
&GetOptions ( %args );

use XML::Comma;

my $doc;

my $key = shift;

die "usage: comma-load-and-store-doc.pl <doc-key>\n"
  if ! $key;

$doc = XML::Comma::Doc->retrieve ( $key );
$doc->store();

print "ok\n";
exit ( 0 );

