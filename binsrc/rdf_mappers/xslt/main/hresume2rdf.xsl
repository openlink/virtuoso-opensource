<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet 
	xmlns:dc="http://purl.org/dc/elements/1.1/" 
	xmlns:rss="http://purl.org/rss/1.0/"
    xmlns:dcterms="http://purl.org/dc/terms/" 
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" 
	xmlns:foaf="http://xmlns.com/foaf/0.1/" 
	xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:admin="http://webns.net/mvcb/" 
	xmlns:h="http://www.w3.org/1999/xhtml" 
	xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:review="http:/www.purl.org/stuff/rev#" 
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:v="http://www.w3.org/2006/vcard/ns#" 
	xmlns:cv="http://purl.org/captsolo/resume-rdf/0.2/cv#"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:cvbase="http://purl.org/captsolo/resume-rdf/0.2/base#" 
	version="1.0">
    <xsl:output indent="yes" omit-xml-declaration="yes" method="xml" />
    <xsl:param name="baseUri" />
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	
    <xsl:template match="/">
        <rdf:RDF>
            <xsl:apply-templates />
        </rdf:RDF>
    </xsl:template>
    <xsl:template match="//*[@class='hresume']">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'hresume')}" />
		</rdf:Description>
        <cv:CV rdf:about="{vi:proxyIRI ($baseUri, '', 'hresume')}">
            <xsl:apply-templates mode="hresume" />
        </cv:CV>
    </xsl:template>

    <xsl:template match="comment()|processing-instruction()|text()"/>

    <xsl:template match="//*[@class='hresume']/*[@class='summary']" mode="hresume">
        <cv:cvDescription>
            <xsl:value-of select="." />
        </cv:cvDescription>
    </xsl:template>

    <xsl:template match="//*[@class='vcalendar']/*[contains(@class, 'experience')]" mode="hresume">
        <cv:hasWorkHistory>
            <cv:WorkHistory>
                <xsl:attribute name="rdf:about">
                    <xsl:value-of select="concat('#', *[contains(@class, 'location')])" />
                </xsl:attribute>
                <cv:employedIn>
                    <cv:Company>
                        <xsl:attribute name="rdf:about">
                            <xsl:value-of select="concat('#', *[contains(@class, 'location')])" />
                        </xsl:attribute>
                        <cv:Name>
                            <xsl:value-of select="*[contains(@class, 'location')]" />
                        </cv:Name>
                        <cv:startDate>
                            <xsl:value-of select="*/abbr[@class='dtstart']/@title"/>
                        </cv:startDate>
                        <cv:endDate>
                            <xsl:value-of select="*/abbr[not (@class='dtstart')]/@title"/>
                        </cv:endDate>
                        <cv:jobTitle>
                            <xsl:value-of select="*[contains(@class, 'summary')]"/>
                        </cv:jobTitle>
                        <cv:jobDescription>
                            <xsl:value-of select="*[contains(@class, 'description')]"/>
                        </cv:jobDescription>
                        <cv:jobType>
                            <xsl:value-of select="*[contains(@class, 'summary')]"/>
                        </cv:jobType>
                    </cv:Company>
                </cv:employedIn>
            </cv:WorkHistory>
        </cv:hasWorkHistory>
    </xsl:template>

    <xsl:template match="//*[@rel='tag' and @class='skill']" mode="hresume">
        <cv:hasSkill>
            <cv:Skill rdf:about="{@href}">
                <cv:skillName>
                    <xsl:value-of select="."/>
                </cv:skillName>
            </cv:Skill>
        </cv:hasSkill>
    </xsl:template>

    <xsl:template match="*" mode="hresume">
        <xsl:variable name="contact">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'vcard'"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:if test="$contact != 0">
            <cv:aboutPerson>
                <cv:Person>
                    <xsl:apply-templates select="." mode="extract-vcard" />
                </cv:Person>
            </cv:aboutPerson>
        </xsl:if>
        <xsl:apply-templates mode="hresume" />
    </xsl:template>

    <xsl:template match="comment()|processing-instruction()|text()" mode="hresume"/>

    <xsl:template match="*" mode="extract-vcal">
        <xsl:variable name="class" select="@class" />
        <xsl:variable name="field">
            <xsl:choose>
                <xsl:when test="contains($class, 'education') ">
                    <xsl:value-of select="'education'" />
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$field='education'">
                <cv:hasEducation>
                    <cv:Education>
                        <xsl:attribute name="rdf:about">
                            <xsl:value-of select="concat('#', *[contains(@class, 'summary')])" />
                        </xsl:attribute>
                    </cv:Education>
                </cv:hasEducation>
            </xsl:when>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="*" mode="extract-vcard">
        <xsl:variable name="fn">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'fn'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="n">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'n'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="sort-string">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'sort-string'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="nickname">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'nickname'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="url">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'url'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="email">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'email'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="tel">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'tel'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="adr">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'adr'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="label">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'label'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="geo">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'geo'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="tz">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'tz'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="photo">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'photo'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="logo">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'logo'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="sound">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'sound'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="bday">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'bday'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="title">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'title'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="role">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'role'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="org">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'org'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="category">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'category'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="note">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'note'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="class">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'class'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="key">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'key'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="mailer">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'mailer'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="uid">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'uid'" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="rev">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="'rev'" />
            </xsl:call-template>
        </xsl:variable> <!-- ============================================================ -->
        <xsl:if test="$fn != 0">
            <xsl:attribute name="rdf:about">
                <xsl:value-of select="concat('#', urlify (.))" />
            </xsl:attribute>
            <v:fn>
                <xsl:value-of select="." />
            </v:fn>
        </xsl:if>
        <xsl:if test="$n != 0">
            <v:n rdf:parseType="Resource">
                <rdf:type rdf:resource="http://nwalsh.com/rdf/vCard#Name" />
                <xsl:apply-templates select="." mode="extract-field">
                    <xsl:with-param name="field" select="'given-name'" />
                </xsl:apply-templates>
                <xsl:apply-templates select="." mode="extract-field">
                    <xsl:with-param name="field" select="'family-name'" />
                </xsl:apply-templates>
                <xsl:apply-templates select="." mode="extract-field">
                    <xsl:with-param name="field" select="'additional-name'" />
                </xsl:apply-templates>
                <xsl:apply-templates select="." mode="extract-field">
                    <xsl:with-param name="field" select="'honorific-prefix'" />
                </xsl:apply-templates>
                <xsl:apply-templates select="." mode="extract-field">
                    <xsl:with-param name="field" select="'honorific-suffix'" />
                </xsl:apply-templates>
                <xsl:apply-templates select="." mode="extract-field">
                    <xsl:with-param name="field" select="'nickname'" />
                </xsl:apply-templates>
            </v:n>
        </xsl:if>
        <xsl:if test="$url != 0">
            <v:url>
                <xsl:attribute name="rdf:resource">
                    <xsl:choose>
                        <xsl:when test="@href">
                            <xsl:value-of select="@href" />
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:if test="not(contains(.,':'))">http://</xsl:if>
                            <xsl:value-of select="string(.)" />
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:attribute>
            </v:url>
        </xsl:if>
        <xsl:if test="$email != 0">
            <xsl:apply-templates select="." mode="extract-email" />
        </xsl:if>
        <xsl:if test="$tel != 0">
            <xsl:apply-templates select="." mode="extract-tel" />
        </xsl:if>
        <xsl:if test="$adr != 0">
            <xsl:apply-templates select="." mode="extract-adr" />
        </xsl:if>
        <xsl:if test="$label != 0">
            <v:label>
                <xsl:value-of select="." />
            </v:label>
        </xsl:if>
        <xsl:if test="$geo != 0">
            <v:geo rdf:parseType="Resource">
                <rdf:type rdf:resource="http://nwalsh.com/rdf/vCard#Geo" />
                <xsl:apply-templates select="." mode="extract-field">
                    <xsl:with-param name="field" select="'latitude'" />
                </xsl:apply-templates>
                <xsl:apply-templates select="." mode="extract-field">
                    <xsl:with-param name="field" select="'longitude'" />
                </xsl:apply-templates>
            </v:geo>
        </xsl:if>
        <xsl:if test="$tz != 0">
            <v:tz>
                <xsl:value-of select="." />
            </v:tz>
        </xsl:if>
        <xsl:if test="$photo != 0 and @src">
            <v:photo rdf:resource="{@src}" />
        </xsl:if>
        <xsl:if test="$logo != 0 and @src">
            <v:logo rdf:resource="{@src}" />
        </xsl:if>
        <xsl:if test="$sound != 0 and @data">
            <v:sound rdf:resource="{@src}" />
        </xsl:if>
        <xsl:if test="$bday != 0 and @title">
            <v:bday>
                <xsl:value-of select="@title" />
            </v:bday>
        </xsl:if>
        <xsl:if test="$title != 0">
            <v:title>
                <xsl:value-of select="." />
            </v:title>
        </xsl:if>
        <xsl:if test="$role != 0">
            <v:role>
                <xsl:value-of select="." />
            </v:role>
        </xsl:if>
        <xsl:if test="$org != 0">
            <xsl:variable name="exists">
                <xsl:apply-templates select="." mode="field-exists">
                    <xsl:with-param name="field" select="'organization-name'" />
                </xsl:apply-templates>
            </xsl:variable>
            <xsl:choose>
                <xsl:when test="$exists != ''">
                    <v:org rdf:parseType="Resource">
                        <rdf:type rdf:resource="http://nwalsh.com/rdf/vCard#Organization" />
                        <xsl:apply-templates select="." mode="extract-field">
                            <xsl:with-param name="field" select="'organization-name'" />
                        </xsl:apply-templates>
                        <xsl:apply-templates select="." mode="extract-field">
                            <xsl:with-param name="field" select="'organization-unit'" />
                        </xsl:apply-templates>
                    </v:org>
                </xsl:when>
                <xsl:otherwise>
                    <v:org rdf:parseType="Resource">
                        <rdf:type rdf:resource="http://nwalsh.com/rdf/vCard#Organization" />
                        <v:organization-name>
                            <xsl:value-of select="." />
                        </v:organization-name>
                    </v:org>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
        <xsl:if test="$category != 0">
            <v:category>
                <xsl:value-of select="." />
            </v:category>
        </xsl:if>
        <xsl:if test="$note != 0">
            <v:note>
                <xsl:value-of select="." />
            </v:note>
        </xsl:if>
        <xsl:if test="$class != 0">
            <v:class>
                <xsl:value-of select="." />
            </v:class>
        </xsl:if>
        <xsl:if test="$key != 0 and @data">
            <v:key rdf:resource="{@data}" />
        </xsl:if>
        <xsl:if test="$mailer != 0">
            <v:mailer>
                <xsl:value-of select="." />
            </v:mailer>
        </xsl:if>
        <xsl:if test="$uid != 0">
            <v:uid>
                <xsl:value-of select="." />
            </v:uid>
        </xsl:if>
        <xsl:if test="$rev != 0 and @title">
            <v:rev>
                <xsl:value-of select="@title" />
            </v:rev>
        </xsl:if>
        <xsl:if test="$sort-string != 0">
            <v:sort-string>
                <xsl:value-of select="." />
            </v:sort-string>
        </xsl:if>
        <xsl:if test="$nickname != 0">
            <v:nickname>
                <xsl:value-of select="." />
            </v:nickname>
        </xsl:if>
        <xsl:apply-templates mode="extract-vcard" />
    </xsl:template>
    <xsl:template match="comment()|processing-instruction()|text()" mode="extract-vcard" />
    <xsl:template match="*" mode="extract-tel">
        <xsl:variable name="type" select=".//*[@class='type']" />
        <xsl:variable name="value" select=".//*[@class='value']" />
        <xsl:variable name="lv" select=".//*[@class]" />
        <xsl:choose>
            <xsl:when test="$type and $value">
                <xsl:call-template name="tel">
                    <xsl:with-param name="type" select="string($type)" />
                    <xsl:with-param name="value" select="string($value)" />
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$lv">
                <xsl:call-template name="tel">
                    <xsl:with-param name="type" select="$lv/@class" />
                    <xsl:with-param name="value" select="string($lv)" />
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="tel">
                    <xsl:with-param name="type" select="''" />
                    <xsl:with-param name="value" select="string(.)" />
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="tel">
        <xsl:param name="type" select="''" />
        <xsl:param name="value" select="'+1-800-555-1212'" />
        <xsl:variable name="token" select="translate($type,
                                               'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                           'abcdefghijklmnopqrstuvwxyz')" />
        <xsl:variable name="rawtel">
            <xsl:call-template name="cleanuptel">
                <xsl:with-param name="value" select="$value" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="tel">
            <xsl:if test="not(starts-with($rawtel,'+'))">+1-</xsl:if>
            <xsl:value-of select="$rawtel" />
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$token = 'mobile' or $token = 'cell'">
                <v:mobileTel rdf:resource="tel:{$tel}" />
            </xsl:when>
            <xsl:when test="$token = 'work' or $token = 'office'">
                <v:workTel rdf:resource="tel:{$tel}" />
            </xsl:when>
            <xsl:when test="$token = 'fax'">
                <v:fax rdf:resource="tel:{$tel}" />
            </xsl:when>
            <xsl:when test="$token = 'home'">
                <v:homeTel rdf:resource="tel:{$tel}" />
            </xsl:when>
            <xsl:otherwise>
                <v:tel rdf:resource="tel:{$tel}" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template> <!-- ============================================================ -->
    <xsl:template match="*" mode="extract-email">
        <xsl:variable name="type" select=".//*[@class='type']" />
        <xsl:variable name="value" select=".//*[@class='value']/@href" />
        <xsl:variable name="lv" select="@href" />
        <xsl:variable name="token" select="translate($type,
                                               'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                           'abcdefghijklmnopqrstuvwxyz')" />
        <xsl:variable name="uri">
            <xsl:choose>
                <xsl:when test="$value != ''">
                    <xsl:value-of select="$value" />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$lv" />
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$token = 'home' or $token = 'personal'">
                <v:personalEmail rdf:resource="{$uri}" />
            </xsl:when>
            <xsl:when test="$token = 'work' or $token = 'office'">
                <v:workEmail rdf:resource="{$uri}" />
            </xsl:when>
            <xsl:when test="$token = 'mobile'">
                <v:mobileEmail rdf:resource="{$uri}" />
            </xsl:when>
            <xsl:otherwise>
                <v:email rdf:resource="{$uri}" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template> <!-- ============================================================ -->
    <xsl:template match="*" mode="extract-adr">
        <xsl:variable name="type" select=".//*[@class='type']" />
        <xsl:variable name="token" select="translate($type,
                                               'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                           'abcdefghijklmnopqrstuvwxyz')" />
        <xsl:variable name="fields">
            <rdf:type rdf:resource="http://nwalsh.com/rdf/vCard#Address" />
            <xsl:apply-templates select="." mode="extract-field">
                <xsl:with-param name="field" select="'post-office-box'" />
            </xsl:apply-templates>
            <xsl:apply-templates select="." mode="extract-field">
                <xsl:with-param name="field" select="'extended-address'" />
            </xsl:apply-templates>
            <xsl:apply-templates select="." mode="extract-field">
                <xsl:with-param name="field" select="'street-address'" />
            </xsl:apply-templates>
            <xsl:apply-templates select="." mode="extract-field">
                <xsl:with-param name="field" select="'locality'" />
            </xsl:apply-templates>
            <xsl:apply-templates select="." mode="extract-field">
                <xsl:with-param name="field" select="'region'" />
            </xsl:apply-templates>
            <xsl:apply-templates select="." mode="extract-field">
                <xsl:with-param name="field" select="'postal-code'" />
            </xsl:apply-templates>
            <xsl:apply-templates select="." mode="extract-field">
                <xsl:with-param name="field" select="'country-name'" />
            </xsl:apply-templates>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$token = 'home' or $token = 'personal'">
                <v:homeAdr rdf:parseType="Resource">
                    <xsl:copy-of select="$fields" />
		<rdfs:label><xsl:value-of select="vi:trim(concat($fields/v:extended-address, ' ', $fields/v:street-address, ', ', $fields/v:locality, ', ', $fields/v:postal-code, ', ', $fields/v:country-name), ', ')"/></rdfs:label>
                </v:homeAdr>
            </xsl:when>
            <xsl:when test="$token = 'work' or $token = 'office'">
                <v:workAdr rdf:parseType="Resource">
                    <xsl:copy-of select="$fields" />
		<rdfs:label><xsl:value-of select="vi:trim(concat($fields/v:extended-address, ' ', $fields/v:street-address, ', ', $fields/v:locality, ', ', $fields/v:postal-code, ', ', $fields/v:country-name), ', ')"/></rdfs:label>
                </v:workAdr>
            </xsl:when>
            <xsl:otherwise>
                <v:adr rdf:parseType="Resource">
                    <xsl:copy-of select="$fields" />
		<rdfs:label><xsl:value-of select="vi:trim(concat($fields/v:extended-address, ' ', $fields/v:street-address, ', ', $fields/v:locality, ', ', $fields/v:postal-code, ', ', $fields/v:country-name), ', ')"/></rdfs:label>
                </v:adr>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="*" mode="field-exists">
        <xsl:param name="field" select="''" />
        <xsl:variable name="f">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="$field" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$f != 0">
                <xsl:value-of select="." />
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="*" mode="field-exists">
                    <xsl:with-param name="field" select="$field" />
                </xsl:apply-templates>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="comment()|processing-instruction()|text()" mode="field-exists" />
    <xsl:template match="*" mode="extract-field">
        <xsl:param name="field" select="''" />
        <xsl:param name="prop" select="concat('v:',$field)" />
        <xsl:variable name="f">
            <xsl:call-template name="testclass">
                <xsl:with-param name="val" select="$field" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:if test="$f != 0">
            <xsl:element name="{$prop}">
                <xsl:value-of select="." />
            </xsl:element>
        </xsl:if>
        <xsl:apply-templates select="*" mode="extract-field">
            <xsl:with-param name="field" select="$field" />
            <xsl:with-param name="prop" select="$prop" />
        </xsl:apply-templates>
    </xsl:template>
    <xsl:template match="comment()|processing-instruction()|text()" mode="extract-field" />
    <xsl:template name="cleanuptel">
        <xsl:param name="value" select="''" />
        <xsl:choose>
            <xsl:when test="starts-with($value, 'tel:')">
                <xsl:value-of select="substring-after($value,'tel:')" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="ch" select="substring($value,1,1)" />
                <xsl:if test="$ch = '0' or $ch = '1' or $ch = '2' or $ch = '3'
                or $ch = '4' or $ch = '5' or $ch = '6' or $ch = '7'
                or $ch = '8' or $ch = '9' or $ch = '-' or $ch = '+'">
                    <xsl:value-of select="$ch" />
                </xsl:if>
                <xsl:if test="string-length($value) &gt; 1">
                    <xsl:call-template name="cleanuptel">
                        <xsl:with-param name="value" select="substring($value,2)" />
                    </xsl:call-template>
                </xsl:if>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="testclass">
        <xsl:param name="class" select="@class" />
        <xsl:param name="val" select="''" />
        <xsl:choose>
            <xsl:when test="$class = $val
            or starts-with($class,concat($val, ' '))
            or contains($class,concat(' ',$val,' '))
            or substring($class, string-length($class)-string-length($val)) = concat(' ',$val)">1</xsl:when>
            <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>
