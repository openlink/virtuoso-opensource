<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://purl.org/ontology/mo/"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:xhtml="http://www.w3.org/1999/xhtml"
	xmlns:dc="http://purl.org/dc/terms/"
	xmlns:foaf="http://xmlns.com/foaf/0.1/"
	xmlns:time="http://www.w3.org/2006/time#"
	xmlns:tl="http://purl.org/NET/c4dm/timeline.owl#"
	xmlns:dcterms="&dcterms;"
	xmlns:opl="&opl;"
	exclude-result-prefixes="xhtml"
  version="1.0">

<!-- Id: Mo-hAudio.xsl,$Version 0.3 *stable* updated Monday, December 29 2008 13:12 +0000 By Martin McEvoy contributions by Yves Raimond http://dbtune.org/, Extract Music Ontology from hAudio Microformat, GRDDL Link http://purl.org/weborganics/mo-haudio -->

<xsl:strip-space elements="*"/>

<xsl:output method="xml"
		   indent="yes"
		   encoding="UTF-8"
		   media-type="application/xml"/>

<!-- recomended for all GRDDL-able documents use <base href="http://yourdocument.url/" /> in the <head> of your xhtml page -->
<xsl:param name="self" select="*[name() = 'base']"/>

<xsl:param name="base-uri">
<xsl:choose>
     	<xsl:when test="$self">
		<xsl:value-of select="$self/attribute::href" />
	</xsl:when>
    	<xsl:otherwise>
		<!-- else set by processor -->
		<xsl:value-of select="''" />
    	</xsl:otherwise>
</xsl:choose>
</xsl:param>

<!-- see if there are any hAudio's with items -->
<xsl:param name="start" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' haudio ') and descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' item ')]]"/>


<!-- index attribute::class="title"/a/attribute::href -->
<xsl:param name="index">
<xsl:choose>
     	<xsl:when test="$start">
		<xsl:value-of select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' fn ')]/xhtml:a/attribute::href" />
	</xsl:when>
    	<xsl:otherwise>
		<xsl:value-of select="$base-uri" />
    	</xsl:otherwise>
</xsl:choose>
</xsl:param>

<!-- see if we have items -->
<xsl:param name="items" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' item ') and descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' fn ')]]"/>

<xsl:param name="audio" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' haudio ') and descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' fn ')]]"/>


<xsl:template match="/">
  <rdf:RDF>
    <xsl:apply-templates/>
  </rdf:RDF>
</xsl:template>

<!-- ==============================================Temaplates===============================================-->

<xsl:template match="xhtml:html">
<xsl:for-each select="$audio">
	<xsl:call-template name="artist"/>
	<xsl:call-template name="recording"/>
	<xsl:choose>
     		<xsl:when test="$items">
			<xsl:call-template name="item"/>
		</xsl:when>
    		<xsl:otherwise>
   			<xsl:call-template name="haudio"/>
    		</xsl:otherwise>
	</xsl:choose>
</xsl:for-each>
</xsl:template>

<!-- attribute::class="haudio" => mo:Record -->
<xsl:template name="recording">
<xsl:param name="item" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' item ')]"/>
<xsl:element name='Record'>
  	<xsl:attribute name='rdf:nodeID'>
      <xsl:value-of select="generate-id()"/>
    </xsl:attribute>
   	<xsl:call-template name="recordtitle"/>
   	<xsl:call-template name="type"/>
    <xsl:call-template name="artistLink"/>
    <xsl:call-template name="image"/>
    <xsl:call-template name="published"/>
    <xsl:call-template name="description"/>
		<xsl:choose>
     			<xsl:when test="$item">
				<xsl:for-each select="$item">
					<xsl:element name='track'>
						<xsl:attribute name='rdf:nodeID'>
							<xsl:value-of select="generate-id()"/>
						</xsl:attribute>
					</xsl:element>
				</xsl:for-each>
			</xsl:when>
    		<xsl:otherwise>
			<xsl:for-each select="$audio">
					<xsl:element name='track'>
						<xsl:attribute name='rdf:nodeID'>
							<xsl:value-of select="generate-id()"/>
						</xsl:attribute>
					</xsl:element>
			</xsl:for-each>
    		</xsl:otherwise>
	</xsl:choose>
</xsl:element>
</xsl:template>

<xsl:template name="artistLink">
<xsl:param name="groupLink" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' contributor ')][1]"/>
<xsl:param name="groupLinkalt" select="/*//*[contains(concat(' ',normalize-space(attribute::class),' '),' contributor ')][1]"/>
<xsl:choose>
     	<xsl:when test="$groupLink">
  		<xsl:for-each select="$groupLink">
			<xsl:element name='dcterms:creator'>
				<xsl:attribute name='rdf:nodeID'>
					<xsl:value-of select="generate-id()"/>
				</xsl:attribute>
			</xsl:element>
		</xsl:for-each>
	</xsl:when>
    	<xsl:otherwise>
  		<xsl:for-each select="$groupLinkalt">
			<xsl:element name='dcterms:creator'>
				<xsl:attribute name='rdf:nodeID'>
					<xsl:value-of select="generate-id()"/>
				</xsl:attribute>
			</xsl:element>
		</xsl:for-each>
    	</xsl:otherwise>
</xsl:choose>
</xsl:template>


<!-- mo:MusicGroup => attribute::class="contributor"-->
<xsl:template name="artist">
<xsl:param name="group" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' contributor ')]"/>
  	<xsl:for-each select="$group">
	<xsl:element name='MusicGroup'>
  	<xsl:attribute name='rdf:nodeID'>
      <xsl:value-of select="generate-id()"/>
    </xsl:attribute>
		<xsl:element name='foaf:name'><xsl:value-of select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' fn ')]" /></xsl:element>
     <xsl:if test="substring-before(descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' url ')]/attribute::href,'musicbrainz') = 'http://'">
				<musicbrainz rdf:resource="{descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' url ')]/attribute::href}"/>
			</xsl:if>
		<xsl:call-template name="madeLink"/>
	</xsl:element>
	</xsl:for-each>
</xsl:template>

<xsl:template name="madeLink">
<xsl:param name="audio" select="/.//*[contains(concat(' ',normalize-space(attribute::class),' '),' haudio ') and descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' fn ')]]"/>
<xsl:for-each select="$audio">
	<xsl:element name='made'>
  		<xsl:attribute name='rdf:nodeID'>
				<xsl:value-of select="generate-id()"/>
		</xsl:attribute>
	</xsl:element>
</xsl:for-each>
</xsl:template>

<!-- see if mo:Record has a title else title of page -->
<xsl:template name="recordtitle">
<xsl:param name="recordtitle" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' fn ')]"/>
<xsl:choose>
     <xsl:when test="$start">
		<xsl:element name='dc:title'><xsl:value-of select="$recordtitle"/></xsl:element>
	</xsl:when>
    	<xsl:otherwise>
		<xsl:element name='dc:title'><xsl:value-of select="descendant::*[name() = 'title']"/></xsl:element>
    	</xsl:otherwise>
</xsl:choose>
</xsl:template>


<!-- haudio has only one type attribute::class="album" all else is considered a compilation -->
<xsl:template name="type">
<xsl:param name="album" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' fn ') and self::*[contains(concat(' ',normalize-space(attribute::class),' '),' album ')]]"/>
<xsl:choose>
     	<xsl:when test="$album">
		<release_type rdf:resource="http://purl.org/ontology/mo/album"/>
	</xsl:when>
    	<xsl:otherwise>
		<release_type rdf:resource="http://purl.org/ontology/mo/compilation"/>
    	</xsl:otherwise>
</xsl:choose>
</xsl:template>


<!-- mo:image => attribute::class="logo" or attribute::class="photo" -->
<xsl:template name="image">
<xsl:param name="photo" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' photo ')]"/>
<xsl:if test="$photo">
	<image rdf:resource="{$photo/attribute::src}"/>
</xsl:if>
</xsl:template>

<!-- published date dc:date => attribute::class="published" -->
<xsl:template name="published">
<xsl:param name="pubdate" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' published ')]"/>
<xsl:if test="$pubdate">
	<dcterms:issued><xsl:value-of select="$pubdate" /></dcterms:issued>
</xsl:if>
</xsl:template>


<xsl:template name="description">
<xsl:param name="desc" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' description ')][1]"/>
	<xsl:if test="$desc">
		<xsl:element name='dc:abstract'>
  			<xsl:attribute name='rdf:datatype'>
		     		<xsl:text>http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral</xsl:text>
			</xsl:attribute>
		     <xsl:text disable-output-escaping="yes">&lt;![CDATA[</xsl:text>
			<xsl:copy-of select="$desc"/>
		     <xsl:text disable-output-escaping="yes">]]&gt;</xsl:text>
		</xsl:element>
	</xsl:if>
</xsl:template>

<!-- test if we are  attribute::class="haudio" -->
<xsl:template name="haudio">
  	<xsl:for-each select="$audio">
		<xsl:call-template name="signal"/>
	</xsl:for-each>
</xsl:template>

<!-- test if we are  attribute::class="item" -->
<xsl:template name="item">
  	<xsl:for-each select="$items">
		<xsl:call-template name="signal"/>
	</xsl:for-each>
</xsl:template>


<!-- mo:Signal and mo:Track -->
<xsl:template name="signal">
<xsl:param name="time" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' duration ')]"/>
	<xsl:element name='Signal'>
		<xsl:call-template name="title"/>
		<xsl:element name='published_as'>
			<xsl:element name='Track'>
				  	<xsl:attribute name='rdf:nodeID'>
							<xsl:value-of select="generate-id()"/>
				</xsl:attribute>
				<xsl:call-template name="title"/>
				<xsl:call-template name="trackLink"/>
				<xsl:call-template name="enclosure"/>
			</xsl:element>
		</xsl:element>
	<xsl:if test="$time">
		<time>
			<time:Interval>
		   		<tl:durationXSD>
					<xsl:value-of select="$time/attribute::title"/>
				</tl:durationXSD>
			</time:Interval>
		</time>
	</xsl:if>
</xsl:element>
</xsl:template>



<!-- dc:title of mo:Track => attribute::class="title"-->
<xsl:template name="title">
<xsl:param name="title" select="descendant::*[contains(concat(' ',normalize-space(attribute::class),' '),' fn ')
                                and not(ancestor::*[contains(concat(' ',normalize-space(attribute::class),' '),' contributor ')])]"/>
	<xsl:if test="$title">
		<xsl:element name='dc:title'>
			<xsl:value-of select="$title"/>
		</xsl:element>
	</xsl:if>
</xsl:template>


<!-- foaf:maker link => attribute::class="contributor"/a/attribute::href-->
<xsl:template name="trackLink">
<xsl:param name="audio" select="/.//*[contains(concat(' ',normalize-space(attribute::class),' '),' contributor ')][1]"/>
<xsl:for-each select="$audio">
	<xsl:element name='dcterms:creator'>
  		<xsl:attribute name='rdf:nodeID'>
				<xsl:value-of select="generate-id()"/>
		</xsl:attribute>
	</xsl:element>
</xsl:for-each>
</xsl:template>

<!-- the file itself mo:available_as => attribute::rel="enclosure"-->
<xsl:template name="enclosure">
<xsl:param name="enc" select="descendant::*[contains(concat(' ',normalize-space(attribute::rel),' '),' enclosure ')]"/>
<xsl:if test="$enc">
	<xsl:element name='available_as'>
  		<xsl:attribute name='rdf:resource'>
			<xsl:value-of select="$enc/attribute::href"/>
		</xsl:attribute>
	</xsl:element>
</xsl:if>
</xsl:template>


<!-- strip text -->
<xsl:template match="text()|@*|*">
  <xsl:apply-templates/>
</xsl:template>

</xsl:stylesheet>
