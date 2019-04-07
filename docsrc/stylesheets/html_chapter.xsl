<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2019 OpenLink Software
 -  
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -  
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -  
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -  
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<!-- ==================================================================== -->

	<xsl:param name="imgroot">/DAV/images/</xsl:param>
	<xsl:param name="chap">overview</xsl:param> 

<!-- ==================================================================== -->

<xsl:include href="html_xt_common.xsl" /> 

<xsl:template match="/book"> 
<xsl:apply-templates /> <!-- select="chapter" / -->
</xsl:template> 

<xsl:template match="chapter[@id = $chap]"> 

<DIV CLASS="abstract">
<H2 CLASS="sect1head">Abstract</H2>
<DIV CLASS="abstracttxt">
   <xsl:apply-templates select="abstract/*" />
</DIV>
</DIV>
<!--  ########## mini Contents bit ######### -->
<xsl:if test=".//sect1">
<H2 CLASS="sect1head">Table of Contents</H2>
	<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
   	<xsl:for-each select="./sect1">
         	<TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
		  <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2"><xsl:attribute name="HREF">#<xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A>
         	    <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
         		<xsl:for-each select="./sect2">
         		<TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/>misc/1x1.gif</xsl:attribute></IMG></TD>
			  <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc3"><xsl:attribute name="HREF">#<xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./title"/></A></TD></TR>
         		</xsl:for-each>
			</TABLE>
			</TD></TR>
		</xsl:for-each>
	 </TABLE>
</xsl:if>

<xsl:if test=".//refentry and @id!='functions'">

<H2 CLASS="sect1head">Reference Entries</H2>
	<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
         	<TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/>misc/1x1.gif</xsl:attribute></IMG></TD>
			<TD WIDTH="95%">
         	<TABLE WIDTH="100%" BORDER="0" CELLPADDING="0" CELLSPACING="0">
         		<TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot"/>misc/1x1.gif</xsl:attribute></IMG></TD>
				<TD>
   	<xsl:for-each select=".//refentry" order-by="+.">
	<A CLASS="toc3"><xsl:attribute name="HREF">#<xsl:value-of select="./@id" /></xsl:attribute><xsl:value-of select="./refmeta/refentrytitle"/></A>
  <xsl:choose>
    <xsl:when test="following-sibling::refentry/title">
      <xsl:text> </xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text> </xsl:text>
    </xsl:otherwise>
  </xsl:choose>
		</xsl:for-each>
		</TD></TR></TABLE></TD></TR>
	 </TABLE>
</xsl:if>
<BR />

<!--  ########## ########### ######### -->

<xsl:choose>
  <xsl:when test="@id='functions'">

<H2 CLASS="sect1head">Table of Contents</H2>
  <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_admin">Administration Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_array">Array Manipulation Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_backup">Backup Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_bif">BIF (Built In) Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_cursors">Cursor Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_dconv">Date Conversion Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_debug">Debug Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_ft">Free Text Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_ldap">LDAP Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_localization">Locale Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_mail">Mail Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_number">Number Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_object">Object Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_repl">Replication Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_rmt">Remote DSN Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_soap">SOAP Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_sql">SQL Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_stream">Stream Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_string">String Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_time">Time Manipulation Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_txn">Transaction Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_type">Type Mapping Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_uddi">UDDI Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_ws">Web Server &amp; Internet Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_xml">XML Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_XPATH">XPATH &amp; XQUERY Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_misc">Miscellaneous Functions</A></TD></TR>
    <TR><TD><IMG ALT="" HEIGHT="10" WIDTH="35"><xsl:attribute name="SRC"><xsl:value-of select="$imgroot" />misc/1x1.gif</xsl:attribute></IMG></TD>
      <TD><xsl:attribute name="NOWRAP">NOWRAP</xsl:attribute><A CLASS="toc2" HREF="#fn_unclassified">Unclassified Functions</A></TD></TR>
  </TABLE>
<BR />

<A NAME="fn_admin" /><H2 CLASS="sect1head">Administration Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='admin']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_array" /><H2 CLASS="sect1head">Array Manipulation Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='array']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_backup" /><H2 CLASS="sect1head">Backup Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='backup']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_bif" /><H2 CLASS="sect1head">BIF (Built In) Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='bif']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_cursors" /><H2 CLASS="sect1head">Cursor Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='cursors']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_dconv" /><H2 CLASS="sect1head">Date Conversion Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='dconv']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_debug" /><H2 CLASS="sect1head">Debug Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='debug']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_ft" /><H2 CLASS="sect1head">Free Text Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='ft']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_ldap" /><H2 CLASS="sect1head">LDAP Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='ldap']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_localization" /><H2 CLASS="sect1head">Locale Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='localization']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_mail" /><H2 CLASS="sect1head">Mail Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='mail']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_number" /><H2 CLASS="sect1head">Number Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='number']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_object" /><H2 CLASS="sect1head">Object Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='object']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_repl" /><H2 CLASS="sect1head">Replication Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='repl']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_rmt" /><H2 CLASS="sect1head">Remote DSN Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='rmt']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_soap" /><H2 CLASS="sect1head">SOAP Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='soap']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_sql" /><H2 CLASS="sect1head">SQL Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='sql']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_stream" /><H2 CLASS="sect1head">Stream Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='stream']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_string" /><H2 CLASS="sect1head">String Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='string']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_time" /><H2 CLASS="sect1head">Time Manipulation Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='time']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_txn" /><H2 CLASS="sect1head">Transaction Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='txn']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_type" /><H2 CLASS="sect1head">Type Mapping Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='type']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_uddi" /><H2 CLASS="sect1head">UDDI Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='uddi']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_ws" /><H2 CLASS="sect1head">Web Server &amp; Internet Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='ws']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_xml" /><H2 CLASS="sect1head">XML Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='xml']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_XPATH" /><H2 CLASS="sect1head">XPATH &amp; XQUERY Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='XPATH']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>
<A NAME="fn_misc" /><H2 CLASS="sect1head">Miscellaneous Functions</H2>
<xsl:for-each select="refentry[refmeta/refmiscinfo='misc']" order-by="+."><xsl:apply-templates select="." /></xsl:for-each>

<!-- <xsl:apply-templates select="refentry" >
<xsl:with-param name="catname">misc</xsl:with-param>
</xsl:apply-templates> -->

<A NAME="fn_unclassified" /><H2 CLASS="sect1head">Unclassified Functions</H2>
   	<xsl:for-each select="refentry[ not(
  refmeta/refmiscinfo = 'admin' 
  or refmeta/refmiscinfo = 'array'
  or refmeta/refmiscinfo = 'backup'
  or refmeta/refmiscinfo = 'bif'
  or refmeta/refmiscinfo = 'cursors'
  or refmeta/refmiscinfo = 'dconv'
  or refmeta/refmiscinfo = 'debug'
  or refmeta/refmiscinfo = 'ft'
  or refmeta/refmiscinfo = 'ldap'
  or refmeta/refmiscinfo = 'localization'
  or refmeta/refmiscinfo = 'mail'
  or refmeta/refmiscinfo = 'misc'
  or refmeta/refmiscinfo = 'number'
  or refmeta/refmiscinfo = 'object'
  or refmeta/refmiscinfo = 'repl'
  or refmeta/refmiscinfo = 'rmt'
  or refmeta/refmiscinfo = 'soap'
  or refmeta/refmiscinfo = 'sql'
  or refmeta/refmiscinfo = 'stream'
  or refmeta/refmiscinfo = 'string'
  or refmeta/refmiscinfo = 'time'
  or refmeta/refmiscinfo = 'txn'
  or refmeta/refmiscinfo = 'type'
  or refmeta/refmiscinfo = 'uddi'
  or refmeta/refmiscinfo = 'ws'
  or refmeta/refmiscinfo = 'xml'
  or refmeta/refmiscinfo = 'XPATH')]" order-by="+.">
<xsl:apply-templates select="." />
</xsl:for-each>

<!-- 
<xsl:apply-templates select="refentry[ not(
  refmeta/refmiscinfo = 'admin' 
  or refmeta/refmiscinfo = 'array'
  or refmeta/refmiscinfo = 'backup'
  or refmeta/refmiscinfo = 'bif'
  or refmeta/refmiscinfo = 'cursors'
  or refmeta/refmiscinfo = 'dconv'
  or refmeta/refmiscinfo = 'debug'
  or refmeta/refmiscinfo = 'ft'
  or refmeta/refmiscinfo = 'ldap'
  or refmeta/refmiscinfo = 'localization'
  or refmeta/refmiscinfo = 'mail'
  or refmeta/refmiscinfo = 'misc'
  or refmeta/refmiscinfo = 'number'
  or refmeta/refmiscinfo = 'object'
  or refmeta/refmiscinfo = 'repl'
  or refmeta/refmiscinfo = 'rmt'
  or refmeta/refmiscinfo = 'soap'
  or refmeta/refmiscinfo = 'sql'
  or refmeta/refmiscinfo = 'stream'
  or refmeta/refmiscinfo = 'string'
  or refmeta/refmiscinfo = 'time'
  or refmeta/refmiscinfo = 'txn'
  or refmeta/refmiscinfo = 'type'
  or refmeta/refmiscinfo = 'uddi'
  or refmeta/refmiscinfo = 'ws'
  or refmeta/refmiscinfo = 'xml')]" />
-->
  </xsl:when>
  
  <xsl:otherwise>
    <xsl:apply-templates />
  </xsl:otherwise>
</xsl:choose>
</xsl:template>

</xsl:stylesheet>
