package XML::Comma::Pkg::Mason::ParResolver;

use strict;
use vars qw( @ISA );

use PAR;
use Archive::Zip;
use File::Spec;
use Apache::Constants qw(OK DECLINED DIR_MAGIC_TYPE);

use HTML::Mason::Resolver;

my $PAR_MASON_DIR = 'mason';
my %PAR_aliases;

sub import {
  my $package = shift;
  my %arg     = @_;

  $arg{base} ||= 'HTML::Mason::Resolver::File::ApacheHandler';
  eval { require $arg{base}; };
  push @ISA, $arg{base};

  %PAR_aliases = %{$arg{par_paths} || {}};
}


my $in_trans_handler_subr;
sub trans_handler {
  my $r = shift;
  return DECLINED  if  $in_trans_handler_subr;

  my ( $par_archive_file, $par_alias_root, $stripped_path ) =
    __PACKAGE__->_is_par_location ( $r->uri );
  return DECLINED unless $par_archive_file;

  $in_trans_handler_subr = 1;
  my $subr = $r->lookup_uri ( $r->uri );
  $in_trans_handler_subr = 0;

  my ( $par_filename, $par_path_info,
       $par_is_directory, $par_full_path_readable ) = __PACKAGE__->
         _par_translation ( $r, $par_archive_file, $stripped_path );
  my $root = File::Spec->canonpath
    ( File::Spec->catfile ($r->document_root, $par_alias_root) );

  my $apache_filename = $subr->filename;
  $apache_filename =~ s|^$root||;

  my $pl = length ( $par_filename );
  my $al = length ( $apache_filename );

  # if par translation has produced a longer par filename apache
  # translation, we should be using the par component. if there is a
  # tie, we use the apache component, unless it doesn't seem to be
  # readable. explanation: a non-readable apache component (in the
  # context of a translation tie) suggests that mason will need to use
  # a dhandler, and if we're doing this resolution as part of a
  # mod_dir-invoked subrequest, things get all mucked up unless we
  # continue to take responsibility for things.)
  if (($pl > $al)  or
      (($pl == $al) and (! -r $apache_filename))) {
    $par_filename = File::Spec->
      canonpath ( File::Spec->catfile($par_alias_root, $par_filename) );
    $r->pnotes    ( PAR           => $par_archive_file );
    $r->pnotes    ( PAR_directory => $par_is_directory );
    $r->pnotes    ( PAR_filename  => $par_filename );
    $r->push_handlers ( PerlTypeHandler  => \&type_handler );
    $r->push_handlers ( PerlFixupHandler => \&fixup_handler );
    $r->filename  ( $par_filename );
    $r->path_info ( $par_path_info );
    return OK;
  } else {
    return DECLINED;
  }
}


# Our mime-type handler only cares about par directories. Anything
# else, we let the standard handler deal with.
sub type_handler {
  my $r = shift;
  if ( $r->pnotes('PAR_directory') ) {
    $r->content_type ( DIR_MAGIC_TYPE );
    return OK;
  } else {
    return DECLINED;
  }
}


# We use the fixup handler to set r->filename to out PAR archive file
# -- some parts of Mason expect there to really by an
# r->filename. It's also a convenient place to put debugging info.
sub fixup_handler {
  my $r = shift;

#   $r->warn ( 'PAR:           ' . $r->pnotes('PAR') );
#   $r->warn ( 'PAR_directory: ' . $r->pnotes('PAR_directory') );
#   $r->warn ( 'PAR_filename:  ' . $r->pnotes('PAR_filename') );
#   $r->warn ( 'path_info:     ' . $r->path_info );
#   $r->warn ( 'content_type:  ' . $r->content_type );

  $r->filename ( $r->pnotes('PAR') );
  return OK;
}


sub get_info {
  my ( $self, $path ) = @_;
  # is this a readable component as far as SUPER is concerned? If so,
  # we'll use SUPER's resolution
  my $cs = $self->SUPER::get_info ( $path );
  return  $cs  if  $cs;

  # try to resolve this from a par file
  my ( $par_archive_file, $par_alias_root, $stripped_path ) =
    $self->_is_par_location ( $path );
  return  unless  $par_archive_file;

  return $self->_get_par_component_info ( $path,
                                          $par_archive_file, $stripped_path );
}

sub _get_par_component_info {
  my ( $self, $path, $par_archive, $par_path ) = @_;
  my $zip = Archive::Zip->new ( $par_archive );
  return  unless  $zip->memberNamed
    ( File::Spec->canonpath(File::Spec->catfile($PAR_MASON_DIR, $par_path)) );

  return HTML::Mason::ComponentSource->new
    ( comp_path       => $path,
      friendly_name   => $path,
      comp_id         => "$par_archive||$path",
      last_modified   => (stat $par_archive)[9],
      source_callback => sub { $self->_get_par_source
                                 ( $par_archive, $par_path ); },
    );
}

sub _get_par_source {
  my ( $self, $par_archive, $par_path ) = @_;
  my $zip = Archive::Zip->new ( $par_archive );
  return $zip->contents
    ( File::Spec->canonpath(File::Spec->catfile($PAR_MASON_DIR, $par_path)) );
}


sub apache_request_to_comp_path {
  my ( $self, $r ) = @_;
  if ( $r->pnotes('PAR') ) {
    return $r->pnotes ( 'PAR_filename' );
  } else {
    return $self->SUPER::apache_request_to_comp_path ( $r );
  }
}

sub _is_par_location {
  my ( $self, $path ) = @_;
  foreach my $alias ( keys %PAR_aliases ) {
    return ( $PAR_aliases{$alias}, $alias, $path )  if  $path =~ s|^$alias||;
  }
  return;
}

sub _par_translation {
  my ( $self, $r, $par_file, $path ) = @_;
  $path = File::Spec->canonpath ( $path );
  my @dirs = File::Spec->splitdir ( $path );
  my $zip = Archive::Zip->new ( $par_file );

  my $file_part = $PAR_MASON_DIR;
  my $zip_member;
  do {
    $file_part = File::Spec->catdir ( $file_part, shift @dirs );
    $zip_member = $zip->memberNamed ( $file_part ) ||
                  $zip->memberNamed ( $file_part . '/' );
  } while ( @dirs        and
            $zip_member  and
            $zip_member->isa('Archive::Zip::DirectoryMember') );

  # if we ended up resolving to a directory, we should make note of that
  my $is_directory;
  if ( $zip_member and
       $zip_member->isa ('Archive::Zip::DirectoryMember') ) {
    $is_directory = 1;
  }

  # finally, we need to figure out our "filename" and "path_info"
  # parts, and return those plus a boolean indicating whether the
  # filename we resolved to is an actual existing thingy.
  $file_part =~ s|$PAR_MASON_DIR||;
  $path =~ m|($file_part)(\/?.*)|;
  my ( $filename, $path_info ) = ( $1 || '/', $2 );
  return ( $filename,
           $path_info,
           $is_directory,
           $zip_member ? 1 : 0 );
}


sub glob_path {
  my ( $self, $pattern ) = @_;
  die "illegal glob_path() -- not allowed to use preloads with ParResolver";
}


1;

