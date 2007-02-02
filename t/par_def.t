use strict;

unless ( XML::Comma->defs_from_PARs() ) {
  print "1..1\n";
  print "ok 1\n";
  exit 0;
}

print "1..6\n";

use FindBin;

use lib ".test/lib/";

use XML::Comma;
use XML::Comma::Util qw( dbg );

my $par_filename = File::Spec->catdir ( $FindBin::Bin, 'par_def.par' );
require PAR;
import  PAR  $par_filename;

print "ok 1\n";

my $doc = XML::Comma::Doc->new ( type => '_test_par_def' );
print "ok 2\n";

$doc->sing ( 'hello' );
print "ok 3\n"  if  $doc->sing() eq 'hello';

$doc->plu ( 'you' ); $doc->plu ( 'and' ); $doc->plu ( 'you' );
print "ok 4\n"  if  $doc->plu()->[0] eq 'you' and
                    $doc->plu()->[1] eq 'and' and
                    $doc->plu()->[2] eq 'you';

$doc->digits_el ( 23 );
print "ok 5\n";

eval { $doc->digits_el ( 'hello' ) };
print "ok 6\n"  if  $@;





