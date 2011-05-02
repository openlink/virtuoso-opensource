<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2009 OpenLink Software
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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY like "http://ontologi.es/like#">
<!ENTITY mmd "http://musicbrainz.org/ns/mmd-1.0#">
<!ENTITY mo "http://purl.org/ontology/mo/">
<!ENTITY og "http://ogp.me/ns#">
<!ENTITY oplog "http://www.openlinksw.com/schemas/opengraph#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdfns  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY video "http://purl.org/media/video#">
<!ENTITY xhv  "http://www.w3.org/1999/xhtml/vocab#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY vi "http://www.openlinksw.com/virtuoso/xslt/">
]>
<xsl:stylesheet
    xmlns:bibo="&bibo;"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
	xmlns:foaf="&foaf;"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:like="&like;"
    xmlns:mmd="&mmd;"
    xmlns:mo="&mo;"
    xmlns:og="&og;"
    xmlns:oplog="&oplog;"
    xmlns:owl="&owl;"	
    xmlns:rdf="&rdfns;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:sioc="&sioc;"
    xmlns:sioct="&sioct;"
    xmlns:vi="&vi;"
    xmlns:video="&video;"
    xmlns:xhv="&xhv;"
	xmlns:fb="http://www.facebook.com/2008/fbml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0"
	>

	<xsl:param name="baseUri" />
    <xsl:param name="og_object_type" />

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	
	<xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no" indent="yes" />

	<xsl:template match="/">
        <xsl:choose>
            <xsl:when test="$og_object_type = 'user'">
	            <xsl:apply-templates mode="root"/>
	            <xsl:apply-templates mode="user"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'user_activities'">
	            <xsl:apply-templates mode="user_activities"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'user_books'">
	            <xsl:apply-templates mode="user_books"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'user_friends'">
	            <xsl:apply-templates mode="user_friends"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'user_likes'">
	            <xsl:apply-templates mode="user_likes"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'user_movies'">
	            <xsl:apply-templates mode="user_movies"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'user_music'">
	            <xsl:apply-templates mode="user_music"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'user_picture'">
	            <xsl:apply-templates mode="user_picture"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'user_posts'">
	            <xsl:apply-templates mode="user_posts"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'user_television'">
	            <xsl:apply-templates mode="user_television"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'page'">
	            <xsl:apply-templates mode="root"/>
	            <xsl:apply-templates mode="page"/>
            </xsl:when>
            <xsl:when test="$og_object_type = 'general'">
	            <xsl:apply-templates mode="general"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>    

	<xsl:template match="/results">
		<rdf:RDF>
        </rdf:RDF>
    </xsl:template>

	<xsl:template match="/results" mode="root">
		<rdf:RDF>
           <rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<xsl:if test="normalize-space (name) != ''">
				<dc:title><xsl:value-of select="concat(name, ' (container)')"/></dc:title>
				</xsl:if>
				<owl:sameAs rdf:resource="{$docIRI}"/>
		    </rdf:Description>
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="/results" mode="general">
		<rdf:RDF>
           <rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<xsl:if test="normalize-space (name) != ''">
				    <dc:title><xsl:value-of select="concat(document/name, ' (container)')"/></dc:title>
                </xsl:if>
				<owl:sameAs rdf:resource="{$docIRI}"/>
		    </rdf:Description>
		    <rdf:Description rdf:about="{$resourceURL}">
				<rdf:type rdf:resource="&oplog;Page" />
                <xsl:if test="document/id">
                    <oplog:id><xsl:value-of select="document/id"/></oplog:id>
                </xsl:if>
                <xsl:if test="document/name">
                    <dc:title><xsl:value-of select="document/name"/></dc:title>
					<rdfs:label><xsl:value-of select="document/name"/></rdfs:label>
                </xsl:if>
                <xsl:if test="document/picture">
                    <foaf:img rdf:resource="{document/picture}"/>
                </xsl:if>
                <xsl:if test="string-length(document/link) &gt; 0">
                    <bibo:uri rdf:resource="{document/link}"/>
                </xsl:if>
                <xsl:if test="document/website">
                    <foaf:page rdf:resource="{document/website}"/>
                </xsl:if>
                <xsl:if test="document/category">
                    <og:category><xsl:value-of select="document/category"/></og:category>
                </xsl:if>
                <xsl:if test="document/description">
                    <dc:description><xsl:value-of select="document/description"/></dc:description>
                </xsl:if>
                <xsl:if test="document/likes">
                    <fb:like><xsl:value-of select="document/likes"/></fb:like>
                </xsl:if>
				<xsl:for-each select="document/metadata/connections/*">
					<rdfs:seeAlso rdf:resource="{.}"/>
				</xsl:for-each>
		    </rdf:Description>
		</rdf:RDF>
	</xsl:template>

    <!-- 
    Process output from: http://graph.facebook.com/<id> where id identifies a User object 
    Only fields/connections which are either 'Publicly available' or 'Available to everyone on Facebook' are included.
    Those which require a particular permission, e.g. 'user_education_history', are excluded.
    -->
	<xsl:template match="/results" mode="user">
		<rdf:RDF>
		    <rdf:Description rdf:about="{$resourceURL}">
                <rdf:type rdf:resource="&foaf;Person" />
                <rdf:type rdf:resource="&oplog;User" />

                <xsl:if test="id">
                    <oplog:id><xsl:value-of select="id"/></oplog:id>
                </xsl:if>
                <xsl:if test="name">
                    <foaf:name><xsl:value-of select="name"/></foaf:name>
                </xsl:if>
                <xsl:if test="first_name">
                    <foaf:firstName><xsl:value-of select="first_name"/></foaf:firstName>
                </xsl:if>
                <xsl:if test="last_name">
                    <foaf:lastName><xsl:value-of select="last_name"/></foaf:lastName>
                </xsl:if>
                <xsl:if test="gender">
    				<foaf:gender><xsl:value-of select="gender"/></foaf:gender>
                </xsl:if>
                <xsl:if test="locale">
    				<oplog:locale><xsl:value-of select="locale"/></oplog:locale>
                </xsl:if>
                <xsl:if test="link">
                    <oplog:uri rdf:resource="{link}"/>
                </xsl:if>
				<xsl:if test="username">
                    <foaf:nick><xsl:value-of select="username"/></foaf:nick>
                    <oplog:username><xsl:value-of select="username"/></oplog:username>
                </xsl:if>
				<xsl:if test="third_party_id">
                    <oplog:third_party_id><xsl:value-of select="third_party_id"/></oplog:third_party_id>
                </xsl:if>
                <xsl:if test="updated_time">
    				<dcterms:modified rdf:datatype="&xsd;dateTime">
						<xsl:value-of select="updated_time"/>
					</dcterms:modified>
                </xsl:if>
				<xsl:if test="verified">
                    <oplog:verified><xsl:value-of select="verified"/></oplog:verified>
                </xsl:if>
		    </rdf:Description>
		</rdf:RDF>
	</xsl:template>

    <!-- Process output from: http://graph.facebook.com/<id>/friends?access_token=... -->
	<xsl:template match="/results" mode="user_friends">
		<rdf:RDF>
            <rdf:Description rdf:about="{$resourceURL}">
                <xsl:for-each select="data">
		            <xsl:variable name="id" select="id" />
                    <foaf:knows>
	                        <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('Friend_', $id))}">
                                <rdf:type rdf:resource="&foaf;Person" />
                                <rdf:type rdf:resource="&oplog;User" />
                                <oplog:id><xsl:value-of select="id"/></oplog:id>
                                <foaf:name><xsl:value-of select="name"/></foaf:name>
	                            <rdfs:seeAlso rdf:resource="{vi:proxyIRI (concat('http://graph.facebook.com/', $id))}" />
		                </rdf:Description>
                    </foaf:knows>
                </xsl:for-each>
		    </rdf:Description>
		</rdf:RDF>
	</xsl:template>

    <!-- Process output from: http://graph.facebook.com/<id>/picture?access_token=... -->
	<xsl:template match="/results" mode="user_picture">
        <xsl:if test="picture">
		    <rdf:RDF>
                <rdf:Description rdf:about="{$resourceURL}">
                    <foaf:img rdf:resource="{picture}"/>
		        </rdf:Description>
		    </rdf:RDF>
        </xsl:if>
	</xsl:template>

    <!-- Process output from: http://graph.facebook.com/<id>/activities?access_token=... -->
	<xsl:template match="/results" mode="user_activities">
	    <rdf:RDF>
            <rdf:Description rdf:about="{$resourceURL}">
                <xsl:for-each select="data">
		            <xsl:variable name="id" select="id" />
                    <oplog:likes_activity>
	                    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('Activity_', $id))}">
                            <rdf:type rdf:resource="&oplog;Activity" />
                            <oplog:id><xsl:value-of select="id"/></oplog:id>
                            <oplog:name><xsl:value-of select="name"/></oplog:name>
                            <rdfs:label><xsl:value-of select="name"/></rdfs:label>
                            <oplog:category><xsl:value-of select="category"/></oplog:category>
    				        <dcterms:created rdf:datatype="&xsd;dateTime">
                                <xsl:value-of select="created_time"/>
					        </dcterms:created>
	                        <rdfs:seeAlso rdf:resource="{vi:proxyIRI (concat('http://graph.facebook.com/', $id))}" />
		                </rdf:Description>
                    </oplog:likes_activity>
                </xsl:for-each>
		    </rdf:Description>
	    </rdf:RDF>
	</xsl:template>

    <!-- Process output from: http://graph.facebook.com/<id>/interests?access_token=... -->
	<xsl:template match="/results" mode="user_likes">
	    <rdf:RDF>
            <rdf:Description rdf:about="{$resourceURL}">
                <xsl:for-each select="data">
		            <xsl:variable name="id" select="id" />
                    <oplog:has_interest>
	                    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('Interest_', $id))}">
                            <rdf:type rdf:resource="&oplog;Interest" />
                            <oplog:id><xsl:value-of select="id"/></oplog:id>
                            <oplog:name><xsl:value-of select="name"/></oplog:name>
                            <rdfs:label><xsl:value-of select="name"/></rdfs:label>
                            <oplog:category><xsl:value-of select="category"/></oplog:category>
    				        <dcterms:created rdf:datatype="&xsd;dateTime">
                                <xsl:value-of select="created_time"/>
					        </dcterms:created>
	                        <rdfs:seeAlso rdf:resource="{vi:proxyIRI (concat('http://graph.facebook.com/', $id))}" />
		                </rdf:Description>
                    </oplog:has_interest>
                </xsl:for-each>
		    </rdf:Description>
	    </rdf:RDF>
	</xsl:template>

    <!-- Process output from: http://graph.facebook.com/<id>/movies?access_token=... -->
	<xsl:template match="/results" mode="user_movies">
	    <rdf:RDF>
            <rdf:Description rdf:about="{$resourceURL}">
                <xsl:for-each select="data">
		            <xsl:variable name="id" select="id" />
                    <oplog:likes_movie>
	                    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('Movie_', $id))}">
                            <rdf:type rdf:resource="&oplog;Movie" />
                            <rdf:type rdf:resource="&video;Movie" />
                            <oplog:id><xsl:value-of select="id"/></oplog:id>
                            <oplog:name><xsl:value-of select="name"/></oplog:name>
                            <rdfs:label><xsl:value-of select="name"/></rdfs:label>
                            <oplog:category><xsl:value-of select="category"/></oplog:category>
    				        <dcterms:created rdf:datatype="&xsd;dateTime">
                                <xsl:value-of select="created_time"/>
					        </dcterms:created>
	                        <rdfs:seeAlso rdf:resource="{vi:proxyIRI (concat('http://graph.facebook.com/', $id))}" />
		                </rdf:Description>
                    </oplog:likes_movie>
                </xsl:for-each>
		    </rdf:Description>
	    </rdf:RDF>
	</xsl:template>

    <!-- Process output from: http://graph.facebook.com/<id>/music?access_token=... -->
	<xsl:template match="/results" mode="user_music">
	    <rdf:RDF>
            <rdf:Description rdf:about="{$resourceURL}">
                <xsl:for-each select="data">
		            <xsl:variable name="id" select="id" />
                    <oplog:likes_music>
	                    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('Music_', $id))}">
                            <rdf:type rdf:resource="&oplog;Music" />
                            <oplog:id><xsl:value-of select="id"/></oplog:id>
                            <oplog:name><xsl:value-of select="name"/></oplog:name>
                            <rdfs:label><xsl:value-of select="name"/></rdfs:label>
                            <oplog:category><xsl:value-of select="category"/></oplog:category>
    				        <dcterms:created rdf:datatype="&xsd;dateTime">
                                <xsl:value-of select="created_time"/>
					        </dcterms:created>
	                        <rdfs:seeAlso rdf:resource="{vi:proxyIRI (concat('http://graph.facebook.com/', $id))}" />
		                </rdf:Description>
                    </oplog:likes_music>
                </xsl:for-each>
		    </rdf:Description>
	    </rdf:RDF>
	</xsl:template>

    <!-- Process output from: http://graph.facebook.com/<id>/books?access_token=... -->
	<xsl:template match="/results" mode="user_books">
	    <rdf:RDF>
            <rdf:Description rdf:about="{$resourceURL}">
                <xsl:for-each select="data">
		            <xsl:variable name="id" select="id" />
                    <oplog:likes_book>
	                    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('Book_', $id))}">
                            <rdf:type rdf:resource="&oplog;Book" />
                            <rdf:type rdf:resource="&bibo;Book" />
                            <oplog:id><xsl:value-of select="id"/></oplog:id>
                            <oplog:name><xsl:value-of select="name"/></oplog:name>
                            <rdfs:label><xsl:value-of select="name"/></rdfs:label>
                            <oplog:category><xsl:value-of select="category"/></oplog:category>
    				        <dcterms:created rdf:datatype="&xsd;dateTime">
                                <xsl:value-of select="created_time"/>
					        </dcterms:created>
	                        <rdfs:seeAlso rdf:resource="{vi:proxyIRI (concat('http://graph.facebook.com/', $id))}" />
		                </rdf:Description>
                    </oplog:likes_book>
                </xsl:for-each>
		    </rdf:Description>
	    </rdf:RDF>
	</xsl:template>

    <!-- Process output from: http://graph.facebook.com/<id>/books?access_token=... -->
	<xsl:template match="/results" mode="user_television">
	    <rdf:RDF>
            <rdf:Description rdf:about="{$resourceURL}">
                <xsl:for-each select="data">
		            <xsl:variable name="id" select="id" />
                    <oplog:likes_tv_programme>
	                    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('Television_', $id))}">
                            <rdf:type rdf:resource="&oplog;TvProgramme" />
                            <oplog:id><xsl:value-of select="id"/></oplog:id>
                            <oplog:name><xsl:value-of select="name"/></oplog:name>
                            <rdfs:label><xsl:value-of select="name"/></rdfs:label>
                            <oplog:category><xsl:value-of select="category"/></oplog:category>
    				        <dcterms:created rdf:datatype="&xsd;dateTime">
                                <xsl:value-of select="created_time"/>
					        </dcterms:created>
	                        <rdfs:seeAlso rdf:resource="{vi:proxyIRI (concat('http://graph.facebook.com/', $id))}" />
		                </rdf:Description>
                    </oplog:likes_tv_programme>
                </xsl:for-each>
		    </rdf:Description>
	    </rdf:RDF>
	</xsl:template>

	<xsl:template match="/results" mode="page">
		<rdf:RDF>
		    <rdf:Description rdf:about="{$resourceURL}">
                <rdf:type rdf:resource="&oplog;Page" />

                <xsl:if test="id">
                    <oplog:id><xsl:value-of select="id"/></oplog:id>
                </xsl:if>
                <xsl:if test="name">
                    <oplog:name><xsl:value-of select="name"/></oplog:name>
                    <rdfs:label><xsl:value-of select="name"/></rdfs:label>
                    <dc:title><xsl:value-of select="name"/></dc:title>
                </xsl:if>
                <xsl:if test="category">
                    <oplog:category><xsl:value-of select="category"/></oplog:category>
                </xsl:if>
                <xsl:if test="description">
                    <oplog:description><xsl:value-of select="description"/></oplog:description>
                </xsl:if>
                <xsl:if test="picture">
                    <foaf:img rdf:resource="{picture}"/>
                </xsl:if>
                <xsl:if test="string-length(link) &gt; 0">
                    <bibo:uri rdf:resource="{link}"/>
                </xsl:if>
                <xsl:if test="likes">
                    <fb:like><xsl:value-of select="likes"/></fb:like>
                </xsl:if>
				<xsl:for-each select="metadata/connections/*">
					<rdfs:seeAlso rdf:resource="{.}"/>
				</xsl:for-each>
		    </rdf:Description>
		</rdf:RDF>
	</xsl:template>

    <!-- Process output from: http://graph.facebook.com/<id>/posts?access_token=... -->
	<xsl:template match="/results" mode="user_posts">
	    <rdf:RDF>
            <rdf:Description rdf:about="{$resourceURL}">
                <xsl:for-each select="data">
		            <xsl:variable name="id" select="id" />
                    <oplog:posted>
	                    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', concat('Post_', $id))}">
                            <rdf:type rdf:resource="&oplog;Post" />
                            <oplog:id><xsl:value-of select="id"/></oplog:id>
                            <oplog:from><xsl:value-of select="concat (from/name, ' (', from/id, ')')"/></oplog:from>
    				        <dcterms:created rdf:datatype="&xsd;dateTime">
                                <xsl:value-of select="created_time"/>
					        </dcterms:created>
                            <!--
                            <xsl:if test="name">
                                <rdfs:label><xsl:value-of select="name"/></rdfs:label>
                            </xsl:if>
                            -->
                            <rdfs:label><xsl:value-of select="concat ('Post ', $id)"/></rdfs:label>
                            <xsl:if test="description">
                                <oplog:description><xsl:value-of select="description"/></oplog:description>
                            </xsl:if>
                            <xsl:if test="message">
                                <oplog:message><xsl:value-of select="message"/></oplog:message>
                            </xsl:if>
                            <xsl:if test="actions/link">
		                        <xsl:variable name="link" select="actions/link" />
                                <oplog:link rdf:resource="{$link}" />
                            </xsl:if>
	                        <rdfs:seeAlso rdf:resource="{vi:proxyIRI (concat('http://graph.facebook.com/', $id))}" />
		                </rdf:Description>
                    </oplog:posted>
                </xsl:for-each>
		    </rdf:Description>
	    </rdf:RDF>
	</xsl:template>


    <xsl:template match="*|text()"/>

</xsl:stylesheet>
