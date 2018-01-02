#!/bin/sh
#
#  $Id$
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2018 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL

MAKE=${MAKE-make}
export MAKE

vspxdir="${HOME}/binsrc/vspx"
vspxsql=${vspxsql-$vspxdir/vspx.sql}
vspxxsd=${vspxxsd-$vspxdir/vspx.xsd}
vspxmetadir=${vspxmetadir-$vspxdir/.vspxmeta}
vspxmetasrc=${vspxmetasrc-$vspxdir/vspxmeta.xml}
cutterdir="${HOME}/binsrc/sqldoc"
if [ "z$CUTTER" != "z" ] ; then
    cutter=$CUTTER
else
    cutter="${cutterdir}/cutter"
fi
pwddir=`pwd`
cd "${cutterdir}"
echo "Running $MAKE in $cutterdir"
$MAKE
cd "${pwddir}"

begin_xml ()
{
	xml=$1
	printf "%s" '<?xml version="1.0" encoding="ISO-8859-1" ?>' > $xml
}

write_xml_cdata ()
{
	xml=$1
	tmp=$2
	printf "%s" '<![CDATA[' >> $xml
	sed 's/\]\]\>/\]\]\]\><![CDATA\]\>/g' < $tmp >> $xml
	printf "%s" ']]>' >> $xml
}

rm $vspxmetasrc
rm -rf $vspxmetadir
mkdir $vspxmetadir
echo 'Cutting SQLs for controls ...'
$cutter -P control -P validator -X -P obsolete -X -P base -N 1 -s $vspxsql -o $vspxmetadir/__controls.tmp
echo 'Grepping names of controls ...'
grep '^create type' $vspxmetadir/__controls.tmp | \
sed 's/\(create [ ]*type [ ]*vspx_\)\([a-zA-Z_][a-zA-Z0-9_]*\)\(.*\)/\2/g' > $vspxmetadir/__control_types0.tmp
sort $vspxmetadir/__control_types0.tmp > $vspxmetadir/__control_types.tmp
begin_xml $vspxmetasrc
echo "<controls>" >> $vspxmetasrc
for type in `cat $vspxmetadir/__control_types.tmp` ; do
	base=$vspxmetadir/${type}
	echo "Extracting 'create type' for control $type ..."
	echo "<control name=\"$type\">" >> $vspxmetasrc
	$cutter -BH1 "create type vspx_${type} " -BT3 ";" -s $vspxmetadir/__controls.tmp -o ${base}__all.tmp
	$cutter -BT1 "create type vspx_${type} " -s ${base}__all.tmp -o ${base}__comment0.tmp
	$cutter -BH1 "create type vspx_$type " -BS1 "create type vspx_" -s ${base}__all.tmp -o ${base}__code.tmp
	cat ${base}__comment0.tmp | sed 's/^--//g' > ${base}__comment.tmp
	write_xml_cdata ${base}__comment.xml ${base}__comment.tmp
	write_xml_cdata ${base}__code.xml ${base}__code.tmp
	echo "<!ENTITY vspx_${type}__comment SYSTEM \"${type}__comment.xml\">" >> $vspxmetadir/vspx.ent
	echo "<!ENTITY vspx_${type}__code SYSTEM \"${type}__code.xml\">" >> $vspxmetadir/vspx.ent
	echo "<sqlcomment>" >> $vspxmetasrc
	cat ${base}__comment.xml >> $vspxmetasrc
	echo "</sqlcomment>" >> $vspxmetasrc
	echo "<sqlcode>" >> $vspxmetasrc
	cat ${base}__code.xml >> $vspxmetasrc
	echo "</sqlcode>" >> $vspxmetasrc
	echo "</control>" >> $vspxmetasrc
done
echo 'Parsing examples ...'
for file in `ls $vspxdir/examples/*.vspx` ; do
	sedop0='s/\(.*\/\)//g'
	sedop1='s/\(__.*\)//g'
	sedop2='s/_/-/g'
	control=`echo $file | sed $sedop0 | sed $sedop1 | sed $sedop2`
	sedop1='s/\(\..*\)//g'
	example=`echo $file | sed $sedop0 | sed $sedop1`
	echo "Processing example '$example' for control '$control' ..."
	$cutter -BS1 "<v:page" -s $file -o $vspxmetadir/${example}__code.tmp
	$cutter -BT1 "<v:page" -s $file -o $vspxmetadir/${example}__cmt0.tmp
	cat $vspxmetadir/${example}__cmt0.tmp | sed 's/<!--!//g' | sed 's/-->//g' > $vspxmetadir/${example}__cmt1.tmp
	cat $vspxmetadir/${example}__cmt1.tmp | grep '\\brief' | sed 's/\\brief//g' > $vspxmetadir/${example}__cmttitle.tmp
	cat $vspxmetadir/${example}__cmt1.tmp | sed 's/^\([ ]*\\brief.*\)//g' > $vspxmetadir/${example}__cmtdescr.tmp
	echo "<example id='$example' control='$control'>" >> $vspxmetasrc
	echo "<title>" >> $vspxmetasrc
	write_xml_cdata $vspxmetasrc $vspxmetadir/${example}__cmttitle.tmp
	echo "</title>" >> $vspxmetasrc
	echo "<descr>" >> $vspxmetasrc
	write_xml_cdata $vspxmetasrc $vspxmetadir/${example}__cmtdescr.tmp
	echo "</descr>" >> $vspxmetasrc
	echo "<code>" >> $vspxmetasrc
	write_xml_cdata $vspxmetasrc $vspxmetadir/${example}__code.tmp
	echo "</code>" >> $vspxmetasrc
	echo "</example>" >> $vspxmetasrc
done

echo "Adding data from $vspxxsd ..."
cat $vspxxsd | sed "s/\([<][?]xml[^>]*[>]\)//g" >> $vspxmetasrc
echo "</controls>" >> $vspxmetasrc

#rm $vspxmetadir/*.tmp
echo "The result is in $vspxmetasrc and $vspxmetadir/*.xml"
