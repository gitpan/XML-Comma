# aaa_test_setup.t : do any global stuff that needs to happen for
# tests to get run.

use strict;

use Test::More tests => 1;
#TODO: more tests, convert shell to perl

#note we haven't overridden lib, so we'll get the active Configuration.pm
eval { require XML::Comma::Configuration; }; if($@) {
	use lib "blib/lib/";
	use XML::Comma::Configuration;
}
my $active_configuration_pm = $INC{"XML/Comma/Configuration.pm"};

use File::Path;

rmtree(".test");
#TODO: replace this with perl
#TODO: recursive symlink instead of copy to save some bytes...
`cp -RPpf blib .test`; #like cp -a but works on *bsd, macosx too
#copy active Configuration.pm in place if it exists
`cp -f "$active_configuration_pm" ".test/lib/XML/Comma/Configuration.pm" 2>/dev/null` if($active_configuration_pm);
chmod(0644, ".test/lib/XML/Comma/Configuration.pm");
###copy active Configuraiton.pm in place if we didn't generate one
####`[ ! -e .test/lib/XML/Comma/Configuration.pm ] && cp $active_configuration_pm .test/lib/XML/Comma/Configuration.pm`

use Cwd;
my $build_root_dir = getcwd;

#read in the config
my $CONFIG_FILE = ".test/lib/XML/Comma/Configuration.pm";
open(F, $CONFIG_FILE) || die "can't open $CONFIG_FILE for reading: $!";
my @conf = <F>;
close(F);

$CONFIG_FILE =~ s/^/$build_root_dir\//;
$CONFIG_FILE =~ s/\/\/+/\//g;
#write a dummy config file
open(F, ">$CONFIG_FILE") || die "can't open $CONFIG_FILE for writing: $!";
my $i = 0;
my $defs_directories_pos = -1;
my @defs_dirs = ();
while($i < $#conf) {
	my $line = $conf[$i];
	#change most everything to be relative to "$build_root_dir/.test"
	if($line =~ /^\s*(comma_root|log_file|document_root|sys_directory)\s+/) {
		$line =~ s/=>(\s+)([\'\"])/=>$1$2$build_root_dir\/.test\//;
		$line =~ s/\/\/+/\//g;
	}
	if($defs_directories_pos == -1) {
		if($line =~ /^\s*defs_directories/) {
			++$defs_directories_pos;
		}
	}
	if($defs_directories_pos == 0) {
		push @defs_dirs, $line;
		if($line =~ /^\s*\]\s*\,\s*$/) {
			++$defs_directories_pos;
		}
	}
	if($defs_directories_pos == 1) {
		my $code_string = join("", @defs_dirs);
		$code_string =~ s/^\s*defs_directories\s*=>//s;
		my $dh = eval $code_string;
		die "error executing defs_directories: $code_string: $@\n" if($@);
		my @dd = map { s/^/$build_root_dir\/.test\//; s/\/\/+/\//g; $_ } @$dh;
		print F "defs_directories =>\n";
		print F "\t[\n";
		print F join("\n", map { "\t\t'$_'," } @dd);
		print F "\n\t],\n";
		++$defs_directories_pos;
		++$i;
		@defs_dirs = @dd;
		next;
	}
	print F $line if($defs_directories_pos != 0);
	$i++;
}
close(F);
chmod(0640, $CONFIG_FILE) || warn "can't chmod $CONFIG_FILE: $!";

#note: just dump all defs into the first defs dir in our tmp Configuration.pm
my $d = $defs_dirs[0];
mkpath($d, 0, 0755);
#TODO: this, in perl
`find t/defs -type f -exec cp -f \{\} "$d" \\;`;

ok("dummy");
