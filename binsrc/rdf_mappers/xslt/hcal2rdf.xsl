<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
]>
<xsl:stylesheet
    xmlns:xsl ="http://www.w3.org/1999/XSL/Transform"
    xmlns:r   ="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:c   ="http://www.w3.org/2002/12/cal/icaltzd#"
    xmlns:h   ="http://www.w3.org/1999/xhtml"
    xmlns:xml   ="xml"
    version="1.0"
    >

    <xsl:output indent="yes" method="xml" />
    <xsl:param name="baseUri" />
    <xsl:param name="Source">
	<xsl:choose>
	    <xsl:when test='h:html/h:head/h:link[@rel="base"]'>
		<xsl:value-of select='h:html/h:head/h:link[@rel="base"]/@href' />
	    </xsl:when>
	    <xsl:when test='h:html/h:head/h:base'>
		<xsl:value-of select='h:html/h:head/h:base/@href'/>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:value-of select="$baseUri"/>
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:param>

    <xsl:param name="Anchor" />

    <xsl:template match="/">
	<r:RDF>
	    <xsl:if test="//*[contains(concat(' ',normalize-space(@class),' '),' vevent ')] or //*[contains(concat(' ', normalize-space(@class), ' '),' vtodo ')]">
		<c:Vcalendar r:about="{$baseUri}">
		    <c:prodid>-//connolly.w3.org//palmagent 0.6 (BETA)//EN</c:prodid>
		    <c:version>2.0</c:version>
		    <xsl:apply-templates />
		</c:Vcalendar>
	    </xsl:if>
	</r:RDF>
    </xsl:template>


    <xsl:template match="*[contains(concat(' ',normalize-space(@class),' '),' vevent ')]">
	<xsl:if test="not($Anchor) or @id = $Anchor">
	    <c:component>
		<c:Vevent>

		    <xsl:call-template name="cal-props" />

		</c:Vevent>
	    </c:component>
	</xsl:if>
    </xsl:template>

    <xsl:template match="*[contains(concat(' ', normalize-space(@class), ' '),' vtodo ')]">
	<xsl:if test="not($Anchor) or @id = $Anchor">
	    <c:component>
		<c:Vtodo>
		    <xsl:call-template name="cal-props" />
		</c:Vtodo>
	    </c:component>
	</xsl:if>
    </xsl:template>

    <xsl:template name="cal-props">
	<xsl:if test="@id and $Source">
	    <xsl:attribute name="r:about">
		<xsl:value-of select='concat($Source, "#", @id)' />
	    </xsl:attribute>
	</xsl:if>

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

	<xsl:for-each select=".//*[contains(concat(' ', @class, ' '), concat(' ', $class, ' '))]">
	    <xsl:element name="{$class}" namespace="&CalNS;">
		<xsl:call-template name="lang" />

		<xsl:choose>
		    <xsl:when test='local-name(.) = "ol" or local-name(.) = "ul"'>
			<xsl:for-each select="*">
			    <xsl:if test="not(position()=1)">
				<xsl:text>,</xsl:text>
			    </xsl:if>

			    <xsl:value-of select="." />
			</xsl:for-each>
		    </xsl:when>

		    <xsl:when test='local-name(.) = "abbr" and @title'>
			<xsl:value-of select="@title" />
		    </xsl:when>

		    <xsl:otherwise>
			<xsl:value-of select="." />
		    </xsl:otherwise>
		</xsl:choose>

	    </xsl:element>
	</xsl:for-each>
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
	    <xsl:when test=".//*[
		contains(concat(' ', @class, ' '),
		concat(' ', $class, ' '))]">

		<xsl:for-each select=".//*[
		    contains(concat(' ', @class, ' '),
		    concat(' ', $class, ' '))]">
		    <xsl:variable name="ref">
			<xsl:choose>
			    <xsl:when test="@href">
				<xsl:value-of select="@href" />
			    </xsl:when>

			    <xsl:otherwise>
				<xsl:value-of select="normalize-space(.)" />
			    </xsl:otherwise>
			</xsl:choose>
		    </xsl:variable>

		    <xsl:element name="{$class}"
			namespace="&CalNS;">
			<xsl:attribute name="r:resource">
			    <xsl:value-of select="$ref" />
			</xsl:attribute>
		    </xsl:element>

		</xsl:for-each>
	    </xsl:when>

	    <xsl:when test="$default">
		<xsl:element name="{$class}"
		    namespace="&CalNS;">
		    <xsl:attribute name="r:resource">
			<xsl:value-of select="$default" />
		    </xsl:attribute>
		</xsl:element>
	    </xsl:when>
	</xsl:choose>

    </xsl:template>


    <xsl:template name="whoProp">
	<xsl:param name="class" />

	<xsl:for-each select=".//*[
	    contains(concat(' ', @class, ' '),
	    concat(' ', $class, ' '))]">
	    <xsl:variable name="mbox">
		<xsl:choose>
		    <xsl:when test="@href">
			<xsl:value-of select="@href" />
		    </xsl:when>

		    <xsl:otherwise>
			<xsl:value-of select="normalize-space(.)" />
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:variable>

	    <xsl:variable name="cn">
		<xsl:choose>
		    <xsl:when test="@href">
			<xsl:value-of select="normalize-space(.)" />
		    </xsl:when>

		    <xsl:otherwise>
			<xsl:value-of select='""'/>
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:variable>

	    <xsl:element name="{$class}"
		namespace="&CalNS;">
		<xsl:attribute name="r:parseType">Resource</xsl:attribute>
		<c:calAddress r:resource="{$mbox}" />
		<xsl:if test="$cn">
		    <c:cn><xsl:value-of select="$cn"/></c:cn>
		</xsl:if>
	    </xsl:element>

	</xsl:for-each>

    </xsl:template>


    <xsl:template name="dateProp">
	<xsl:param name="class" />

	<xsl:for-each select=".//*[
	    contains(concat(' ', @class, ' '),
	    concat(' ', $class, ' '))]">
	    <xsl:element name="{$class}"
		namespace="&CalNS;">

		<xsl:variable name="when">
		    <xsl:choose>
			<xsl:when test="@title">
			    <xsl:value-of select="@title">
			    </xsl:value-of>
			</xsl:when>
			<xsl:otherwise>
			    <xsl:value-of select="normalize-space(.)" />
			</xsl:otherwise>
		    </xsl:choose>
		</xsl:variable>

		<xsl:choose>
		    <xsl:when test='contains($when, "Z")'>
			<xsl:attribute name="r:datatype">
			    <xsl:value-of select='concat("&XdtNS;", "dateTime")' />
			</xsl:attribute>

			<xsl:value-of select='$when' />
		    </xsl:when>

		    <xsl:when test='string-length($when) =
			string-length("yyyy-mm-ddThh:mm:ss+hhmm")'>
			<xsl:attribute name="r:datatype">
			    <xsl:value-of select='concat("&XdtNS;", "dateTime")' />
			</xsl:attribute>
			<xsl:call-template name="timeDelta">
			    <xsl:with-param name="year"
				select='number(substring($when, 1, 4))'/>
			    <xsl:with-param name="month"
				select='number(substring($when, 6, 2))'/>
			    <xsl:with-param name="day"
				select='number(substring($when, 9, 2))'/>
			    <xsl:with-param name="hour"
				select='number(substring($when, 12, 2))'/>
			    <xsl:with-param name="minute"
				select='number(substring($when, 15, 2))'/>

			    <xsl:with-param name="hourDelta"
				select='number(substring($when, 21, 2))'/>
			</xsl:call-template>
		    </xsl:when>

		    <xsl:when test='contains($when, "T")'>
			<xsl:attribute name="r:datatype">
			    <xsl:value-of select='concat("&CalNS;", "dateTime")' />
			</xsl:attribute>
			<xsl:value-of select='$when' />
		    </xsl:when>

		    <xsl:otherwise>
			<xsl:attribute name="r:datatype">
			    <xsl:value-of select='concat("&XdtNS;", "date")' />
			</xsl:attribute>
			<xsl:value-of select='$when' />
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:element>
	</xsl:for-each>
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

	<xsl:for-each select=".//*[
	    contains(concat(' ', @class, ' '),
	    concat(' ', $class, ' '))]">
	    <xsl:element name="{$class}"
		namespace="&CalNS;">

		<xsl:choose>
		    <xsl:when test='local-name(.) = "abbr" and @title'>
			<xsl:value-of select="@title" />
		    </xsl:when>

		    <xsl:otherwise>
			<xsl:value-of select='normalize-space(.)' />
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:element>
	</xsl:for-each>
    </xsl:template>

    <xsl:template name="floatPairProp">
	<xsl:param name="class" />

	<xsl:for-each select=".//*[
	    contains(concat(' ', @class, ' '),
	    concat(' ', $class, ' '))]">

	    <xsl:variable name="xy">
		<xsl:choose>
		    <xsl:when test='local-name(.) = "abbr" and @title'>
			<xsl:value-of select="@title" />
		    </xsl:when>

		    <xsl:otherwise>
			<xsl:value-of select="." />
		    </xsl:otherwise>
		</xsl:choose>
	    </xsl:variable>

	    <xsl:variable name="x" select='substring-before($xy, ";")' />
	    <xsl:variable name="y" select='substring-after($xy, ";")' />

	    <xsl:element name="{$class}"
		namespace="&CalNS;">
		<xsl:attribute name="r:parseType">Resource</xsl:attribute>

		<r:first r:datatype="http://www.w3.org/2001/XMLSchema#double">
		    <xsl:value-of select="$x" />
		</r:first>

		<r:rest r:parseType="Resource">
		    <r:first r:datatype="http://www.w3.org/2001/XMLSchema#double">
			<xsl:value-of select="$y" />
		    </r:first>
		    <r:rest r:resource="http://www.w3.org/1999/02/22-rdf-syntax-ns#nil" />
		</r:rest>
	    </xsl:element>
	</xsl:for-each>
    </xsl:template>


    <xsl:template name="recurProp">
	<xsl:param name="class" />

	<xsl:for-each select=".//*[
	    contains(concat(' ', @class, ' '),
	    concat(' ', $class, ' '))]">
	    <xsl:element name="{$class}"
		namespace="&CalNS;">
		<xsl:attribute name="r:parseType">Resource</xsl:attribute>
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
	</xsl:for-each>
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
