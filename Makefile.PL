use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'XML::Comma',
    'VERSION_FROM' => 'Comma.pm', # finds $VERSION
    'ABSTRACT' => 'XML::Comma document life-cycle platform',
    'EXE_FILES' => [],
    'clean' => {
      'FILES' => 'lib/XML/Comma.pm'
    }
);
