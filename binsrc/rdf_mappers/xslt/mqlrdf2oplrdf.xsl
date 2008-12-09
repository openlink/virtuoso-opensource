<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY sc "http://umbel.org/umbel/sc/">
<!ENTITY fb "http://rdf.freebase.com/ns/">
]>

<xsl:stylesheet version="1.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dcterms= "http://purl.org/dc/terms/"
    xmlns:umbel="&sc;"
    xmlns:fb="&fb;"
    xmlns:mql="http://www.freebase.com/">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:param name="wpUri" />

    <xsl:variable name="ns">http://www.freebase.com/</xsl:variable>

  <xsl:template match="/">
    <xsl:apply-templates select="*"/>
  </xsl:template>

    <xsl:template match="*">
      <xsl:copy>
        <xsl:for-each select="@*">
	  <xsl:copy/>
        </xsl:for-each>
        <xsl:apply-templates/>
      </xsl:copy>
      <xsl:if test="local-name () = 'location.country.iso3166_1_shortname'">
        <dcterms:identifier><xsl:value-of select="."/></dcterms:identifier>
        <rdf:type rdf:resource="&sc;Country"/>
      </xsl:if>
    </xsl:template>

</xsl:stylesheet>
