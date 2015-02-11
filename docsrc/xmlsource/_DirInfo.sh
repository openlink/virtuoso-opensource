# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


out='_DirInfo.xml'
echo '<?xml version="1.0" ?>' > $out
echo '<!--
  $Id$
  Copyright (C) 1998-2015 OpenLink Software
-->
<dirinfo>' >> $out
echo '  <dir path="">
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="adminui"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="backup"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="cinterface"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="dbconcepts"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="errors"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="freetext"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="functions"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="hooks"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="installation"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="intl"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="isql"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="ldap"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="mailsrv"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="mime"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="odbcimplementation"	/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="overview"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="preface"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="ptune"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="quicktours"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="repl"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="sampleapps"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="server"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="soap"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="sqlfunctions"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="sqlprocedures"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="sqlreference"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="support"		/>
<!--    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="test"			/> -->
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="tpcc"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="vdbconcepts"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="virtwhitepaper"	/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="vsp"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="vsptraining"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="webandxml"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="webserver"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="xpfs"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="xquery"		/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="yacsqlgrammar"		/>
<!--    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Drafts" name="uni"			/> -->
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Main" name="virtdocs"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="uddi"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="xslttrans"		/>
  </dir>' >> $out
echo '  <dir path="releasenotes">
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="Chapters" name="vrelnotes-nw"		/>
  </dir>' >> $out
echo '  <dir path="funcref">' >> $out
ls funcref/[a-z]*.xml | sed 's/funcref\///g' | sed 's/.xml//g' | sed 's/^\(.*\)$/    \<file type="xml" ext="xml" dtd="DocBook\/docbookx.dtd" group="Functions" name="\1"\/\>/g' >> $out
echo '  </dir>' >> $out
echo '  <dir path="vspx_ref">' >> $out
ls vspx_ref/vspx_*.xml | sed 's/vspx_ref\///g' | sed 's/.xml//g' | sed 's/^\(.*\)$/    \<file type="xml" ext="xml" dtd="DocBook\/docbookx.dtd" group="VSPX Controls" name="\1"\/\>/g' >> $out
echo '  </dir>' >> $out
echo '  <dir path="xmlref">' >> $out
ls xmlref/xpf_*.xml | sed 's/xmlref\///g' | sed 's/.xml//g' | sed 's/^\(.*\)$/    \<file type="xml" ext="xml" dtd="DocBook\/docbookx.dtd" group="XPFs" name="\1"\/\>/g' >> $out
echo '  </dir>' >> $out
echo '  <dir path="DocBook">
    <file type="dtd" ext="dtd" dtd="DocBook/docbookx.dtd" group="DocBook" name="calstblx"			/>
    <file type="dtd" ext="mod" dtd="DocBook/docbookx.dtd" group="DocBook" name="dbcentx"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="dbgenent"			/>
    <file type="dtd" ext="mod" dtd="DocBook/docbookx.dtd" group="DocBook" name="dbhierx"			/>
    <file type="dtd" ext="mod" dtd="DocBook/docbookx.dtd" group="DocBook" name="dbnotnx"			/>
    <file type="dtd" ext="mod" dtd="DocBook/docbookx.dtd" group="DocBook" name="dbpoolx"			/>
    <file type="dtd" ext="dtd" dtd="DocBook/docbookx.dtd" group="DocBook" name="dbtblcals"			/>
    <file type="dtd" ext="dtd" dtd="DocBook/docbookx.dtd" group="DocBook" name="dbtblxchg"			/>
    <file type="dtd" ext="dtd" dtd="DocBook/docbookx.dtd" group="DocBook" name="docbookx"			/>
    <file type="dtd" ext="dtd" dtd="DocBook/docbookx.dtd" group="DocBook" name="soextblx"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="DocBook" name="tblcals"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="DocBook" name="tblxchg"			/>
    <file type="xml" ext="xml" dtd="DocBook/docbookx.dtd" group="DocBook" name="test"				/>
  </dir>' >> $out
echo '  <dir path="DocBook/ent">
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-amsa"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-amsb"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-amsc"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-amsn"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-amso"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-amsr"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-box"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-cyr1"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-cyr2"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-dia"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-grk1"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-grk2"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-grk3"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-grk4"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-lat1"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-lat2"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-num"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-pub"			/>
    <file type="dtd" ext="ent" dtd="DocBook/docbookx.dtd" group="DocBook" name="iso-tech"			/>
  </dir>' >> $out
echo '</dirinfo>' >> $out

