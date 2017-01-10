<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2017 OpenLink Software
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
<!-- ==================================================================== -->

<!-- Parameters -->

	<xsl:param name="docroot">.</xsl:param>
	<xsl:param name="imgroot"><xsl:value-of select="$docroot"/>/../images/</xsl:param>
	<xsl:param name="chap">overview</xsl:param>
	<xsl:param name="renditionmode">multi_chapter</xsl:param>
	<xsl:param name="page_ext">.html</xsl:param>
	<xsl:param name="foo">bar</xsl:param>

<!-- Configuration variables -->

<!-- Chapter files mapping -->

	<xsl:variable name="accint_file">accessinterfaces</xsl:variable>
	<xsl:variable name="admui_file">adminui</xsl:variable>
	<xsl:variable name="appa_file">appendixa</xsl:variable>
	<xsl:variable name="bak_file">backup</xsl:variable>
	<xsl:variable name="cint_file">cinterface</xsl:variable>
	<xsl:variable name="conc_file">concepts</xsl:variable>
	<xsl:variable name="dbconc_file">dbconcepts</xsl:variable>
	<xsl:variable name="err_file">errors</xsl:variable>
	<xsl:variable name="fn_file">functions</xsl:variable>
	<xsl:variable name="ft_file">freetext</xsl:variable>
	<xsl:variable name="hooks_file">hooks</xsl:variable>
	<xsl:variable name="inst_file">installation</xsl:variable>
	<xsl:variable name="intl_file">intl</xsl:variable>
	<xsl:variable name="isql_file">isql</xsl:variable>
	<xsl:variable name="ldap_file">ldap</xsl:variable>
	<xsl:variable name="mailsrv_file">mailsrv</xsl:variable>
	<xsl:variable name="mime_file">mime</xsl:variable>
	<xsl:variable name="odbc_file">odbc</xsl:variable>
	<xsl:variable name="ov_file">overview</xsl:variable>
	<xsl:variable name="ptune_file">ptune</xsl:variable>
	<xsl:variable name="qt_file">quicktours</xsl:variable>
	<xsl:variable name="reln21_file">relnotes_21</xsl:variable>
	<xsl:variable name="reln25_file">relnotes_25</xsl:variable>
	<xsl:variable name="repl_file">repl</xsl:variable>
	<xsl:variable name="sapp_file">sampleapps</xsl:variable>
	<xsl:variable name="srv_file">server</xsl:variable>
	<xsl:variable name="sqlfun_file">sqlfunctions</xsl:variable>
	<xsl:variable name="sqlproc_file">sqlprocedures</xsl:variable>
	<xsl:variable name="sqlref_file">sqlreference</xsl:variable>
	<xsl:variable name="supp_file">support</xsl:variable>
	<xsl:variable name="tpcc_file">tpcc</xsl:variable>
	<xsl:variable name="uddi_file">uddi</xsl:variable>
	<xsl:variable name="vdbconc_file">vdbconcepts</xsl:variable>
	<xsl:variable name="wpap_file">virtwhitepaper</xsl:variable>
	<xsl:variable name="vsp_file">vsp</xsl:variable>
	<xsl:variable name="vsptrain_file">vsptraining</xsl:variable>
	<xsl:variable name="wxml_file">webandxml</xsl:variable>
	<xsl:variable name="wsrv_file">wsrv</xsl:variable>
	<xsl:variable name="wsvcs_file">webservices</xsl:variable>
	<xsl:variable name="yacc_file">yacsqlgrammar</xsl:variable>

<!-- Doc tree location -->

        <xsl:variable name="fnroot">
          <xsl:value-of select="$docroot"/>funcref/
	</xsl:variable>

<!-- HTML heading generation controls -->

	<xsl:variable name="topelemoffset">
	  <xsl:choose>
	    <xsl:when test="$renditionmode != 'single_page'">1</xsl:when>
	    <xsl:otherwise>0</xsl:otherwise>
	  </xsl:choose>
	</xsl:variable>

<!-- ==================================================================== -->
</xsl:stylesheet>
