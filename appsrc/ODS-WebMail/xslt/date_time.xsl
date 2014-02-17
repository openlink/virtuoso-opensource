<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
 -
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:dt="http://xsltsl.org/date-time">
  <!-- ================================================== -->
  <xsl:template name="dt:format-date-time">
    <xsl:param name="year"/>
    <xsl:param name="month"/>
    <xsl:param name="day"/>
    <xsl:param name="hour"/>
    <xsl:param name="minute"/>
    <xsl:param name="second"/>
    <xsl:param name="time-zone"/>
    <xsl:param name="format" select="'%Y-%m-%dT%H:%M:%S%z'"/>
    <xsl:value-of select="substring-before($format, '%')"/>
    <xsl:variable name="code" select="substring(substring-after($format, '%'), 1, 1)"/>
    <xsl:choose>
      <!-- Abbreviated weekday name with only two letters (added by Bombata) -->
      <xsl:when test="$code='O'">
        <xsl:variable name="day-of-the-week">
          <xsl:call-template name="dt:calculate-day-of-the-week">
            <xsl:with-param name="year" select="$year"/>
            <xsl:with-param name="month" select="$month"/>
            <xsl:with-param name="day" select="$day"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:call-template name="dt:get-day-of-the-week-abbrev">
          <xsl:with-param name="day-of-the-week" select="$day-of-the-week"/>
        </xsl:call-template>
      </xsl:when>
      <!-- Abbreviated weekday name -->
      <xsl:when test="$code='a'">
        <xsl:variable name="day-of-the-week">
          <xsl:call-template name="dt:calculate-day-of-the-week">
            <xsl:with-param name="year" select="$year"/>
            <xsl:with-param name="month" select="$month"/>
            <xsl:with-param name="day" select="$day"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:call-template name="dt:get-day-of-the-week-abbreviation">
          <xsl:with-param name="day-of-the-week" select="$day-of-the-week"/>
        </xsl:call-template>
      </xsl:when>
      <!-- Full weekday name -->
      <xsl:when test="$code='A'">
        <xsl:variable name="day-of-the-week">
          <xsl:call-template name="dt:calculate-day-of-the-week">
            <xsl:with-param name="year" select="$year"/>
            <xsl:with-param name="month" select="$month"/>
            <xsl:with-param name="day" select="$day"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:call-template name="dt:get-day-of-the-week-name">
          <xsl:with-param name="day-of-the-week" select="$day-of-the-week"/>
        </xsl:call-template>
      </xsl:when>
      <!-- Abbreviated month name -->
      <xsl:when test="$code='b'">
        <xsl:call-template name="dt:get-month-abbreviation">
          <xsl:with-param name="month" select="$month"/>
        </xsl:call-template>
      </xsl:when>
      <!-- Full month name -->
      <xsl:when test="$code='B'">
        <xsl:call-template name="dt:get-month-name">
          <xsl:with-param name="month" select="$month"/>
        </xsl:call-template>
      </xsl:when>
      <!-- Date and time representation appropriate for locale -->
      <xsl:when test="$code='c'">
        <xsl:text>[not implemented]</xsl:text>
      </xsl:when>
      <!-- Day of month as decimal number (01 - 31) -->
      <xsl:when test="$code='d'">
        <xsl:if test="$day &lt; 10">0</xsl:if>
        <xsl:value-of select="number($day)"/>
      </xsl:when>
      <!-- Hour in 24-hour format (00 - 23) -->
      <xsl:when test="$code='H'">
        <xsl:if test="$hour &lt; 10">0</xsl:if>
        <xsl:value-of select="number($hour)"/>
      </xsl:when>
      <!-- Hour in 12-hour format (01 - 12) -->
      <xsl:when test="$code='I'">
        <xsl:choose>
          <xsl:when test="$hour = 0">12</xsl:when>
          <xsl:when test="$hour &lt; 10">0<xsl:value-of select="$hour - 0"/>
          </xsl:when>
          <xsl:when test="$hour &lt; 13">
            <xsl:value-of select="$hour - 0"/>
          </xsl:when>
          <xsl:when test="$hour &lt; 22">0<xsl:value-of select="$hour - 12"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$hour - 12"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- Day of year as decimal number (001 - 366) -->
      <xsl:when test="$code='j'">
        <xsl:text>[not implemented]</xsl:text>
      </xsl:when>
      <!-- Month as decimal number (01 - 12) -->
      <xsl:when test="$code='m'">
        <xsl:if test="$month &lt; 10">0</xsl:if>
        <xsl:value-of select="number($month)"/>
      </xsl:when>
      <!-- Minute as decimal number (00 - 59) -->
      <xsl:when test="$code='M'">
        <xsl:if test="$minute &lt; 10">0</xsl:if>
        <xsl:value-of select="number($minute)"/>
      </xsl:when>
      <!-- Current locale's A.M./P.M. indicator for 12-hour clock -->
      <xsl:when test="$code='p'">
        <xsl:choose>
          <xsl:when test="$hour &lt; 12">AM</xsl:when>
          <xsl:otherwise>PM</xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- Second as decimal number (00 - 59) -->
      <xsl:when test="$code='S'">
        <xsl:if test="$second &lt; 10">0</xsl:if>
        <xsl:value-of select="number($second)"/>
      </xsl:when>
      <!-- Week of year as decimal number, with Sunday as first day of week (00 - 53) -->
      <xsl:when test="$code='U'">
        <!-- add 1 to day -->
        <xsl:call-template name="dt:calculate-week-number">
          <xsl:with-param name="year" select="$year"/>
          <xsl:with-param name="month" select="$month"/>
          <xsl:with-param name="day" select="$day + 1"/>
        </xsl:call-template>
      </xsl:when>
      <!-- Weekday as decimal number (0 - 6; Sunday is 0) -->
      <xsl:when test="$code='w'">
        <xsl:call-template name="dt:calculate-day-of-the-week">
          <xsl:with-param name="year" select="$year"/>
          <xsl:with-param name="month" select="$month"/>
          <xsl:with-param name="day" select="$day"/>
        </xsl:call-template>
      </xsl:when>
      <!-- Week of year as decimal number, with Monday as first day of week (00 - 53) -->
      <xsl:when test="$code='W'">
        <xsl:call-template name="dt:calculate-week-number">
          <xsl:with-param name="year" select="$year"/>
          <xsl:with-param name="month" select="$month"/>
          <xsl:with-param name="day" select="$day"/>
        </xsl:call-template>
      </xsl:when>
      <!-- Date representation for current locale -->
      <xsl:when test="$code='x'">
        <xsl:text>[not implemented]</xsl:text>
      </xsl:when>
      <!-- Time representation for current locale -->
      <xsl:when test="$code='X'">
        <xsl:text>[not implemented]</xsl:text>
      </xsl:when>
      <!-- Year without century, as decimal number (00 - 99) -->
      <xsl:when test="$code='y'">
        <xsl:text>[not implemented]</xsl:text>
      </xsl:when>
      <!-- Year with century, as decimal number -->
      <xsl:when test="$code='Y'">
        <xsl:value-of select="concat(substring('000', string-length(number($year))), $year)"/>
      </xsl:when>
      <!-- Time-zone name or abbreviation; no characters if time zone is unknown -->
      <xsl:when test="$code='z'">
        <xsl:value-of select="$time-zone"/>
      </xsl:when>
      <!-- Percent sign -->
      <xsl:when test="$code='%'">
        <xsl:text>%</xsl:text>
      </xsl:when>
    </xsl:choose>
    <xsl:variable name="remainder" select="substring(substring-after($format, '%'), 2)"/>
    <xsl:if test="$remainder">
      <xsl:call-template name="dt:format-date-time">
        <xsl:with-param name="year" select="$year"/>
        <xsl:with-param name="month" select="$month"/>
        <xsl:with-param name="day" select="$day"/>
        <xsl:with-param name="hour" select="$hour"/>
        <xsl:with-param name="minute" select="$minute"/>
        <xsl:with-param name="second" select="$second"/>
        <xsl:with-param name="time-zone" select="$time-zone"/>
        <xsl:with-param name="format" select="$remainder"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>
  <!-- ================================================== -->
  <xsl:template name="dt:calculate-day-of-the-week">
    <xsl:param name="year"/>
    <xsl:param name="month"/>
    <xsl:param name="day"/>
    <xsl:variable name="a" select="floor((14 - $month) div 12)"/>
    <xsl:variable name="y" select="$year - $a"/>
    <xsl:variable name="m" select="$month + 12 * $a - 2"/>
    <xsl:value-of select="($day + $y + floor($y div 4) - floor($y div 100) + floor($y div 400) + floor((31 * $m) div 12)) mod 7"/>
  </xsl:template>
  <!-- ================================================== -->
  <xsl:template name="dt:get-day-of-the-week-name">
    <xsl:param name="day-of-the-week"/>
    <xsl:choose>
      <xsl:when test="$day-of-the-week = 0">Sunday</xsl:when>
      <xsl:when test="$day-of-the-week = 1">Monday</xsl:when>
      <xsl:when test="$day-of-the-week = 2">Tuesday</xsl:when>
      <xsl:when test="$day-of-the-week = 3">Wednesday</xsl:when>
      <xsl:when test="$day-of-the-week = 4">Thursday</xsl:when>
      <xsl:when test="$day-of-the-week = 5">Friday</xsl:when>
      <xsl:when test="$day-of-the-week = 6">Saturday</xsl:when>
      <xsl:otherwise>error: <xsl:value-of select="$day-of-the-week"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ================================================== -->
  <xsl:template name="dt:get-day-of-the-week-abbreviation">
    <xsl:param name="day-of-the-week"/>
    <xsl:choose>
      <xsl:when test="$day-of-the-week = 0">Sun</xsl:when>
      <xsl:when test="$day-of-the-week = 1">Mon</xsl:when>
      <xsl:when test="$day-of-the-week = 2">Tue</xsl:when>
      <xsl:when test="$day-of-the-week = 3">Wed</xsl:when>
      <xsl:when test="$day-of-the-week = 4">Thu</xsl:when>
      <xsl:when test="$day-of-the-week = 5">Fri</xsl:when>
      <xsl:when test="$day-of-the-week = 6">Sat</xsl:when>
      <xsl:otherwise>error: <xsl:value-of select="$day-of-the-week"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ================================================== (added by Bombata) -->
  <xsl:template name="dt:get-day-of-the-week-abbrev">
    <xsl:param name="day-of-the-week"/>
    <xsl:choose>
      <xsl:when test="$day-of-the-week = 0">Su</xsl:when>
      <xsl:when test="$day-of-the-week = 1">Mo</xsl:when>
      <xsl:when test="$day-of-the-week = 2">Tu</xsl:when>
      <xsl:when test="$day-of-the-week = 3">We</xsl:when>
      <xsl:when test="$day-of-the-week = 4">Th</xsl:when>
      <xsl:when test="$day-of-the-week = 5">Fr</xsl:when>
      <xsl:when test="$day-of-the-week = 6">Sa</xsl:when>
      <xsl:otherwise>error: <xsl:value-of select="$day-of-the-week"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ================================================== -->
  <xsl:template name="dt:get-month-name">
    <xsl:param name="month"/>
    <xsl:choose>
      <xsl:when test="$month = 1">January</xsl:when>
      <xsl:when test="$month = 2">February</xsl:when>
      <xsl:when test="$month = 3">March</xsl:when>
      <xsl:when test="$month = 4">April</xsl:when>
      <xsl:when test="$month = 5">May</xsl:when>
      <xsl:when test="$month = 6">June</xsl:when>
      <xsl:when test="$month = 7">July</xsl:when>
      <xsl:when test="$month = 8">August</xsl:when>
      <xsl:when test="$month = 9">September</xsl:when>
      <xsl:when test="$month = 10">October</xsl:when>
      <xsl:when test="$month = 11">November</xsl:when>
      <xsl:when test="$month = 12">December</xsl:when>
      <xsl:otherwise>error: <xsl:value-of select="$month"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ================================================== -->
  <xsl:template name="dt:get-month-abbreviation">
    <xsl:param name="month"/>
    <xsl:choose>
      <xsl:when test="$month = 1">Jan</xsl:when>
      <xsl:when test="$month = 2">Feb</xsl:when>
      <xsl:when test="$month = 3">Mar</xsl:when>
      <xsl:when test="$month = 4">Apr</xsl:when>
      <xsl:when test="$month = 5">May</xsl:when>
      <xsl:when test="$month = 6">Jun</xsl:when>
      <xsl:when test="$month = 7">Jul</xsl:when>
      <xsl:when test="$month = 8">Aug</xsl:when>
      <xsl:when test="$month = 9">Sep</xsl:when>
      <xsl:when test="$month = 10">Oct</xsl:when>
      <xsl:when test="$month = 11">Nov</xsl:when>
      <xsl:when test="$month = 12">Dec</xsl:when>
      <xsl:otherwise>error: <xsl:value-of select="$month"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ================================================== -->
  <xsl:template name="dt:calculate-julian-day">
    <xsl:param name="year"/>
    <xsl:param name="month"/>
    <xsl:param name="day"/>
    <xsl:variable name="a" select="floor((14 - $month) div 12)"/>
    <xsl:variable name="y" select="$year + 4800 - $a"/>
    <xsl:variable name="m" select="$month + 12 * $a - 3"/>
    <xsl:value-of select="$day + floor((153 * $m + 2) div 5) + $y * 365 + floor($y div 4) - floor($y div 100) + floor($y div 400) - 32045"/>
  </xsl:template>
  <!-- ================================================== -->
  <xsl:template name="dt:format-julian-day">
    <xsl:param name="julian-day"/>
    <xsl:param name="format" select="'%Y-%m-%d'"/>
    <xsl:variable name="a" select="$julian-day + 32044"/>
    <xsl:variable name="b" select="floor((4 * $a + 3) div 146097)"/>
    <xsl:variable name="c" select="$a - floor(($b * 146097) div 4)"/>
    <xsl:variable name="d" select="floor((4 * $c + 3) div 1461)"/>
    <xsl:variable name="e" select="$c - floor((1461 * $d) div 4)"/>
    <xsl:variable name="m" select="floor((5 * $e + 2) div 153)"/>
    <xsl:variable name="day" select="$e - floor((153 * $m + 2) div 5) + 1"/>
    <xsl:variable name="month" select="$m + 3 - 12 * floor($m div 10)"/>
    <xsl:variable name="year" select="$b * 100 + $d - 4800 + floor($m div 10)"/>
    <xsl:call-template name="dt:format-date-time">
      <xsl:with-param name="year" select="$year"/>
      <xsl:with-param name="month" select="$month"/>
      <xsl:with-param name="day" select="$day"/>
      <xsl:with-param name="format" select="$format"/>
    </xsl:call-template>
  </xsl:template>
  <!-- ================================================== -->
  <xsl:template name="dt:calculate-week-number">
    <xsl:param name="year"/>
    <xsl:param name="month"/>
    <xsl:param name="day"/>
    <xsl:variable name="J">
      <xsl:call-template name="dt:calculate-julian-day">
        <xsl:with-param name="year" select="$year"/>
        <xsl:with-param name="month" select="$month"/>
        <xsl:with-param name="day" select="$day"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="d4" select="($J + 31741 - ($J mod 7)) mod 146097 mod 36524 mod 1461"/>
    <xsl:variable name="L" select="floor($d4 div 1460)"/>
    <xsl:variable name="d1" select="(($d4 - $L) mod 365) + $L"/>
    <xsl:value-of select="floor($d1 div 7) + 1"/>
  </xsl:template>
  <!-- ================================================== -->
</xsl:stylesheet>
