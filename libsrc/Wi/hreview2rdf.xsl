<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
xmlns:dc="http://purl.org/dc/elements/1.1/"
xmlns:rss="http://purl.org/rss/1.0/"
xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
xmlns:foaf="http://xmlns.com/foaf/0.1/"
xmlns:skos="http://www.w3.org/2004/02/skos/core#"
xmlns:admin="http://webns.net/mvcb/"
xmlns:xhtml="http://www.w3.org/1999/xhtml"
xmlns:owl="http://www.w3.org/2002/07/owl#"
xmlns:review="http:/www.purl.org/stuff/rev#"
xmlns:hrev="http:/www.purl.org/stuff/hrev#"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
version="1.0">

<xsl:output indent="yes" omit-xml-declaration="yes" method="xml"/>

<xsl:template match="/xhtml:html/xhtml:body">
  <rdf:RDF>
	<xsl:apply-templates />
  </rdf:RDF>
</xsl:template>


<xsl:template match="//*[@class='hreview']">
  <review:Review>
	<xsl:apply-templates mode="hreview"/>
  </review:Review>
</xsl:template>

<xsl:template match="*" mode="hreview">
  <xsl:variable name="class" select="@class" />
  <xsl:variable name="field">
	<xsl:choose>
	  <xsl:when test="substring($class, string-length($class)-1)= 'fn' and substring($class, 1, string-length($class)-3) != ''">
		<xsl:value-of select="substring($class, 1, string-length($class)-3)" />
	  </xsl:when>

	  <xsl:when test="substring($class, 1, 3)='fn' and substring($class, 3, string-length($class)+1) != ''">
		<xsl:value-of select="substring($class, 3, string-length($class)+1)" />
	    </xsl:when>

	  <xsl:when test="$class='reviewbody description'">
		<xsl:value-of select="'description'" />
	  </xsl:when>

	  <xsl:otherwise>
		<xsl:value-of select="$class" />
	  </xsl:otherwise>
	</xsl:choose>
  </xsl:variable>

  <!--
  Class: "<xsl:value-of select="$class" />"
  Field: "<xsl:value-of select="$field" />"
  -->
<xsl:choose>
  <xsl:when test="$field='reviewer'">
	<review:reviewer>
	  <foaf:Person>
		<foaf:name><xsl:value-of select="../*"/></foaf:name>
	  </foaf:Person>
	</review:reviewer>
  </xsl:when>
  <xsl:when test="$field='reviewer vcard'">
	<review:reviewer>
	  <foaf:Person>
		<foaf:name><xsl:value-of select="@title"/></foaf:name>
	  </foaf:Person>
	</review:reviewer>
  </xsl:when>
  <xsl:when test="$field='description'">
	<dc:description><xsl:value-of select="." /></dc:description>
  </xsl:when>
  <xsl:when test="$field='rating'">
	<review:rating><xsl:value-of select="../*" /></review:rating>
  </xsl:when>
  <xsl:when test="$field='summary'">
	<dc:title><xsl:value-of select="." /></dc:title>
  </xsl:when>
  <xsl:when test="$field='dtreview'">
	<dc:date><xsl:value-of select="../*" /></dc:date>
  </xsl:when>
  <xsl:when test="$field='dtreviewed'">
	<dc:date><xsl:value-of select="@title" /></dc:date>
  </xsl:when>
</xsl:choose>

<xsl:apply-templates mode="hreview" />

</xsl:template>

<xsl:template match="text()" mode="hreview" />
<xsl:template match="text()" />

</xsl:stylesheet>
