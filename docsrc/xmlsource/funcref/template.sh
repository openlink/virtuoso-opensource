# $Id$

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


name="$1"
miscinfo="$2"
prefix="${3-fn}"
#id=`echo "${name}" | sed 's/_/-/g'`
id=`echo "${name}" | sed 's/-/_/g'`
tgt="${name}.xml"
if [ -f "${tgt}" ]
then
  echo "The destination file ${tgt} already exists and will remain unchanged!"
else
cat > "${tgt}" <<EndOfTemplate
<?xml version="1.0" encoding="ISO-8859-1"?>
<!--

  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
  project.
  
  Copyright (C) 1998-2018 OpenLink Software
  
  This project is free software; you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the
  Free Software Foundation; only version 2 of the License, dated June 1991.
  
  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.
  
  You should have received a copy of the GNU General Public License along
  with this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
  
  $Id$
-->
<refentry id="${prefix}_${id}">
  <refmeta>
    <refentrytitle>${name}</refentrytitle>
    <refmiscinfo>${miscinfo}</refmiscinfo>
  </refmeta>
  <refnamediv>
    <refname>${name}</refname>
    <refpurpose></refpurpose>
  </refnamediv>
  <refsynopsisdiv>
    <funcsynopsis id="fsyn_${id}">
      <funcprototype id="fproto_${id}">
        <funcdef><function>${name}</function></funcdef>
	<paramdef> <parameter></parameter> </paramdef>
      </funcprototype>
    </funcsynopsis>
  </refsynopsisdiv>
  <refsect1 id="desc_${id}">
    <title>Description</title>
    <para></para>
  </refsect1>
  <refsect1 id="params_${id}">
    <title>Parameters</title>
    <refsect2><title></title>
      <para></para>
    </refsect2>
  </refsect1>
  <refsect1 id="ret_${id}"><title>Return Types</title>
    <para></para>
  </refsect1>
  <refsect1 id="errors_${id}">
    <title>Errors</title>

<!-- In case of non-function-specific errors, i.e. only common
     parameter errors are signalled, comment out the table below 
     otherwise add the unique error values as individual errorcodes -->

    <para>This function can generate the following errors:</para>
    <errorcode></errorcode>
  </refsect1>
  <refsect1 id="examples_${id}">
    <title>Examples</title>
    <example id="ex_${id}"><title></title>
      <para></para>
      <screen><![CDATA[
]]>
</screen>
    </example>
  </refsect1>
  <refsect1 id="seealso_${id}">
    <title>See Also</title>
    <para><link linkend="fn_XXX"><function>XXX</function></link></para>
  </refsect1>
</refentry>
EndOfTemplate

echo 'Do not forget to add the following line into virtdocs.xml:'
cat <<EndOfEntityDecl
<!ENTITY ${id}			SYSTEM	"funcref/${name}.xml">
EndOfEntityDecl

echo 'Do not forget to add the following line into functions.xml:'
cat <<EndOfEntityIncl
&${id};
EndOfEntityIncl
fi
