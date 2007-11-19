<?xml version="1.0"?>
<xsl:stylesheet
    xmlns:xsl  ="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:foaf ="http://xmlns.com/foaf/0.1/"
    xmlns:rdf  ="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:oai="http://www.openarchives.org/OAI/2.0/"
    xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
    >
    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="baseUri" />

    <xsl:template match="/">
	<rdf:RDF>
	    <rdf:Description rdf:about="{$baseUri}">
		<xsl:apply-templates select="oai:OAI-PMH/oai:GetRecord/oai:record/oai:metadata/oai_dc:dc/*"/>
	    </rdf:Description>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="dc:*">
	<xsl:copy-of select="."/>
    </xsl:template>

</xsl:stylesheet>
