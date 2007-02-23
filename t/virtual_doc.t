use strict;

use lib ".test/lib/";

use XML::Comma;
use XML::Comma::VirtualDoc;

use Test::More tests => 46;

sub array_cmp {
	my ($ar1, $ar2) = @_;
	#same number of arguments
	return 0 unless(scalar(@$ar1) == scalar(@$ar2));
	foreach my $i (0..scalar(@$ar1)-1) {
		foreach my $el qw ( doc_id doc_key bar bart ) {
			my $a = $ar1->[$i]->$el;
			my $b = $ar2->[$i]->$el;
			#if one or the other isn't defined, return false
			return 0 if((defined($a) && !defined($b)) ||
				(!defined($a) && defined($b)));
			# print "a: ".$a.", b: ".$b."\n";
			#we're ok if neither is defined, or they are the same
			return 0 unless ((!defined($a) && !defined($b)) || ($a eq $b));
		}
	}
	return 1;		
}

my $vdef = XML::Comma::Def->_test_virtual_doc;
ok($vdef);

#document creation (12 tests)
for my $i qw ( baz quux xyzzy ) {
	my $d = XML::Comma::Doc->new(type => "_test_virtual_doc");
	ok($d);
	ok($d->bar($i));
	ok($d->bart("monkey"));
	ok($d->store(store => "main"));
}

#VirtualDoc creation from indexing iterator (3 tests)
my $it = $vdef->get_index("main")->iterator();
my @ivds = ();
while(++$it) {
	my $vd = XML::Comma::VirtualDoc->new($it);
	ok($vd); #make sure we can create the VirtualDoc
	push @ivds, $vd;
}

#indexing iterator vdoc behavior (15 tests)
my $n = 1;
foreach my $vd (@ivds) {
	#make sure the iterator behaves properly with respect to order
	ok($vd->doc_key && $vd->doc_key eq "_test_virtual_doc|main|000$n");
	++$n;
	#make sure the iterator has the element bar, but not bart
	ok($vd->{parent}->has_element("bar"));
	ok(!$vd->{parent}->has_element("bart"));
	#access bar and bart without error
	ok($vd->bar);
	ok($vd->bart);
} 

#VirtualDoc creation from storage iterator (3 tests)
my $sit = $vdef->get_store("main")->iterator(pos=>'-');
my @svds = ();
while(++$sit) {
	my $vd = XML::Comma::VirtualDoc->new($sit);
	ok($vd); #make sure we can create the VirtualDoc
	push @svds, $vd;
}

#storage iterator vdoc behavior (9 tests)
$n = 1;
foreach my $vd (@svds) {
	#make sure the iterator behaves properly with respect to order
	ok($vd->doc_key && $vd->doc_key eq "_test_virtual_doc|main|000$n");
	++$n;
	#access bar and bart without error
	ok($vd->bar);
	ok($vd->bart);
} 

#TODO: compare contents of @svds, @ivds
ok(array_cmp(\@svds, \@ivds));

#TODO: test to_array behavior
$it  = $vdef->get_index("main")->iterator();
$sit = $vdef->get_store("main")->iterator(pos=>'-');
my @ivds_from_to_array = $it->to_array();
my @svds_from_to_array = $sit->to_array();

#TODO: compare the contents of @ivds_from_to_array and @ivds
ok(array_cmp(\@ivds_from_to_array, \@ivds));
#TODO: compare the contents of @svds_from_to_array and @svds
ok(array_cmp(\@svds_from_to_array, \@svds));
