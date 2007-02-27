<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE xsl:stylesheet [
  <!ENTITY ng  "http://www.openlinksw.com/schemas/ning#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:a="http://www.w3.org/2005/Atom"
    xmlns:xn="http://www.ning.com/atom/1.0"
    xmlns:ng="&ng;"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
    version="1.0">

    <xsl:output method="xml" encoding="utf-8" indent="yes"/>
    <xsl:preserve-space elements="*"/>
    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates select="a:feed/a:entry"/>
	</rdf:RDF>
    </xsl:template>
    <xsl:template match="a:entry">
	<xsl:variable name="mypref" select="xn:application/text()"/>
	<xsl:if test="$mypref != '' and (*[starts-with (namespace-uri(), concat ('http://', $mypref))]|xn:*)">
	    <rdf:Description rdf:about="{link[@rel='alternate']/@href}">
		<dc:title><xsl:value-of select="a:title"/></dc:title>
		<xsl:apply-templates select="*[starts-with (namespace-uri(), concat ('http://', $mypref))]|xn:*"/>
	    </rdf:Description>
	</xsl:if>
    </xsl:template>
    <xsl:template match="*">
	<xsl:element name="{local-name(.)}" namespace="&ng;">
	    <xsl:value-of select="."/>
	</xsl:element>
    </xsl:template>
    <xsl:template match="text()" />
</xsl:stylesheet>
