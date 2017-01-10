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
<!DOCTYPE xsl:stylesheet [
  <!ENTITY CalNS  "http://www.w3.org/2002/12/cal/icaltzd#">
  <!ENTITY XdtNS  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
]>
<xsl:stylesheet
    xmlns:xsl ="http://www.w3.org/1999/XSL/Transform"
    xmlns:c   ="http://www.w3.org/2002/12/cal/icaltzd#"
    xmlns:h   ="http://www.w3.org/1999/xhtml"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:dc="&dc;"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;"
    version="1.0"
    >

    <xsl:output indent="yes" method="xml" />
    <xsl:param name="baseUri" />
	
<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:param name="Source">
	<xsl:choose>
	    <xsl:when test='h:html/h:head/h:link[@rel="base"]'>
		<xsl:value-of select='h:html/h:head/h:link[@rel="base"]/@href' />
	    </xsl:when>
	    <xsl:when test='h:html/h:head/h:base'>
		<xsl:value-of select='h:html/h:head/h:base/@href'/>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:value-of select="$resourceURL"/>
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:param>

    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:if test="//*[contains(concat(' ',normalize-space(@class),' '),' vevent ')] or //*[contains(concat(' ', normalize-space(@class), ' '),' vtodo ')]">
	<rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'hcalendar')}"/>
	</rdf:Description>
		<c:Vcalendar rdf:about="{vi:proxyIRI ($baseUri, '', 'hcalendar')}">
		    <c:prodid>-//connolly.w3.org//palmagent 0.6 (BETA)//EN</c:prodid>
		    <c:version>2.0</c:version>
					<xsl:for-each select=".//*[contains(concat(' ',normalize-space(@class),' '),' vevent ')]">
	    <c:component>
		<c:Vevent>
		    <xsl:call-template name="cal-props" />
		</c:Vevent>
	    </c:component>
					</xsl:for-each>

					<xsl:for-each select=".//*[contains(concat(' ', normalize-space(@class), ' '),' vtodo ')]">
	    <c:component>
		<c:Vtodo>
		    <xsl:call-template name="cal-props" />
		</c:Vtodo>
	    </c:component>
					</xsl:for-each>
				</c:Vcalendar>
	</xsl:if>
		</rdf:RDF>
    </xsl:template>

    <xsl:template name="cal-props">
		<xsl:variable name="summary">
			<xsl:if test=".//*[contains(concat(' ', @class, ' '), concat(' summary '))]">
				<xsl:value-of select="replace(substring(normalize-space(.//*[1][contains(concat(' ', @class, ' '), concat(' summary '))]), 1, 40), ' ' , '')" />
			</xsl:if>
		</xsl:variable>
		<xsl:variable name="dtstart">
			<xsl:if test=".//*[contains(concat(' ', @class, ' '), concat(' dtstart '))]">
				<xsl:choose>
					<xsl:when test=".//*[1][contains(concat(' ', @class, ' '), concat(' dtstart '))]//*[@title]">
						<xsl:value-of select="normalize-space(.//*[1][contains(concat(' ', @class, ' '), concat(' dtstart '))]//*/@title)" />
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="replace(normalize-space(.//*[1][contains(concat(' ', @class, ' '), concat(' dtstart '))]), ' ', '')" />
					</xsl:otherwise>
				</xsl:choose>
	</xsl:if>
		</xsl:variable>

	    <xsl:attribute name="rdf:about">
			<xsl:value-of select="vi:proxyIRI ($baseUri, '', concat($summary, $dtstart))" />
	    </xsl:attribute>
		<rdfs:label><xsl:value-of select="$summary" /></rdfs:label>

	<xsl:call-template name="textProp">
	    <xsl:with-param name="class">uid</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="textProp">
	    <xsl:with-param name="class">summary</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="textProp">
	    <xsl:with-param name="class">description</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="dateProp">
	    <xsl:with-param name="class">dtstart</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="dateProp">
	    <xsl:with-param name="class">dtend</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="durProp">
	    <xsl:with-param name="class">duration</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="refProp">
	    <xsl:with-param name="class">url</xsl:with-param>
	    <xsl:with-param name="default">
		<xsl:choose>
		    <xsl:when test="@id">
			<xsl:value-of select='concat($Source, "#", @id)' />
		    </xsl:when>
		    <xsl:otherwise>
			<xsl:value-of select='$Source' />
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="textProp">
	    <xsl:with-param name="class">location</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="textProp">
	    <xsl:with-param name="class">status</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="floatPairProp">
	    <xsl:with-param name="class">geo</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="recurProp">
	    <xsl:with-param name="class">rrule</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="dateProp">
	    <xsl:with-param name="class">exdate</xsl:with-param>
	</xsl:call-template>

	<xsl:call-template name="whoProp">
	    <xsl:with-param name="class">attendee</xsl:with-param>
	</xsl:call-template>

    </xsl:template>



    <xsl:template name="textProp">
	<xsl:param name="class" />

		<xsl:if test=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))]">
			<xsl:variable name="cur" select=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))][1]" />
	    <xsl:element name="{$class}" namespace="&CalNS;">
		<xsl:choose>
					<xsl:when test='local-name($cur) = "ol" or local-name($cur) = "ul"'>
			<xsl:for-each select="*">
			    <xsl:if test="not(position()=1)">
				<xsl:text>,</xsl:text>
			    </xsl:if>
							<xsl:value-of select="$cur" />
			</xsl:for-each>
		    </xsl:when>
					<xsl:when test='local-name($cur) = "abbr" and $cur/@title'>
						<xsl:value-of select="$cur/@title" />
		    </xsl:when>
		    <xsl:otherwise>
						<xsl:value-of select="$cur" />
		    </xsl:otherwise>
		</xsl:choose>

	    </xsl:element>
		</xsl:if>
    </xsl:template>


    <xsl:template name="lang">
	<xsl:variable name="langElt" select='ancestor-or-self::*[@xml:lang or @lang]' />
	<xsl:if test="$langElt">
	    <xsl:variable name="lang">
		<xsl:choose>
		    <xsl:when test="$langElt/@xml:lang">
			<xsl:value-of select="normalize-space($langElt/@xml:lang)" />
		    </xsl:when>
		    <xsl:when test="$langElt/@lang">
			<xsl:value-of select="normalize-space($langElt/@lang)" />
		    </xsl:when>
		    <xsl:otherwise>
			<xsl:message>where id lang and xml:lang go?!?!?
			</xsl:message>
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:variable>
	    <xsl:attribute name="xml:lang">
		<xsl:value-of select="$lang" />
	    </xsl:attribute>
	</xsl:if>
    </xsl:template>



    <xsl:template name="refProp">
	<xsl:param name="class" />
	<xsl:param name="default" />
	<xsl:choose>
			<xsl:when test=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))]">
				<xsl:variable name="cur" select=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))][1]" />
		    <xsl:variable name="ref">
			<xsl:choose>
						<xsl:when test="$cur/@href">
							<xsl:value-of select="$cur/@href" />
			    </xsl:when>
			    <xsl:otherwise>
							<xsl:value-of select="normalize-space($cur)" />
			    </xsl:otherwise>
			</xsl:choose>
		    </xsl:variable>
				<xsl:element name="{$class}" namespace="&CalNS;">
			<xsl:attribute name="rdf:resource">
			    <xsl:value-of select="$ref" />
			</xsl:attribute>
		    </xsl:element>
	    </xsl:when>
	    <xsl:when test="$default">
				<xsl:element name="{$class}" namespace="&CalNS;">
		    <xsl:attribute name="rdf:resource">
			<xsl:value-of select="$default" />
		    </xsl:attribute>
		</xsl:element>
	    </xsl:when>
	</xsl:choose>

    </xsl:template>


    <xsl:template name="whoProp">
	<xsl:param name="class" />

		<xsl:if test=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))]">
			<xsl:variable name="cur" select=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))][1]" />
	    <xsl:variable name="mbox">
		<xsl:choose>
					<xsl:when test="$cur/@href">
						<xsl:value-of select="$cur/@href" />
		    </xsl:when>
		    <xsl:otherwise>
						<xsl:value-of select="normalize-space($cur)" />
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:variable>
	    <xsl:variable name="cn">
		<xsl:choose>
					<xsl:when test="$cur/@href">
						<xsl:value-of select="normalize-space($cur)" />
		    </xsl:when>
		    <xsl:otherwise>
			<xsl:value-of select='""'/>
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:variable>

			<xsl:element name="{$class}" namespace="&CalNS;">
		<xsl:attribute name="rdf:parseType">Resource</xsl:attribute>
		<c:calAddress rdf:resource="{$mbox}" />
		<xsl:if test="$cn">
		    <c:cn><xsl:value-of select="$cn"/></c:cn>
		</xsl:if>
	    </xsl:element>
		</xsl:if>
    </xsl:template>


    <xsl:template name="dateProp">
	<xsl:param name="class" />
		<xsl:if test=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))]">
			<xsl:variable name="cur" select=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))][1]" />
			<xsl:element name="{$class}" namespace="&CalNS;">
		<xsl:variable name="when">
		    <xsl:choose>
						<xsl:when test="$cur/*[@class = 'value-title' and @title]">
							<xsl:value-of select="$cur/*[@class = 'value-title'][1]/@title"/>
						</xsl:when>
						<xsl:when test="$cur/@title and $cur/@title != ''">
							<xsl:value-of select="$cur/@title"/>
			</xsl:when>
			<xsl:otherwise>
							<xsl:value-of select="normalize-space($cur)" />
			</xsl:otherwise>
		    </xsl:choose>
		</xsl:variable>

		<xsl:choose>
		    <xsl:when test='contains($when, "Z")'>
			<xsl:attribute name="rdf:datatype">
			    <xsl:value-of select='concat("&XdtNS;", "dateTime")' />
			</xsl:attribute>
			<xsl:value-of select='$when' />
		    </xsl:when>
					<xsl:when test='string-length($when) = string-length("yyyy-mm-ddThh:mm:ss+hhmm")'>
			<xsl:attribute name="rdf:datatype">
			    <xsl:value-of select='concat("&XdtNS;", "dateTime")' />
			</xsl:attribute>
			<xsl:call-template name="timeDelta">
							<xsl:with-param name="year" select='number(substring($when, 1, 4))'/>
							<xsl:with-param name="month" select='number(substring($when, 6, 2))'/>
							<xsl:with-param name="day" select='number(substring($when, 9, 2))'/>
							<xsl:with-param name="hour" select='number(substring($when, 12, 2))'/>
							<xsl:with-param name="minute" select='number(substring($when, 15, 2))'/>
							<xsl:with-param name="hourDelta" select='number(substring($when, 21, 2))'/>
			</xsl:call-template>
		    </xsl:when>
		    <xsl:when test='contains($when, "T")'>
			<xsl:attribute name="rdf:datatype">
			    <xsl:value-of select='concat("&CalNS;", "dateTime")' />
			</xsl:attribute>
			<xsl:value-of select='$when' />
		    </xsl:when>

		    <xsl:otherwise>
			<xsl:attribute name="rdf:datatype">
			    <xsl:value-of select='concat("&XdtNS;", "date")' />
			</xsl:attribute>
			<xsl:value-of select='vi:str2date ($when)' />
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:element>
		</xsl:if>
    </xsl:template>


    <xsl:template name="timeDelta">
	<xsl:param name="year" />
	<xsl:param name="month" />
	<xsl:param name="day" />
	<xsl:param name="hour" />
	<xsl:param name="minute" />

	<xsl:param name="hourDelta" />

	<xsl:variable name="hour2">
	    <xsl:choose>
		<xsl:when test="$hour + $hourDelta &gt; 23">
		    <xsl:value-of select="$hour + $hourDelta - 24" />
		</xsl:when>
		<xsl:when test="$hour + $hourDelta &lt; 0">
		    <xsl:value-of select="$hour + $hourDelta + 24" />
		</xsl:when>
		<xsl:otherwise>
		    <xsl:value-of select="$hour + $hourDelta" />
		</xsl:otherwise>
	    </xsl:choose>
	</xsl:variable>

	<xsl:variable name="dayDelta">
	    <xsl:choose>
		<xsl:when test="$hour + $hourDelta &gt; 23">
		    <xsl:value-of select="1" />
		</xsl:when>
		<xsl:when test="$hour + $hourDelta &lt; 0">
		    <xsl:value-of select="-1" />
		</xsl:when>
		<xsl:otherwise>
		    <xsl:value-of select="0" />
		</xsl:otherwise>
	    </xsl:choose>
	</xsl:variable>

	<xsl:variable name="maxd">
	    <xsl:call-template name="max-days">
		<xsl:with-param name="y" select="$year"/>
		<xsl:with-param name="m" select="$month"/>
	    </xsl:call-template>
	</xsl:variable>

	<xsl:variable name="day2">
	    <xsl:choose>
		<xsl:when test="$day + $dayDelta &gt; $maxd">
		    <xsl:value-of select="1" />
		</xsl:when>

		<xsl:when test="$day + $dayDelta &lt; 0">
		    <xsl:call-template name="max-days">
			<xsl:with-param name="y" select="$year"/>
			<xsl:with-param name="m" select="$month - 1"/>
		    </xsl:call-template>
		</xsl:when>

		<xsl:otherwise>
		    <xsl:value-of select="$day + $dayDelta" />
		</xsl:otherwise>
	    </xsl:choose>
	</xsl:variable>

	<xsl:variable name="monthDelta">
	    <xsl:choose>
		<xsl:when test="$day + $dayDelta &gt; $maxd">
		    <xsl:value-of select="1" />
		</xsl:when>
		<xsl:when test="$day + $dayDelta &lt; 0">
		    <xsl:value-of select="-1" />
		</xsl:when>
		<xsl:otherwise>
		    <xsl:value-of select="0" />
		</xsl:otherwise>
	    </xsl:choose>
	</xsl:variable>

	<xsl:variable name="month2">
	    <xsl:choose>
		<xsl:when test="$month + $monthDelta &gt; 12">
		    <xsl:value-of select="1" />
		</xsl:when>

		<xsl:when test="$month + $monthDelta &lt; 0">
		    <xsl:value-of select="12" />
		</xsl:when>

		<xsl:otherwise>
		    <xsl:value-of select="$month + $monthDelta" />
		</xsl:otherwise>
	    </xsl:choose>
	</xsl:variable>

	<xsl:variable name="yearDelta">
	    <xsl:choose>
		<xsl:when test="$month + $monthDelta &gt; 12">
		    <xsl:value-of select="1" />
		</xsl:when>

		<xsl:when test="$month + $monthDelta &lt; 0">
		    <xsl:value-of select="-1" />
		</xsl:when>

		<xsl:otherwise>
		    <xsl:value-of select="0" />
		</xsl:otherwise>
	    </xsl:choose>
	</xsl:variable>

	<xsl:variable name="year2">
	    <xsl:value-of select="$year + $yearDelta" />
	</xsl:variable>

	<xsl:value-of select='concat(format-number($year2, "0000"), "-",
	    format-number($month2, "00"), "-",
	    format-number($day2, "00"), "T",
	    format-number($hour2, "00"), ":",
	    format-number($minute, "00"), ":00Z")' />

    </xsl:template>


    <xsl:template name="max-days">
	<xsl:param name="y"/>
	<xsl:param name="m"/>

	<xsl:choose>
	    <xsl:when test='$m = 1 or $m = 3 or $m = 5 or $m = 7 or
		$m = 8 or $m = 10 or $m = 12'>
		<xsl:value-of select="31" />
	    </xsl:when>

	    <xsl:when test='$m = 2'>
		<xsl:value-of select="28" />
	    </xsl:when>

	    <xsl:otherwise>
		<xsl:value-of select="30" />
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:template>

    <xsl:template name="durProp">
	<xsl:param name="class" />

	<xsl:if test=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))]">
		<xsl:variable name="cur" select=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))][1]" />
	    <xsl:element name="{$class}" namespace="&CalNS;">
		<xsl:choose>
		    <xsl:when test='local-name($cur) = "abbr" and $cur/@title'>
			<xsl:value-of select="$cur/@title" />
		    </xsl:when>
		    <xsl:otherwise>
			<xsl:value-of select='normalize-space($cur)' />
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:element>
	</xsl:if>
    </xsl:template>

    <xsl:template name="floatPairProp">
	<xsl:param name="class" />

	<xsl:if test=".//*[ contains(concat(' ', @class, ' '), concat(' ', $class, ' '))]">
		<xsl:variable name="cur" select=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))][1]" />
	    <xsl:variable name="xy">
		<xsl:choose>
		    <xsl:when test='local-name($cur) = "abbr" and $cur/@title'>
			<xsl:value-of select="$cur/@title" />
		    </xsl:when>

		    <xsl:otherwise>
			<xsl:value-of select="$cur" />
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:variable>

	    <xsl:variable name="x" select='substring-before($xy, ";")' />
	    <xsl:variable name="y" select='substring-after($xy, ";")' />

	    <xsl:element name="{$class}"
		namespace="&CalNS;">
		<xsl:attribute name="rdf:parseType">Resource</xsl:attribute>

		<rdf:first rdf:datatype="http://www.w3.org/2001/XMLSchema#double">
		    <xsl:value-of select="$x" />
		</rdf:first>

		<rdf:rest rdf:parseType="Resource">
		    <rdf:first rdf:datatype="http://www.w3.org/2001/XMLSchema#double">
			<xsl:value-of select="$y" />
		    </rdf:first>
		    <rdf:rest rdf:resource="http://www.w3.org/1999/02/22-rdf-syntax-ns#nil" />
		</rdf:rest>
	    </xsl:element>
	</xsl:if>
    </xsl:template>


    <xsl:template name="recurProp">
	<xsl:param name="class" />

	<xsl:if test=".//*[contains(concat(' ', @class, ' '),concat(' ', $class, ' '))]">
		<xsl:variable name="cur" select=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))][1]" />
	    <xsl:element name="{$class}"
		namespace="&CalNS;">
		<xsl:attribute name="rdf:parseType">Resource</xsl:attribute>
		<xsl:call-template name="sub-prop">
		    <xsl:with-param name="ln" select='"freq"' />
		</xsl:call-template>

		<xsl:call-template name="sub-prop">
		    <xsl:with-param name="ln" select='"interval"' />
		</xsl:call-template>

		<xsl:call-template name="sub-prop">
		    <xsl:with-param name="ln" select='"byday"' />
		</xsl:call-template>

		<xsl:call-template name="sub-prop">
		    <xsl:with-param name="ln" select='"bymonthday"' />
		</xsl:call-template>

		<xsl:call-template name="sub-prop">
		    <xsl:with-param name="ln" select='"until"' />
		</xsl:call-template>

	    </xsl:element>
	</xsl:if>
    </xsl:template>

    <xsl:template name="sub-prop">
	<xsl:param name="ln" />
	<xsl:variable name="v">
	    <xsl:call-template name="class-value">
		<xsl:with-param name="class" select="$ln" />
	    </xsl:call-template>
	</xsl:variable>

	<xsl:if test="string-length($v) &gt; 0">
	    <xsl:element name="{$ln}" namespace="&CalNS;">
		<xsl:value-of select="$v" />
	    </xsl:element>
	</xsl:if>
    </xsl:template>

    <xsl:template name="class-value">
	<xsl:param name="class" />

	<xsl:value-of	select="descendant-or-self::*[
	    contains(concat(' ', @class, ' '),
	    concat(' ', $class, ' '))]" />
    </xsl:template>

    <xsl:template match="text()" />
</xsl:stylesheet>
