<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:g="http://base.google.com/ns/1.0"
    xmlns:gb="http://www.openlinksw.com/schemas/google-base#"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
    xmlns:batch="http://schemas.google.com/gdata/batch"
    version="1.0">

    <xsl:output method="xml" encoding="utf-8" indent="yes"/>
    <xsl:preserve-space elements="*"/>
    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates/>
	</rdf:RDF>
    </xsl:template>
    <xsl:template match="a:entry[g:*]">
	<rdf:Description rdf:about="{link[@rel='self']/@href}">
	    <dc:title><xsl:value-of select="a:title"/></dc:title>
	    <xsl:apply-templates select="g:*"/>
	</rdf:Description>
    </xsl:template>
    <xsl:template match="g:*">
	<xsl:element name="{local-name(.)}" namespace="http://www.openlinksw.com/schemas/google-base#">
	    <xsl:value-of select="."/>
	</xsl:element>
    </xsl:template>
    <xsl:template match="text()" />
</xsl:stylesheet>
