<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2008 OpenLink Software
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
-->
<!DOCTYPE xsl:stylesheet [
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
]>
<xsl:stylesheet
    xmlns:xsl  ="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc   ="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms = "http://purl.org/dc/terms/"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:foaf="&foaf;"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:rdf  ="&rdf;">


    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />

    <xsl:template match="rdf:RDF">
	<xsl:copy>
	    <rdf:Description rdf:about="{$baseUri}">
		<rdf:type rdf:resource="&foaf;Document"/>
		<rdf:type rdf:resource="&bibo;Document"/>
		<rdf:type rdf:resource="&sioc;Container"/>
		<xsl:for-each select="rdf:Description[rdf:type[starts-with (@rdf:resource, 'http://s.opencalais.com/1/type/em/')]]">
		    <xsl:variable name="frag">
			<xsl:call-template name="substring-after-last">
			    <xsl:with-param name="string" select="@rdf:about"/>
			    <xsl:with-param name="character" select="'/'"/>
			</xsl:call-template>
		    </xsl:variable>
		    <xsl:variable name="res">
			<xsl:value-of select="vi:proxyIRI($baseUri,'', $frag)"/>
		    </xsl:variable>
		    <sioc:container_of rdf:resource="{$res}"/>
		    <foaf:topic rdf:resource="{$res}"/>
		    <dcterms:subject rdf:resource="{$res}"/>
		</xsl:for-each>
	    </rdf:Description>
	    <xsl:apply-templates />
	</xsl:copy>
    </xsl:template>

    <xsl:template match="rdf:Description[rdf:type[starts-with (@rdf:resource, 'http://s.opencalais.com/1/type/em/')]]">
	<rdf:Description>
	    <sioc:has_container rdf:resource="{$baseUri}"/>
	    <opl:data_source>
		<opl:DataSource rdf:about="{@rdf:about}"/>
	    </opl:data_source>
	    <opl:provided_by>
		<foaf:Organization rdf:about="http://dbpedia.org/resource/Reuters">
		    <foaf:name>OpenCalais</foaf:name>
		    <foaf:homepage rdf:resource="http://www.opencalais.com/"/>
		</foaf:Organization>
	    </opl:provided_by>
	    <xsl:attribute name="rdf:about">
		<xsl:variable name="frag">
		    <xsl:call-template name="substring-after-last">
			<xsl:with-param name="string" select="@rdf:about"/>
			<xsl:with-param name="character" select="'/'"/>
		    </xsl:call-template>
		</xsl:variable>
		<xsl:value-of select="vi:proxyIRI($baseUri,'', $frag)"/>
	    </xsl:attribute>
	    <!--xsl:copy-of select="*"/-->
	    <xsl:apply-templates mode="cp"/>
	</rdf:Description>
    </xsl:template>

    <xsl:template match="rdf:type" mode="cp">
	<xsl:copy-of select="."/>
    </xsl:template>

    <xsl:template match="*" mode="cp">
	<xsl:copy>
	    <xsl:copy-of select="@*[local-name () != 'resource']"/>
	    <xsl:if test="@rdf:resource">
		<xsl:attribute name="rdf:resource">
		    <xsl:variable name="frag">
			<xsl:call-template name="substring-after-last">
			    <xsl:with-param name="string" select="@rdf:resource"/>
			    <xsl:with-param name="character" select="'/'"/>
			</xsl:call-template>
		    </xsl:variable>
		    <xsl:value-of select="vi:proxyIRI($baseUri, '', $frag)"/>
		</xsl:attribute>
	    </xsl:if>
	    <xsl:apply-templates mode="cp"/>
	</xsl:copy>
    </xsl:template>

  <xsl:template name="substring-after-last">
    <xsl:param name="string"/>
    <xsl:param name="character"/>
    <xsl:choose>
      <xsl:when test="contains($string,$character)">
          <xsl:call-template name="substring-after-last">
            <xsl:with-param name="string" select="substring-after($string, $character)"/>
            <xsl:with-param name="character" select="$character"/>
          </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$string"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

    <xsl:template match="*|text()"/>

</xsl:stylesheet>
