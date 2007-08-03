<?xml version="1.0"?>
<xsl:stylesheet
    xmlns:xsl  ="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:foaf ="http://xmlns.com/foaf/0.1/"
    xmlns:h    ="http://www.w3.org/1999/xhtml"
    xmlns:rdf  ="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    >
    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />

    <xsl:template match="html">
	<rdf:RDF>
	    <xsl:apply-templates select="*[@class='xfolkentry']"/>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="*[@class='xfolkentry']">
	<rdf:Description>
	    <xsl:apply-templates select=".//a[@class='taggedlink']|.//*[@class='meta']|.//*[@class='description']"/>
	</rdf:Description>
    </xsl:template>

    <xsl:template match="a[@class='taggedlink']">
	<xsl:attribute name="about" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><xsl:value-of select="resolve-uri($baseUri, @href)"/></xsl:attribute>
	<dc:title><xsl:value-of select="."/></dc:title>
    </xsl:template>

    <xsl:template match="a[@rel='tag']">
	<dc:subject>
	    <skos:Concept rdf:about="{resolve-uri ($baseUri, @href)}">
		<skos:prefLabel><xsl:value-of select="."/></skos:prefLabel>
	    </skos:Concept>
	</dc:subject>
    </xsl:template>

    <xsl:template match="*[@class='meta']">
	<xsl:apply-templates select=".//a[@rel='tag']"/>
    </xsl:template>

    <xsl:template match="*[@class='description']">
	<dc:description><xsl:value-of select="."/></dc:description>
    </xsl:template>

    <xsl:template match="text()"/>

</xsl:stylesheet>
