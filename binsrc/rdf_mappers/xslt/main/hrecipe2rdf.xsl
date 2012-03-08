<?xml version="1.0" encoding="utf-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
 -
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
-->
<!DOCTYPE xsl:stylesheet [
<!ENTITY moat "http://moat-project.org/ns#">
<!ENTITY scot "http://scot-project.org/scot/ns#">
<!ENTITY skos "http://www.w3.org/2004/02/skos/core#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
]>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
xmlns:h="http://www.w3.org/1999/xhtml"
xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
xmlns:foaf="http://xmlns.com/foaf/0.1/"
xmlns:dc="http://purl.org/dc/elements/1.1/"
xmlns:sioc="http://rdfs.org/sioc/ns#"
xmlns:scot="&scot;"
xmlns:moat="&moat;"
xmlns:skos="&skos;"
xmlns:wdrs="http://www.w3.org/2007/05/powder-s#"
xmlns:opl="&opl;"
xmlns:dv="http://rdf.data-vocabulary.org/" version="1.0">
  <xsl:output method="xml" encoding="utf-8" indent="yes" />
  <xsl:preserve-space elements="*" />
  <xsl:param name="baseUri" />

  <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
  <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
  
  <xsl:template match="/">
    <rdf:RDF>
      <xsl:apply-templates />
    </rdf:RDF>
  </xsl:template>
  <xsl:template match="*">
    <xsl:variable name="recipe">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'hrecipe'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="$recipe = 0">	
		<xsl:variable name="recipe">
		  <xsl:call-template name="testclass">
			<xsl:with-param name="val" select="'hRecipe'" />
		  </xsl:call-template>
		</xsl:variable>
    </xsl:if>
    <xsl:if test="$recipe != 0">
      <rdf:Description rdf:about="{$docproxyIRI}">
        <foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'hrecipe')}" />
      </rdf:Description>
      <dv:Recipe rdf:about="{vi:proxyIRI ($baseUri, '', 'hrecipe')}">
				<opl:providedBy>
					<xsl:variable name="home1" select="substring-after($baseUri, '//')"/>
					<xsl:variable name="home2" select="substring-before($home1, '/')"/>
					<xsl:variable name="home" select="concat('http://', $home2)"/>
					<xsl:if test="string-length($home) &lt; 8">
						<xsl:variable name="home2" select="$baseUri"/>
						<xsl:variable name="home" select="$baseUri"/>
					</xsl:if>
					<foaf:Organization rdf:about="{concat($home, '#this')}">
						<foaf:name>
							<xsl:value-of select="$home2" />
						</foaf:name>
						<foaf:homepage rdf:resource="{$home}"/>
					</foaf:Organization>
				</opl:providedBy>
			
	<foaf:page rdf:resource="{$baseUri}"/>
				<wdrs:describedby rdf:resource="{$resourceURL}"/>
        <xsl:apply-templates mode="extract-recipe" />
      </dv:Recipe>
    </xsl:if>
    <xsl:apply-templates />
  </xsl:template>
  <xsl:template match="comment()|processing-instruction()|text()" />
  <!-- ============================================================ -->
  <xsl:template match="*" mode="extract-recipe">
    <xsl:variable name="fn">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'fn'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="ingredient">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'ingredient'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="ingredients">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'ingredients'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="yield">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'yield'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="instructions">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'instructions'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="directions">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'directions'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="duration">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'duration'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="prepTime">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'prepTime'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="cooktime">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'cooktime'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="cookTime">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'cookTime'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="totalTime">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'totalTime'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="photo">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'photo'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="food-image">
      <xsl:call-template name="testid">
        <xsl:with-param name="val" select="'food-image'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="summary">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'summary'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="author">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'author'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="published">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'published'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="nutrition">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'nutrition'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="nutritional-information">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'nutritional-information'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="tag">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'tag'" />
      </xsl:call-template>
    </xsl:variable>
    <!-- ============================================================ -->
    <xsl:if test="$fn != 0">
			<xsl:variable name="is_author">
				<xsl:call-template name="testclass">
					<xsl:with-param name="class" select="../@class" />
					<xsl:with-param name="val" select="'author'" />
				</xsl:call-template>
			</xsl:variable>
			<xsl:if test="$is_author = 0">
      <dc:title>
        <xsl:value-of select="." />
      </dc:title>
      <dv:name>
        <xsl:value-of select="." />
      </dv:name>
    </xsl:if>
		</xsl:if>
	
    <xsl:if test="$ingredient != 0">
		<xsl:variable name="ing_name">
		  <xsl:call-template name="testclass">
			<xsl:with-param name="val" select="'name'" />
		  </xsl:call-template>
		</xsl:variable>
		<xsl:choose>
				<xsl:when test="string-length($ing_name) &gt; 0">
			  <dv:ingredient>
						<dv:Ingredient rdf:about="{vi:proxyIRI ($baseUri, '', escape-uri(concat('hrecipe', substring( replace(normalize-space(.), ' ', ''), 1 , 20) ), true())) }">
					<dv:name>
								<xsl:choose>
									<xsl:when test="*[@class = 'name' or starts-with(@class,concat('name', ' ')) or contains(@class,concat(' ','name',' ')) or substring(@class, string-length(@class)-string-length('name')) = concat(' ','name')]">
						<xsl:value-of select="*[@class = 'name' or starts-with(@class,concat('name', ' ')) or contains(@class,concat(' ','name',' ')) 
						or substring(@class, string-length(@class)-string-length('name')) = concat(' ','name')]" />
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="." />
									</xsl:otherwise>
								</xsl:choose>
					</dv:name>
							<rdfs:label>
								<xsl:value-of select="." />
							</rdfs:label>
					<dv:amount>
						<xsl:choose>
							<xsl:when test="*[@class = 'amount' or starts-with(@class,concat('amount', ' ')) or contains(@class,concat(' ','amount',' ')) 
									or substring(@class, string-length(@class)-string-length('amount')) = concat(' ','amount')]">
								<xsl:variable name="amount" select="*[@class = 'amount' or starts-with(@class,concat('amount', ' ')) or contains(@class,concat(' ','amount',' ')) 
									or substring(@class, string-length(@class)-string-length('amount')) = concat(' ','amount')]"/>
							</xsl:when>
							<xsl:otherwise>
								<xsl:variable name="amount" select="."/>
							</xsl:otherwise>
						</xsl:choose>
						<xsl:value-of select="$amount" />
					</dv:amount>
				</dv:Ingredient>
			  </dv:ingredient>
			</xsl:when>
			<xsl:otherwise>
				<dv:ingredient>
					<xsl:value-of select="." />
				</dv:ingredient>
			</xsl:otherwise>
		</xsl:choose>
    </xsl:if>

	<xsl:if test="$ingredients != 0">
			<xsl:if test="string-length(.) &gt; 0">
      <dv:ingredient>
        <xsl:value-of select="." />
      </dv:ingredient>
    </xsl:if>
		</xsl:if>
	
    <xsl:if test="$yield != 0">
      <dv:yield>
        <xsl:value-of select="." />
      </dv:yield>
    </xsl:if>
    <xsl:if test="$instructions != 0">
			<xsl:if test="string-length(normalize-space(.)) &gt; 0">
      <dv:instructions>
        <xsl:value-of select="." />
      </dv:instructions>
    </xsl:if>
		</xsl:if>
    <xsl:if test="$directions != 0">
			<xsl:if test="string-length(normalize-space(.)) &gt; 0">
      <dv:instructions>
        <xsl:value-of select="." />
      </dv:instructions>
    </xsl:if>
		</xsl:if>
    <xsl:if test="$duration != 0">
      <dv:duration>
        <xsl:value-of select="." />
      </dv:duration>
    </xsl:if>
    <xsl:if test="$prepTime != 0">
	  <xsl:if test="string-length(.) &gt; 0">
      <dv:prepTime>
        <xsl:value-of select="." />
      </dv:prepTime>
    </xsl:if>
    </xsl:if>
    <xsl:if test="$cooktime != 0">
	  <dv:cookTime>
		<xsl:value-of select="." />
	  </dv:cookTime>
    </xsl:if>
    <xsl:if test="$cookTime != 0">
	  <xsl:if test="string-length(.) &gt; 0">
   	  <dv:cookTime>
        <xsl:value-of select="." />
      </dv:cookTime>
	  </xsl:if>
    </xsl:if>
    <xsl:if test="$totalTime != 0">
	  <xsl:if test="string-length(.) &gt; 0">
      <dv:totalTime>
        <xsl:value-of select="." />
      </dv:totalTime>
    </xsl:if>
    </xsl:if>
    <xsl:if test="$food-image != 0 and @src">
      <dv:photo rdf:resource="{@src}" />
    </xsl:if>
    <xsl:if test="$photo != 0 and @src">
      <dv:photo rdf:resource="{@src}" />
    </xsl:if>
    <xsl:if test="$summary != 0">
      <dv:summary>
        <xsl:value-of select="." />
      </dv:summary>
    </xsl:if>
    <xsl:if test="$author != 0">
      <dv:author>
        <xsl:value-of select="." />
      </dv:author>
    </xsl:if>
    <xsl:if test="$published != 0">
      <dv:published>
        <xsl:value-of select="." />
      </dv:published>
    </xsl:if>
    <xsl:if test="$nutrition != 0">
	  <xsl:if test="string-length(.) &gt; 0">
      <dv:nutrition>
        <xsl:value-of select="." />
      </dv:nutrition>
    </xsl:if>
    </xsl:if>
    <xsl:if test="$nutritional-information != 0">
	  <xsl:if test="string-length(.) &gt; 0">
  	  <dv:nutrition>
        <xsl:value-of select="." />
      </dv:nutrition>
    </xsl:if>
    </xsl:if>
    <xsl:if test="$tag != 0">
			<scot:hasScot>
				<scot:Tagcloud rdf:about="{vi:proxyIRI($baseUri, '', 'tagcloud')}">
					<scot:hasTag rdf:resource="{vi:proxyIRI ($baseUri, '', concat ('tag_', .))}"/>
				</scot:Tagcloud>
			</scot:hasScot>
			<sioc:topic>
				<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat ('tag_', .))}">
					<rdf:type rdf:resource="&skos;Concept"/>
					<rdf:type rdf:resource="&scot;Tag "/>
					<rdf:type rdf:resource="&moat;Tag"/>
					<skos:prefLabel>
						<xsl:value-of select="."/>
					</skos:prefLabel>
					<scot:name>
						<xsl:value-of select="."/>
					</scot:name>
					<dc:description>
						Tag: <xsl:value-of select="."/>
					</dc:description>
					<skos:isSubjectOf rdf:resource="{vi:proxyIRI ($baseUri, '', 'hrecipe')}"/>
					<foaf:topic rdf:resource="{vi:dbpIRI ($baseUri, .)}"/>
					<moat:name>
        <xsl:value-of select="." />
					</moat:name>
					<foaf:topic rdf:resource="{vi:dbpIRI ($baseUri, .)}"/>
				</rdf:Description>
			</sioc:topic>
    </xsl:if>
    <xsl:apply-templates mode="extract-recipe" />
  </xsl:template>
  <xsl:template match="comment()|processing-instruction()|text()" mode="extract-recipe" />
  
  <xsl:template name="testclass">
    <xsl:param name="class" select="@class" />
    <xsl:param name="val" select="''" />
    <xsl:choose>
      <xsl:when test="$class = $val or starts-with($class,concat($val, ' ')) or contains($class,concat(' ',$val,' ')) or substring($class, string-length($class)-string-length($val)) = concat(' ',$val)">1</xsl:when>
      <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="testid">
    <xsl:param name="class" select="@id" />
    <xsl:param name="val" select="''" />
    <xsl:choose>
      <xsl:when test="$class = $val or starts-with($class,concat($val, ' ')) or contains($class,concat(' ',$val,' ')) or substring($class, string-length($class)-string-length($val)) = concat(' ',$val)">1</xsl:when>
      <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
