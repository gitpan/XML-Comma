use ExtUtils::MakeMaker;

package MY;
sub MY::libscan {
  my ( $self, $path ) = @_;
  #print " path --> $path\n";
  my $path = $self->SUPER::libscan($path);
  if ( $path eq 'Comma.pm' ) {
    if ( `perl -e 'eval { require XML::Comma }; print "ok" unless \$@;'`
           eq 'ok' ) {
      print <<'END';

- XML::Comma is already installed on this machine. We'll use your
- existing Comma.pm file for 'make test', and leave it alone during
- any future 'make install' operation. If you would actually prefer to
- use the new Comma.pm file that's in this dist directory, you'll need
- to remove the one you have installed in Perl's %INC path, then do a
- 'make realclean; perl Makefile.PL'

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
    'NAME'	=> 'XML::Comma',
    'VERSION_FROM' => 'Comma/Bootstrap.pm', # finds $VERSION
    'ABSTRACT' => 'XML::Comma document life-cycle platform',
    'EXE_FILES' => \@cmd_line_utils,
    'clean' => {
      'FILES' => 'lib/XML/Comma.pm'
    }
);
