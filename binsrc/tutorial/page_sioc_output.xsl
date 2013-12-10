<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2013 OpenLink Software
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
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns:sioc="http://rdfs.org/sioc/ns#"
  version='1.0'>
<xsl:output method="xml" indent="yes"/>
<!--<xsl:include href="page_common.xsl"/>
<xsl:include href="page_html_common.xsl"/>-->
<xsl:template match="tutorial">
<?vsp
      declare _path,_domain varchar;
      _domain := cfg_item_value (virtuoso_ini_path(), 'URIQA', 'DefaultHost');
      if (_domain is null)
      {
        http_request_status (sprintf ('HTTP/1.1 500 %s', 'SIOC RDF output cannot be constructed without URIQA DefaultHost set. Please contact the site administrator and report the problem.'));
        return;
      }
		  http_header ('Content-Type: text/xml\r\n');
      _path := 'http://' || ltrim(_domain,'/') || '/tutorial/';
?>
<rdf:RDF xmlns="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
		  <xsl:attribute name="rdf" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#"/>
		  <xsl:attribute name="dc" namespace="http://purl.org/dc/elements/1.1/"/>
  <xsl:attribute name="dcterms" namespace="http://purl.org/dc/terms/"/>
  <!--<xsl:attribute name="content" namespace="http://purl.org/rss/1.0/modules/content/"/>-->
                  <xsl:attribute name="foaf" namespace="http://xmlns.com/foaf/0.1/"/>
		  <xsl:attribute name="sioc" namespace="http://rdfs.org/sioc/ns#"/>
<xsl:text disable-output-escaping="yes"><![CDATA[
<sioc:Space rdf:about="<?V _path ?>">]]></xsl:text>
      	<sioc:name>OpenLink Virtuoso Features Demonstrations and Tutorials</sioc:name>
      	<sioc:description>OpenLink Virtuoso Features Demonstrations and Tutorials</sioc:description>
        <xsl:for-each select="//subsection[not(@ref)]">
      	  <xsl:text disable-output-escaping="yes"><![CDATA[
    <sioc:space_of rdf:resource="<?V _path ?>]]></xsl:text>
 <xsl:value-of select="@wwwpath"/>
 <xsl:text disable-output-escaping="yes"><![CDATA["/>]]></xsl:text>
        </xsl:for-each>
      <xsl:text disable-output-escaping="yes"><![CDATA[
</sioc:Space>]]></xsl:text>
<xsl:apply-templates select="//subsection[not(@ref)]"/>
<xsl:apply-templates select="//example"/>
</rdf:RDF>
</xsl:template>

<xsl:template match="subsection">
<xsl:text disable-output-escaping="yes"><![CDATA[
<sioc:Container rdf:about="<?V _path ?>]]></xsl:text>
 <xsl:value-of select="@wwwpath"/>
 <xsl:text disable-output-escaping="yes"><![CDATA[">]]></xsl:text>
    	<sioc:description>
    	  <xsl:value-of select="parent::section/@Title" disable-output-escaping="yes"/>
	      <xsl:text> - </xsl:text>
	      <xsl:value-of select="@Title" disable-output-escaping="yes"/>
    	</sioc:description>
    	<rdf:type>Tutorial</rdf:type>
      	<xsl:text disable-output-escaping="yes"><![CDATA[
  <sioc:has_space rdf:resource="<?V _path ?>"/>]]></xsl:text>
        <xsl:for-each select=".//example">
      	  <xsl:text disable-output-escaping="yes"><![CDATA[
    <sioc:container_of rdf:resource="<?V _path ?>]]></xsl:text>
    <xsl:value-of select="@wwwpath"/>
 <xsl:text disable-output-escaping="yes"><![CDATA["/>]]></xsl:text>
        </xsl:for-each>
      <xsl:text disable-output-escaping="yes"><![CDATA[
</sioc:Container>]]></xsl:text>
</xsl:template>
	
<xsl:template match="example">
<xsl:text disable-output-escaping="yes"><![CDATA[
<foaf:Document rdf:about="<?V _path ?>]]></xsl:text>
 <xsl:value-of select="@wwwpath"/>
 <xsl:text disable-output-escaping="yes"><![CDATA[">]]></xsl:text>
      <xsl:text disable-output-escaping="yes"><![CDATA[
  <sioc:has_container rdf:resource="<?V _path ?>]]></xsl:text>
 <xsl:value-of select="ancestor::subsection/@wwwpath"/>
 <xsl:text disable-output-escaping="yes"><![CDATA["/>]]></xsl:text>
	    <dc:title><xsl:value-of select="refentry/refnamediv/refname"/></dc:title>
  <dcterms:created_at><xsl:value-of select="@date"/></dcterms:created_at>
	    <sioc:description><xsl:value-of select="refentry/refnamediv/refpurpose"/></sioc:description>
      <sioc:content>
        <xsl:for-each select="refentry/refsect1">
          <xsl:apply-templates mode="strip"/>
        </xsl:for-each>
      </sioc:content>
      <content:encoded xmlns:content="http://purl.org/rss/1.0/modules/content/">
        <xsl:text disable-output-escaping="yes">&lt;![CDATA[</xsl:text>
        <xsl:for-each select="refentry/refsect1">
          <xsl:apply-templates />
        </xsl:for-each>
        <xsl:text disable-output-escaping="yes">]]></xsl:text>
      </content:encoded>
      <xsl:text disable-output-escaping="yes"><![CDATA[
</foaf:Document>]]></xsl:text>

</xsl:template>

<xsl:template match="*" priority="20" mode="strip">
    <xsl:apply-templates mode="strip" />
</xsl:template>

</xsl:stylesheet>
