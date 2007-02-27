<xsl:stylesheet
    xmlns:xsl  ="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:h    ="http://www.w3.org/1999/xhtml"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:rdf  ="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:dt   ="http://www.w3.org/2001/XMLSchema#"
    >
    <xsl:output method="xml" indent="yes"/>
    <xsl:template match="h:html">
	<rdf:RDF>
	    <xsl:if test="h:head/h:meta[@name = 'ICBM'] or h:head/h:meta[@name = 'DC.title']">
		<xsl:for-each select="h:head">
		    <rdf:Description rdf:about="">
			<xsl:for-each select="h:meta[@name = 'ICBM']">
			    <xsl:variable name="lat" select='substring-before(@content, ",")'/>
			    <xsl:variable name="lon" select='substring-after(@content, ",")'/>
			    <foaf:topic rdf:parseType="Resource">
				<geo:lat><xsl:value-of select='$lat'/></geo:lat>
				<geo:long><xsl:value-of select='$lon'/></geo:long>
			    </foaf:topic>
			</xsl:for-each>
			<xsl:for-each select="h:meta[@name = 'DC.title']">
			    <dc:title><xsl:value-of select='@content'/></dc:title>
			</xsl:for-each>
		    </rdf:Description>
		</xsl:for-each>
	    </xsl:if>
	</rdf:RDF>
    </xsl:template>
    <xsl:template match="text()|@*" />
</xsl:stylesheet>
