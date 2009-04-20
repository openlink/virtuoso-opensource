<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2009 OpenLink Software
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
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY xsi "http://www.w3.org/2001/XMLSchema-instance">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY dcmitype "http://purl.org/dc/dcmitype/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#/">
<!ENTITY cp "http://schemas.openxmlformats.org/package/2006/metadata/core-properties">
<!ENTITY ep "http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
<!ENTITY vt "http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
<!ENTITY a "http://schemas.openxmlformats.org/drawingml/2006/main">
<!ENTITY p "http://schemas.openxmlformats.org/presentationml/2006/main">
<!ENTITY r "http://schemas.openxmlformats.org/package/2006/relationships">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:xsd="&xsd;"
    xmlns:xsi="&xsi;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:dcmitype="&dcmitype;"
    xmlns:bibo="&bibo;"
    xmlns:foaf="&foaf;"
    xmlns:sioc="&sioc;"
    xmlns:cp="&cp;"
    xmlns:ep="&ep;"
    xmlns:vt="&vt;"
    xmlns:a="&a;"
    xmlns:p="&p;"
    xmlns:r="&r;"
    >

  <xsl:output method="xml" indent="yes" />

  <xsl:param name="baseUri" />
  <xsl:param name="urihost" />
  <xsl:param name="fileExt" />
  <xsl:param name="slideDir" />
  <xsl:param name="mode" />
  <xsl:param name="slideNum" />
  <xsl:param name="imageDavPath" />
  <xsl:param name="sourceDoc" />

  <xsl:variable name="documentResourceURL">
    <xsl:value-of select="$baseUri"/>
  </xsl:variable>

  <xsl:variable name="sourceDoc">
    <xsl:value-of select="$sourceDoc"/>
  </xsl:variable>

  <xsl:variable name="entityURL">
    <xsl:value-of select="substring-before($baseUri, $fileExt)"/>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:choose>
      <xsl:when test="contains($mode, 'get_slide_content')">
        <xsl:apply-templates mode="get_slide_content" />
      </xsl:when>
      <xsl:when test="contains($mode, 'get_slide_list')">
        <xsl:apply-templates mode="get_slide_list" />
      </xsl:when>
      <xsl:when test="contains($mode, 'get_image_descs')">
        <xsl:apply-templates mode="get_image_descs" />
      </xsl:when>
      <xsl:when test="contains($mode, 'get_image_file_list')">
        <xsl:apply-templates mode="get_image_file_list" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Template for parsing <file name>.pptx/docProps/core.xml -->
  <xsl:template match="cp:coreProperties">
    <rdf:RDF>
      <!-- Describe a container document which points to the presentation resource -->
      <!-- Container document URI = URI of .pptx file *minus* the file suffix
      <rdf:Description rdf:about="{$entityURL}">
	<rdf:type>bibo:Slideshow</rdf:type>
      -->
	<!-- Alternatively
	<rdf:type>bibo:Document</rdf:type>
	<rdf:type>foaf:Document</rdf:type>
	<rdf:type>sioc:Container</rdf:type>
	<dc:type>Presentation</dc:type>
	-->
      <!--
	<foaf:primaryTopic><xsl:value-of select="$documentResourceURL"/></foaf:primaryTopic>
	<dcterms:hasFormat rdf:resource="{$documentResourceURL}"/>
      </rdf:Description>
      -->

      <!-- The PPTX representation of the presentation i.e. .pptx file URI *including* file suffix -->
      <rdf:Description rdf:about="{$documentResourceURL}">
	<rdf:type>bibo:Slideshow</rdf:type>
	<dcterms:format>application/vnd.openxmlformats-officedocument.presentationml.presentation</dcterms:format>
	<dc:source><xsl:value-of select="$sourceDoc"/></dc:source>
        <rdfs:label><xsl:value-of select="dc:title"/></rdfs:label>
        <xsl:copy-of select="dc:title"/>
        <xsl:copy-of select="dc:subject"/>
        <xsl:copy-of select="dc:description"/>
        <xsl:copy-of select="dc:creator"/>
        <dcterms:created><xsl:value-of select="dcterms:created"/></dcterms:created>
        <dcterms:modified><xsl:value-of select="dcterms:modified"/></dcterms:modified>
	<!-- Container doc link
	<dcterms:isFormatOf rdf:resource="{$entityURL}"/>
	-->
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>

  <!-- Template for parsing <file name>.pptx/docProps/app.xml -->
  <xsl:template match="ep:Properties">
    <rdf:RDF>
      <rdf:Description rdf:about="{$documentResourceURL}">
        <xsl:copy-of select="ep:Slides"/>
        <xsl:apply-templates select="ep:TitlesOfParts" />
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>

  <!-- Get the title of each slide -->
  <xsl:template match="ep:TitlesOfParts/vt:vector">
    <xsl:for-each select="vt:lpstr">
      <xsl:choose>
	<!-- Skip slides which describe the presentation layout/theme/template -->
        <xsl:when test="position() <= (number(../@size) - number(/ep:Properties/ep:Slides))">
        </xsl:when>

        <xsl:otherwise>
	  <dcterms:hasPart>
	    <bibo:Slide>
	      <xsl:attribute name="rdf:about">
	        <xsl:value-of select="concat($documentResourceURL, '/slide', string(position() + number(/ep:Properties/ep:Slides) - number(../@size)))"/>
	      </xsl:attribute>
	      <dcterms:isPartOf rdf:resource="{$documentResourceURL}"/>
              <dc:title><xsl:value-of select="."/></dc:title>
              <rdfs:label><xsl:value-of select="."/></rdfs:label>
	    </bibo:Slide>
	  </dcterms:hasPart>
        </xsl:otherwise>

      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!-- Template for parsing <file name>.pptx/ppt/slides/slide[:digit:]+ -->
  <!-- Extract slide text -->
  <xsl:template match="p:sld">
    <slide_text>
    <xsl:for-each select=".//a:t">
      <xsl:value-of select="normalize-space()"/><xsl:text> </xsl:text>
    </xsl:for-each>
    </slide_text>
  </xsl:template>

  <!-- Template for parsing <file name>.pptx/ppt/_rels/presentation.xml.rels -->
  <!-- Get a colon-separated list of slides contained in slides folder, slides/slide1.xml:slides/slide2.xml:... -->
  <xsl:template match="r:Relationships" mode="get_slide_list">
    <xsl:for-each select="r:Relationship[@Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide']/@Target">
      <xsl:value-of select="concat(':', .)"/>
    </xsl:for-each>
  </xsl:template>

  <!-- Templates for parsing <file name>.pptx/ppt/slides/_rels/slide[:digit:]+.xml.rels -->
  <!-- Get descriptions of any images embedded in the slide -->
  <xsl:template match="r:Relationships" mode="get_image_descs">
    <xsl:for-each select="r:Relationship[@Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/image']/@Target">
      <bibo:Slide>
        <xsl:attribute name="rdf:about">
          <xsl:value-of select="concat($documentResourceURL, '/slide', $slideNum)"/>
        </xsl:attribute>
        <foaf:depiction><xsl:value-of select="concat('http://', $urihost, $imageDavPath, substring-after(., 'media/'))"/></foaf:depiction>
      </bibo:Slide>
    </xsl:for-each>
  </xsl:template>
  <!-- Get a colon-separated list of any images embedded in the slide -->
  <xsl:template match="r:Relationships" mode="get_image_file_list">
    <xsl:for-each select="r:Relationship[@Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/image']/@Target">
      <xsl:value-of select="concat(':', .)"/>
    </xsl:for-each>
  </xsl:template>

  <!-- Get the text content of each slide (which could be used as the basis for a free-text search) -->
  <!-- Used for testing with Xalan. Not used with Virtuoso Sponger
  <xsl:template match="r:Relationships" mode="get_slide_content">
    <rdf:RDF>
      <rdf:Description rdf:about="{$documentResourceURL}">
        <rdf:value>
          <xsl:for-each select="r:Relationship[@Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide']/@Target">
            <xsl:apply-templates select="document(concat($slideDir, '/', .))"/>
          </xsl:for-each>
        </rdf:value>
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>
  -->

  <xsl:template match="text()|@*"/>

</xsl:stylesheet>
