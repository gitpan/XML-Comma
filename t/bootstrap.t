use strict;

use XML::Comma;

# first, let's create a comma root directory and put some defs down
# below it. this is the first test that is run by make tests, so we
# can do a little installation magic here.
my $root = XML::Comma->comma_root();
if ( ! -d $root ) {
  my $top_level_dir = `pwd`; chop $top_level_dir;
  my $dist_defs_dir = $top_level_dir . '/t/defs';
  mkdir $root;
  chmod 0777, $root;
  print `cp -r $dist_defs_dir $root`;
}

print "1..2\n";
print "ok 1\n";

my $bd = XML::Comma::Def->new
  (
   block => XML::Comma::Bootstrap->bootstrap_block()
  );

print "ok 2\n"  if  $bd;




