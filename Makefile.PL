use ExtUtils::MakeMaker;

package MY;
sub MY::libscan {
  my ( $self, $path ) = @_;
  # print " path --> $path\n";
  my $path = $self->SUPER::libscan($path);
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

);

WriteMakefile(
    'NAME'	       => 'XML::Comma',
    'ABSTRACT'     => 'XML::Comma document life-cycle platform',
    'EXE_FILES'    => \@cmd_line_utils,
    'VERSION_FROM' => 'Comma.pm',
    'PREREQ_PM'    =>
              { Inline                   => 0,
                Proc::ProcessTable       => 0,
                Lingua::Stem             => 0,
                Crypt::Twofish           => 0,
                Crypt::CBC               => 0,
                Digest::HMAC_MD5         => 0,
                String::CRC              => 0,
                Math::BaseCalc           => 0,
                PAR                      => 0,
              },
    'clean' => {
      'FILES' => 'lib/XML/Comma.pm'
    }
);
