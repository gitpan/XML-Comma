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
#    http://xml-comma.org, or read the tutorial included
#    with the XML::Comma distribution at docs/guide.html
#
##

package XML::Comma::VirtualDoc;
use vars '$AUTOLOAD';

@ISA = qw ( XML::Comma::Doc XML::Comma::NestedElement );

use strict;

##
# given an object with the necessary fields to fall back on, returns
# a new virtual doc (give it a doc or an iterator)
#

### TODO: Storage Iterators!

sub new {
	my ( $class, $parent, %args ) = @_; 
	if ($parent->isa("XML::Comma::Indexing::Iterator")) {
		$parent = XML::Comma::VirtualDocIteratorHolder->new($parent);
	} elsif ($parent->isa("XML::Comma::Storage::Iterator")) {
		$parent = $parent->read_doc;
	}
	my $self = { parent => $parent }; bless ( $self, $class );
	return $self;
}

## XML::Comma::Doc returns empty string unless we intercept here
sub doc_key { $_[0]->{parent}->doc_key; }

sub AUTOLOAD {
	my ( $self, @args ) = @_;
	# strip out local method name and stick into $m
	$AUTOLOAD =~ /::(\w+)$/;  my $m = $1;
	my $parent = $self->{parent};
	if($parent->isa("XML::Comma::Doc")) {
		return $parent->auto_dispatch( $m, @args );
	} elsif ($parent->isa("XML::Comma::VirtualDocIteratorHolder")) {
		if($parent->has_element($m)) {
			return $parent->dispatch( $m, @args );
		} else {
			#replace VirtualDocIteratorHolder with a proper XML::Comma::Doc
			$parent = XML::Comma::Doc->read($parent->{doc_key});
			return $parent->auto_dispatch( $m, @args );
		}
	} else {
		XML::Comma::Log->warn("VirtualDoc has unrecognized parent - trying double AUTOLOAD");
		return $parent->$m( @args );
	}
	#you never get here
}

#note: don't need a destroy method, count on $parent having one.

1;

### TODO: the below should be refactored into and used by 
### Indexing::Iterator code
### FIXME - this probably doesn't work for collections yet

package XML::Comma::VirtualDocIteratorHolder;
use strict;
use vars '$AUTOLOAD';

use Storable qw( dclone );

sub new {
	my ( $class, $iterator, %args ) = @_; 
	return bless (
		{ 
			doc_key      => $iterator->doc_key(),
			#the actual stuff in this row - copied so we don't get
			#a pointer to the latest data
			row          => dclone( $iterator->{_Iterator_current_row}),
			#for collections: column_type, etc.
			index        => $iterator->{_Iterator_index},
			#for _ce_pos equivalent
			columns_lst  => $iterator->{_Iterator_columns_lst},
			columns_pos  => $iterator->{_Iterator_columns_pos},
			columns_hash => { map { $_ => 1 } 
				@{$iterator->{_Iterator_columns_lst}} },
		},
	$class );
}

sub has_element { return $_[0]->{columns_hash}->{$_[1]}; }

sub doc_key { return $_[0]->{doc_key}; }

#swiped verbatim from Indexing::Iterator
#probably should memoize this / put it in a hash
sub _ce_pos {
	return 0 if $_[1] eq 'doc_id';
	return scalar ( @{$_[0]->{columns_lst}} ) + 1
		if $_[1] eq 'record_last_modified';
	return $_[0]->{columns_pos}->{$_[1]};
}

sub dispatch {
	my ( $self, $m, @args ) = @_;
	my @row = @{$self->{row}};
	my $pos = $self->_ce_pos($m);
	return $row[$pos];
}

1;

