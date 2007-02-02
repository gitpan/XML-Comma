package XML::Comma::Configuration;
use base 'XML::Comma::Pkg::ModuleConfiguration'; 1;
__DATA__

##
#  system and defs directories
#
comma_root          =>     '/usr/local/comma',
log_file            =>     '/usr/local/comma/log.comma',
document_root       =>     '/usr/local/comma/docs',
sys_directory       =>     '/usr/local/comma/sys',
tmp_directory       =>     '/tmp',

defs_directories    =>
    [
     '/usr/local/comma/defs',
     '/usr/local/comma/macros',
     '/usr/local/comma/standard',
     '/usr/local/comma/test'
    ],

#
##

defs_from_PARs    =>     1,
defs_extension    =>     '.def',
macro_extension   =>     '.macro',
include_extension =>     '.include',

#do we validate a doc created with new( [ file | block ] => ... )?
validate_new      =>     1,

parser            =>     'PurePerl',
hash_module       =>     'Digest::MD5',

mysql =>
  { sql_syntax  =>  'mysql',
    dbi_connect_info => 
    [ 'DBI:mysql:comma:localhost;mysql_local_infile=1', 'root', '',
      { RaiseError => 1,
        PrintError => 0,
        ShowErrorStatement => 1,
        AutoCommit => 1,
      } ],
  },
postgres =>
  { sql_syntax  =>  'Pg',
    dbi_connect_info => 
    [ 'DBI:Pg:dbname=comma', '', '',
      { RaiseError => 1,
        PrintError => 0,
        ShowErrorStatement => 1,
        AutoCommit => 1,
      } ],
  },
system_db        => 'mysql',
#system_db        => 'postgres',

