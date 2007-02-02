use Test::Harness qw( runtests );
use FindBin;

use XML::Comma;

my $dir = $FindBin::Bin;
chdir $dir;

print "--- unit tests from t/ directory --- \n";
runtests (

't/util.t',
't/parser.t',
't/bootstrap.t',
't/validation.t',
't/storage.t',
't/virtual_element.t',
't/document_hooks.t',
't/indexing.t',
't/order.t',
't/read_only.t',
't/index_only.t',
't/par_def.t',
't/timestamp.t',

);
print "---\n\n";



#  print "--- story functional tests -- \n";
#   runtests qw( functional_test/story-test.pl );
#  print "---\n\n";




