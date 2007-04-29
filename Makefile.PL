#!/usr/bin/perl -w

use strict;

use ExtUtils::MakeMaker;

package MY;
sub MY::libscan {
  my ( $self, $passed_path ) = @_;
  # print " path --> $passed_path\n";
  my $path = $self->SUPER::libscan($passed_path);
  if ( $path =~ m|Comma/Configuration\.pm$| ) {
    # print "matched config path\n";
    if (
`perl -e 'eval { require XML::Comma::Configuration }; print "ok" unless \$@;'`
           eq 'ok' ) {
      print <<'END';

- XML::Comma is already installed on this machine. We'll use your
- existing XML::Comma::Configuration file for 'make test', and leave
- it alone during any future 'make install' operation. If you would
- actually prefer to use the new Comma/Configuration.pm file that's in
- this dist directory, you'll need to remove the one you have
- installed in Perl's %INC path, then do a 'make realclean; perl
- Makefile.PL'

END
      return '';
    }
  }
  return $path;
};

package main;


my @cmd_line_utils = qw(
bin/comma-drop-index.pl
bin/comma-load-doc.pl
bin/comma-load-and-store-doc.sh
bin/comma-load-and-index-doc.pl
);

my $dbd_module = "DBD::mysql";
eval { require DBD::mysql; }; if($@) {
	#no mysql, try pg
	$dbd_module = "DBD::Pg";
	eval { require DBD::Pg; }; if($@) {
		#neither found, use mysql by default due to its popularity
		$dbd_module = "DBD::mysql";
	}
}

my $prereq_pm = 
	# need Storable to run bin/comma-create-config.pl
	# but that's ok since it's been in core since 5.007003
	# (5.8 came out around 2002)
	{ 'Class::ClassDecorator'    => 0,
	  'Compress::Zlib'           => 0,
	  'Crypt::Blowfish'          => 0,
	  'Crypt::CBC'               => 0,
	  $dbd_module                => 0,
	  'DBI'                      => 0,
	  'Digest::HMAC_MD5'         => 0,
	  'Inline'                   => 0,
	  'Lingua::Stem'             => 0,
	  'Math::BaseCalc'           => 0,
	  'PAR'                      => 0,
	  'String::CRC'              => 0,
	  'Storable'                 => 0,
	  'Test::More'               => 0,
};

WriteMakefile(
    'NAME'         => 'XML::Comma',
    'ABSTRACT'     => 'XML::Comma document life-cycle platform',
    'EXE_FILES'    => \@cmd_line_utils,
    'VERSION_FROM' => 'lib/XML/Comma.pm',
    'PREREQ_PM'    => $prereq_pm,
    #'clean' => {
    #  'FILES' => 'lib/XML/Comma.pm'
    #}
);

#install base macros, defs, includes, etc.
use misc::MakeMakerMod;
misc::MakeMakerMod::add_steps(
   step => "install",
   what => "perl misc/install-extras.pl"
);
misc::MakeMakerMod::add_steps(
   step => "distclean",
   what => "rm -rf .test",
);

foreach my $pm (keys %$prereq_pm) {
	$pm =~ s/::\///g;
	$pm =~ s/$/.pm/;
	eval { require $pm; };
	if($@) {
		#die results in this output: "# Looks like your test died before it could output anything."
		warn "missing depends, stopping to let CPAN or user get them\n";
		exit(1);
	}
}

eval { require XML::Comma::Configuration; };
if ( $@ ) {
	my $ret = system qw( perl bin/comma-create-config.pl );
	$ret >>= 8;
	die "bin/comma-create-config.pl failed with error code $ret" if $ret;
}

