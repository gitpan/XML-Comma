package XML::Comma::Configuration;
use base 'XML::Comma::Pkg::ModuleConfiguration'; 1;
__DATA__

comma_root          =>     '/usr/local/comma',
log_file            =>     '/usr/local/comma/log.comma',
document_root       =>     '/usr/local/comma/docs',
sys_directory       =>     '/usr/local/comma/sys',
tmp_directory       =>     '/tmp',

defs_directories    =>
  [
   '/allafrica/comma/defs',
   '/usr/local/comma/defs',
   '/usr/local/comma/defs/macros',
   '/usr/local/comma/defs/standard',
   '/usr/local/comma/defs/test'
  ],

defs_from_PARs    =>     1,
defs_extension    =>     '.def',
macro_extension   =>     '.macro',
include_extension =>     '.include',

# parser => 'PurePerl',
parser => 'SimpleC',

hash_module       =>     'Digest::MD5',

mysql => {
          sql_syntax  =>  'mysql',
          dbi_connect_info => [
                               'DBI:mysql:comma:localhost',
 #                              'DBI:mysql:comma:homes',
                               'root',
                               'test',
                               { RaiseError => 1,
                                 PrintError => 0,
                                 ShowErrorStatement => 1,
                                 AutoCommit => 1,
                               } ],
         },

postgres => {
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

