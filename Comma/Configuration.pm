package XML::Comma::Configuration;
use base 'XML::Comma::Pkg::ModuleConfiguration'; 1;
__DATA__

##
#  system and defs directories set up for local TESTING
#
comma_root          =>     'TEST',
log_file            =>     'TEST/log.comma',
document_root       =>     'TEST/docs',
sys_directory       =>     'TEST/sys',
tmp_directory       =>     '/tmp',

defs_directories    =>
  [
   'TEST/defs/test',
   'TEST/defs/macros',
   'TEST/defs/standard',
  ],
#
##

##
#  A typical set of system and defs directories

#  comma_root          =>     '/usr/local/comma',
#  log_file            =>     '/usr/local/comma/log.comma',
#  document_root       =>     '/usr/local/comma/docs',
#  sys_directory       =>     '/usr/local/comma/sys',
#  tmp_directory       =>     '/tmp',

#  defs_directories    =>
#    [
#     '/allafrica/comma/defs',
#     '/usr/local/comma/defs',
#     '/usr/local/comma/defs/macros',
#     '/usr/local/comma/defs/standard',
#     '/usr/local/comma/defs/test'
#    ],

#
##

defs_from_PARs    =>     0,
defs_extension    =>     '.def',
macro_extension   =>     '.macro',
include_extension =>     '.include',

# pure perl parser, no need to use Inline
parser => 'PurePerl',

# faster, hairier parser
# parser => 'SimpleC',

hash_module       =>     'Digest::MD5',

mysql => {
          sql_syntax  =>  'mysql',
          dbi_connect_info => [
                               'DBI:mysql:comma:localhost', '', '',
                               { RaiseError => 1,
                                 PrintError => 0,
                                 ShowErrorStatement => 1,
                                 AutoCommit => 1,
                               } ],
         },

postgres => {
             sql_syntax  =>  'Pg',
             dbi_connect_info => [
                                  'DBI:Pg:dbname=comma', '', '',
                                  { RaiseError => 1,
                                    PrintError => 0,
                                    ShowErrorStatement => 1,
                                    AutoCommit => 1,
                                  } ],
            },

system_db        => 'mysql',
#system_db        => 'postgres',



