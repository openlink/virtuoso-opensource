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
<!ENTITY zem "http://s.zemanta.com/ns#">
]>
<xsl:stylesheet
    xmlns:xsl  ="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc   ="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms = "http://purl.org/dc/terms/"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:foaf="&foaf;"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:rdf  ="&rdf;"
    xmlns:zem  ="&zem;"
    >


    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />
    <xsl:param name="min-score" />
    <xsl:param name="max-results" />
    <xsl:variable name="target">http://s.zemanta.com/ns#</xsl:variable>

    <xsl:template match="rdf:RDF">
	<xsl:copy>
	    <rdf:Description rdf:about="{$baseUri}">
		<xsl:for-each select="rdf:Description[rdf:type[starts-with (@rdf:resource, $target)]
		    and number (zem:confidence) > $min-score]">
		    <xsl:sort select="zem:confidence" data-type="number" order="descending"/>
		    <!--xsl:message terminate="no"><xsl:value-of select="zem:confidence"/></xsl:message>
		    <xsl:message terminate="no"><xsl:value-of select="position()"/></xsl:message-->
		    <xsl:if test="position () <= $max-results">
		    <xsl:variable name="frag">
			<xsl:call-template name="substring-after-last">
			    <xsl:with-param name="string" select="@rdf:about"/>
			    <xsl:with-param name="character" select="'#'"/>
			</xsl:call-template>
		    </xsl:variable>
		    <xsl:variable name="res">
			<xsl:value-of select="concat($baseUri,'#', $frag)"/>
		    </xsl:variable>
		    <rdfs:seeAlso rdf:resource="{$res}"/>
		    </xsl:if>
		</xsl:for-each>
	    </rdf:Description>
	    <xsl:for-each select="rdf:Description[rdf:type[starts-with (@rdf:resource, $target)] and number (zem:confidence) > $min-score]">
		<xsl:sort select="zem:confidence" data-type="number" order="descending"/>
		<!--xsl:message terminate="no"><xsl:value-of select="zem:confidence"/></xsl:message>
		<xsl:message terminate="no"><xsl:value-of select="position()"/></xsl:message-->
		<xsl:if test="position () <= $max-results">
	<rdf:Description>
	    <opl:providedBy>
		<foaf:Organization rdf:about="http://www.crunchbase.com/company/zemanta">
		    <foaf:name>Zemanta</foaf:name>
		    <foaf:homepage rdf:resource="http://www.zemanta.com/"/>
		</foaf:Organization>
	    </opl:providedBy>
	    <xsl:attribute name="rdf:about">
		<xsl:variable name="frag">
		    <xsl:call-template name="substring-after-last">
			<xsl:with-param name="string" select="@rdf:about"/>
			<xsl:with-param name="character" select="'#'"/>
		    </xsl:call-template>
		</xsl:variable>
		<xsl:value-of select="concat($baseUri,'#', $frag)"/>
	    </xsl:attribute>
	    <xsl:apply-templates mode="cp"/>
	</rdf:Description>
		</xsl:if>
	    </xsl:for-each>
	</xsl:copy>
    </xsl:template>

    <xsl:template match="rdf:type" mode="cp">
	<xsl:copy-of select="."/>
    </xsl:template>

    <xsl:template match="zem:text" mode="cp"/>

    <xsl:template match="*" mode="cp">
	<xsl:copy>
	    <xsl:copy-of select="@*[local-name () != 'resource']"/>
	    <xsl:choose>
		<xsl:when test="@rdf:resource[starts-with (., $target)]">
		    <xsl:attribute name="rdf:resource">
			<xsl:variable name="frag">
			    <xsl:call-template name="substring-after-last">
				<xsl:with-param name="string" select="@rdf:resource"/>
				<xsl:with-param name="character" select="'#'"/>
			    </xsl:call-template>
			</xsl:variable>
			<xsl:value-of select="concat($baseUri, '#', $frag)"/>
		    </xsl:attribute>
		</xsl:when>
		<xsl:otherwise>
		    <xsl:copy-of select="@rdf:resource"/>
		</xsl:otherwise>
	    </xsl:choose>
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
