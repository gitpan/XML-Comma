##
#
#    Copyright 2001, AllAfrica Global Media
#
#    This file is part of XML::Comma
#
#    XML::Comma is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    For more information about XML::Comma, point a web browser at
#    http://xymbollab.com/tools/comma/, or read the tutorial included
#    with the XML::Comma distribution at docs/guide.html
#
##

package XML::Comma;

use strict;
use vars '$AUTOLOAD';

BEGIN {

  $XML::Comma::VERSION = '1.00';

  my $config =
  {

  comma_root          =>     '/usr/local/comma',
  document_root       =>     '/usr/local/comma/docs',
  tmp_directory       =>     '/tmp',

  defs_directories    =>
    [
     '/usr/local/comma/defs',
     '/usr/local/comma/defs/macros',
     '/usr/local/comma/defs/standard',
     '/usr/local/comma/defs/test'
    ],

  defs_extension    =>     '.def',
  macro_extension   =>     '.macro',

  #parser => 'PurePerl',
  parser => 'SimpleC',

  hash_module       =>     'Digest::MD5',

  mysql            =>      {
                            sql_syntax  =>  'mysql',
                            dbi_connect_info => [
                                                 'DBI:mysql:comma:localhost',
                                                 'root',
                                                 'test',
                                                 { RaiseError => 1,
                                                   PrintError => 0,
                                                   ShowErrorStatement => 1,
                                                   AutoCommit => 1,
                                                 } ],
                           },

   postgres         =>      {
                            sql_syntax  =>  'Pg',
                            dbi_connect_info => [
                                                 'DBI:Pg:dbname=comma',
                                                 'root',
                                                 'test',
                                                 { RaiseError => 1,
                                                   PrintError => 0,
                                                   ShowErrorStatement => 1,
                                                   AutoCommit => 1,
                                                 } ],
                           },

  system_db        => 'mysql',
  #system_db        => 'postgres',

  log_file => '/tmp/log.comma',
  };

  sub parser {
    return 'XML::Comma::Parsing::' . $config->{parser};
  }

  sub lock_singlet {
    return $config->{_lock_singlet} ||= XML::Comma::SQL::Lock->new();
  }

  sub pnotes {
    return XML::Comma::DefManager->get_pnotes ( $_[1] );
  }

  sub AUTOLOAD {
    my ( $self, @args ) = @_;
    # strip out local method name and stick into $m
    $AUTOLOAD =~ /::(\w+)$/;  my $m = $1;
    # check that this configuration variable exists
    if ( ! exists $$config{$m} ) {
      XML::Comma::Log->err
          ( 'UNKNOWN_CONFIG_VAR',
            "no such config variable '$m'" );
    }
    #die "no such config variable $m\n"  if  ! exists $$config{$m};
    # call holder's dispatch figure-outer
    return $config->{$m};
  }

  # use the parser class given above
  eval "use ${ \( XML::Comma::parser() ) }";
  die "can't use parser class: $@\n" if $@;

}

# externally-required modules
use Proc::ProcessTable;

# comma modules
use XML::Comma::Log;
use XML::Comma::SQL::Lock;
use XML::Comma::Configable;
use XML::Comma::Hookable;
use XML::Comma::Methodable;
use XML::Comma::AbstractElement;
use XML::Comma::NestedElement;
use XML::Comma::BlobElement;
use XML::Comma::Element;
use XML::Comma::Doc;
use XML::Comma::Def;
use XML::Comma::Storage::Util;
use XML::Comma::Storage::FileUtil;
use XML::Comma::Storage::Store;
use XML::Comma::Indexing::Index;
use XML::Comma::Bootstrap;
use XML::Comma::DefManager;
my $hash_module = XML::Comma->hash_module();
eval "use $hash_module";
if ( $@ ) {
  die "startup error while trying to use hash module '$hash_module': $@\n";
}


1;
__END__


=head1 NAME

XML::Comma - A framework for structured document manipulation

=head1 SYNOPSIS

  use XML::Comma;
  blah blah blah

=head1 DESCRIPTION

  This is the "entry point" for using the XML::Comma modules. 

=head1 AUTHOR

  comma@xymbollab.com

=head1 SEE ALSO

  http://xymbollab.com/tools/comma/guide.html

=cut


