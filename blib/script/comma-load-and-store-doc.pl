#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell
use strict;

use Getopt::Long;

my $file;
my $module;
my %args = ( 'file=s', \$file,
             'module=s', \$module );
&GetOptions ( %args );

use XML::Comma;

if ( $module ) {
  eval "use $module";
  if ( $@ ) { die "bad module load: $@\n" }
}

my $doc;

my $key = shift;

die "usage: comma-load-and-store-doc.pl [-module <module to load/new()>] <doc-key>\n"
  if ! $key;

$doc = XML::Comma::Doc->retrieve ( $key );
$doc->store();

print "ok\n";
exit ( 0 );

