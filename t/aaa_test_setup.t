# aaa_test_setup.t : do any global stuff that needs to happen for
# tests to get run.

use strict;
use File::Spec;
use File::Copy;
use File::Path;
use FindBin;

use XML::Comma;
use XML::Comma::Util qw( dbg );
$|++;

print "1..4\n";

my @directories = @{ XML::Comma->defs_directories() };

my $defs_extension = XML::Comma->defs_extension();
my $t_defs_directory = File::Spec->catdir ( $FindBin::Bin, 'defs' );
my $test_directory;
foreach my $dir ( @directories ) {
  if ( $dir =~ /test$/ ) {
    $test_directory = $dir;
    last;
  }
}

my $macro_extension =   XML::Comma->macro_extension();
my $include_extension = XML::Comma->include_extension();
my $t_macros_directory = File::Spec->catdir ( $FindBin::Bin, 'defs', 'macros' );
my $macros_directory;
foreach my $dir ( @directories ) {
  if ( $dir =~ /macros$/ ) {
    $macros_directory = $dir;
    last;
  }
}

my $t_st_directory = File::Spec->catdir ( $FindBin::Bin, 'defs', 'standard' );
my $standard_directory;
foreach my $dir ( @directories ) {
  if ( $dir =~ /standard$/ ) {
    $standard_directory = $dir;
    last;
  }
}

#  dbg 't_defs', $t_defs_directory;
#  dbg 'test', $test_directory;
#  dbg 't_macros', $t_macros_directory;
#  dbg 'macros', $macros_directory;
#  dbg 'current directory', $FindBin::Bin;

die "Couldn't find a defs directory in Comma.pm\n"  if  ! $test_directory;
die "Couldn't find a macros directory in Comma.pm\n"  if  ! $macros_directory;
die "Couldn't find a standard defs directory in Comma.pm\n"  if  ! $standard_directory;
print "ok 1\n";

mkpath ( $test_directory );
opendir ( DIR, $t_defs_directory ) || die "can't open test defs dir: $!\n";
while ( my $filename = readdir(DIR) ) {
  if ( $filename =~ /$defs_extension$/ ) {
    print "copying $filename to $test_directory\n";
    copy ( File::Spec->catfile($t_defs_directory, $filename),
           File::Spec->catfile($test_directory,$filename) )
           || die " -- couldn't copy: $!\n";
  }
}
print "ok 2\n";

mkpath ( $macros_directory );
opendir ( DIR, $t_macros_directory ) || die "can't open test macros dir: $!\n";
while ( my $filename = readdir(DIR) ) {
  #print "ie - $include_extension -- $filename\n";
  if ( $filename =~ /$macro_extension$/  or
       $filename =~ /$include_extension$/ ) {
    print "copying $filename to $macros_directory\n";
    copy ( File::Spec->catfile($t_macros_directory, $filename),
           File::Spec->catfile($macros_directory,$filename) )
           || die " -- couldn't copy: $!\n";
  }
}
print "ok 3\n";

mkpath ( $standard_directory );
opendir ( DIR, $t_st_directory ) || die "can't open test standard dir: $!\n";
while ( my $filename = readdir(DIR) ) {
  if ( $filename =~ /$defs_extension$/ ) {
    print "copying $filename to $standard_directory\n";
    copy ( File::Spec->catfile($t_st_directory, $filename),
           File::Spec->catfile($standard_directory,$filename) )
           || die " -- couldn't copy: $!\n";
  }
}
print "ok 4\n";
