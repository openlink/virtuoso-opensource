<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY nyt "http://www.nytimes.com/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:dcterms = "http://purl.org/dc/terms/"
	xmlns:scot="http://scot-project.org/scot/ns#"    
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:moat="http://moat-project.org/ns#"
    xmlns:sioc="&sioc;"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:dc="&dc;"
    xmlns:nyt="&nyt;"
    >
    
    <xsl:param name="baseUri" />

    <xsl:output method="xml" indent="yes" />
    
    <xsl:template match="/">
		<rdf:Description rdf:about="{$baseUri}">
			<scot:hasSCOT rdf:resource="{concat($baseUri, '#tagcloud')}"/>
			<xsl:for-each select="tag">
				<sioc:topic>
					<skos:Concept rdf:about="{concat('http://www.nytimes.com/tag#', .)}">
						<skos:prefLabel>
							<xsl:value-of select="."/>
						</skos:prefLabel>
					</skos:Concept>
				</sioc:topic>
			</xsl:for-each>
		</rdf:Description>
		<scot:Tagcloud rdf:about="{concat($baseUri, '#tagcloud')}">
			<xsl:for-each select="tag">
				<scot:hasTag rdf:resource="{concat('http://www.nytimes.com/tag#', .)}"/>
			</xsl:for-each>
		</scot:Tagcloud>
		<xsl:for-each select="tag">
			<scot:Tag rdf:about="{concat('http://www.nytimes.com/tag#', .)}">
				<scot:name>
					<xsl:value-of select="."/>
				</scot:name>
			</scot:Tag>
			<moat:Tag rdf:about="{concat('http://www.nytimes.com/tag#', .)}">
				<moat:name>
					<xsl:value-of select="."/>
				</moat:name>
			</moat:Tag>
		</xsl:for-each>
	</xsl:template>
    
    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
