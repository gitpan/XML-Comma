#!/bin/sh

#TODO: allow for -f[file] argument

continue=true
while [ \( "z$*" != z \) -a \( "z$continue" = ztrue \) ] ; do
	if echo "z$1" | grep -q '^z\-' ; then
		var="$1" ; shift

		# convert '--stuff' or '-stuff' to 'stuff'
		var=`echo $var | sed 's/^\-*//'`

		#f33r th1$ 1337 codez
		if echo $var | grep -qi -e '=' ; then
			#support = as delimiter
			val="$var"
			var=`echo $val | sed 's/=.*$//'`
			val=`echo $val | sed 's/^.*=//'`
			#echo case 1, $var : $val
		elif echo $var | grep -qi -e '^I.*/' ; then
			#allow -I/foo or -include_path/foo, etc.
			var=`echo $var | sed 's/^include.path/i/i'`
			var=`echo $var | sed 's/^include/i/i'`
			val="$var"
			var=`echo $var | sed 's/^\(.\).*$/\1/'`
			val=`echo $val | sed 's/^.\(.*\)$/\1/'`
			#echo case 2, $var : $val
		elif echo $var | grep -qi -e '^M.*::' ; then
			#allow -mFoo::bar --modFoo::Bar --moduleFoo::Bar, etc.
			var=`echo $var | sed 's/^module/m/i'`
			var=`echo $var | sed 's/^mod/m/i'`
			val="$var"
			var=`echo $var | sed 's/^\(.\).*$/\1/'`
			val=`echo $val | sed 's/^.\(.*\)$/\1/'`
			#echo case 3, $var : $val
		else
			val="$1" ; shift
			#echo case 4, $var : $val
		fi
		echo "$var" | grep -qi '^[li]' && include_path="$val"
		echo "$var" | grep -qi ^m && module="$val"
	else
		continue=false
	fi
done

if [ "z$*" = z ] ; then
 	echo "usage: $0 [ -L </path/to/perllib> ] [ -M <Some::Module> ] <list of doc_keys>" >&2
	exit 1
fi

cmd="perl "
[ "z$include_path" != z ] && cmd="$cmd -I$include_path"
[ "z$module" != z ]       && cmd="$cmd -M$module"
echo $cmd $*
#cat <<END;
$cmd <<END;
use strict;
use warnings;
if ( "z$module" ne "z" ) {
  eval "use $module";
  if ( \$@ ) { die "bad module load: \$@\n" }
}

#TODO: remove duplicates from @keys
my @keys=split(/\s+/, "$*");
if (! @keys) {
	die "internal error: shell script should have caught this problem";
}

foreach my \$key (@keys) {
	my \$doc = XML::Comma::Doc->retrieve ( \$key );
	\$doc->store();
	print "ok \$key\n";
}
exit (0);
END
