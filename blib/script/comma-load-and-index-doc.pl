#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell
use strict;

use Getopt::Long;

my $file;

my %args = ( 'file=s', \$file );
&GetOptions ( %args );

use XML::Comma;

my $doc;

my $key = shift;
my $index_name = shift;

die "usage: comma-load-and-index-doc.pl <doc-key> <index-name>\n"
  if ! ($key and $index_name);

$doc = XML::Comma::Doc->retrieve ( $key );
$doc->index_update( index=>$index_name );

print "ok\n";
exit ( 0 );

