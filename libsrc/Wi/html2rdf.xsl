<?xml version="1.0"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  version="1.0">
  <xsl:param name="base" />
  <xsl:template match="/">
      <xsl:apply-templates select="html/head"/>
  </xsl:template>
  <xsl:template match="html/head">
      <rdf:RDF>
	  <foaf:Document rdf:about="{$base}">
	      <xsl:apply-templates select="title|meta"/>
	  </foaf:Document>
      </rdf:RDF>
  </xsl:template>
  <xsl:template match="title">
      <dc:title>
	  <xsl:value-of select="."/>
      </dc:title>
  </xsl:template>
  <xsl:template match="meta[@name='description']">
      <dc:description>
	  <xsl:value-of select="@content"/>
      </dc:description>
  </xsl:template>
  <xsl:template match="meta[@name='copyrights']">
      <dc:rights>
	  <xsl:value-of select="@content"/>
      </dc:rights>
  </xsl:template>
  <xsl:template match="meta[@name='keywords']">
      <dc:subject>
	  <xsl:value-of select="@content"/>
      </dc:subject>
  </xsl:template>
  <xsl:template match="*|text()"/>
</xsl:stylesheet>
