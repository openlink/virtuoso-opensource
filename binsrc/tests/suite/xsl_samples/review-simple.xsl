<?xml version="1.0"?>
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
 -  
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl" xmlns:HTML="http://www.w3.org/Profiles/XHTML-transitional">
  <xsl:template><xsl:apply-templates/></xsl:template>
  <xsl:template match="text()"><xsl:value-of/></xsl:template>
  
  <xsl:template match="/">
    <HTML>
      <HEAD>
        <TITLE><xsl:value-of select="story/restaurant/name"/></TITLE>
        <STYLE>
          BODY       { margin:0px; background-color: #FFFFDD; width: 30em;
                       font-family: Arial, Helvetica, sans-serif; font-size: small; }
          H1         { color: #888833; }
          P          { margin-top: .5em; margin-bottom: .25em; }
          HR         { color: #888833; }
          .address   { text-align: right; font-size: xx-small; margin-top: .25em; }
          .tagline   { font-style: italic; font-size: smaller; text-align: right; }
          .body      { text-align: justify; background-color: #FFFFDD; }
          .dingbat   { font-family: WingDings; font-style: normal; font-size: xx-small; }
          .person    { font-weight: bold; }
          .city      { font-weight: bold; }
          .self      { font-style: italic; }
          #menu      { border: 2px solid black; padding: 1em; background-color: #888833; }
          .menutext  { color: #FFFFDD; font-family: Times, serif; font-style: italic;
                       vertical-align: top; text-align:center; }
          .menuhead  { color: #FFFFDD; font-family: Times, serif; font-weight: bold;
                       vertical-align: top; text-align:center; margin-bottom: .5em; }
        </STYLE>
        <SCRIPT language="JavaScript"><xsl:comment><![CDATA[
          function show() {
            full.style.display="block";
            summary.style.display="none";
          }

          function hide() {
            summary.style.display="block";
            full.style.display="none";
          }

        ]]></xsl:comment></SCRIPT>
      </HEAD>

      <BODY>
        <TABLE WIDTH="580" CELLSPACING="8">
          <TR>
            <TD colspan="2">
              <H1>
                <xsl:apply-templates select="story/restaurant/logo/*"/>
                <xsl:value-of select="story/restaurant/name"/>
              </H1>
            </TD>
          </TR>
          <TR>
            <TD WIDTH="120" VALIGN="top" STYLE="padding-top:2em">
              <P class="address">
                Rating:
                <IMG>
                  <xsl:attribute name="src">rate<xsl:value-of select="story/review/rating/@stars"/>.gif</xsl:attribute>
                  <xsl:attribute name="title">rating: <xsl:value-of select="story/review/rating/@stars"/> stars</xsl:attribute>
                </IMG>
              </P>
              <HR/>
              <xsl:for-each select="story/restaurant">
                <P class="address"><xsl:value-of select="address/street"/></P>
                <P class="address"><xsl:value-of select="address/city"/>, <xsl:value-of select="address/state"/></P>
                <P class="address">Res: <xsl:value-of select="phone"/></P>
              </xsl:for-each>
            </TD>
            <TD class="body">
              <P class="tagline"><xsl:value-of select="story/review/date"/></P>
              <DIV id="summary">
                <P><xsl:apply-templates select="story/body//summary"/></P>
                <P class="tagline">
                  <A href="javascript:show();">View complete review by <B><xsl:value-of select="story/review/reviewer"/></B></A>
                </P>
              </DIV>
              <DIV id="full" STYLE="display:none">
                <xsl:apply-templates select="story/body"/>
                <P class="tagline">Review by <B><xsl:value-of select="story/review/reviewer"/></B>
                  <SPAN class="dingbat">n</SPAN>
                </P>
                <P class="tagline">
                  <A href="javascript:hide();">View summary</A>
                </P>
              </DIV>
              <DIV id="menu">
                <xsl:apply-templates select="story/menu"/>
              </DIV>
            </TD>
          </TR>
        </TABLE>
        
        <P/>
      </BODY>
    </HTML>
  </xsl:template>
  
  <xsl:template match="p">
    <P><xsl:apply-templates/></P>
  </xsl:template>

  <xsl:template match="person">
    <SPAN class="person"><xsl:apply-templates/></SPAN>
  </xsl:template>

  <xsl:template match="city">
    <SPAN class="city"><xsl:apply-templates/></SPAN>
  </xsl:template>

  <xsl:template match="self">
    <SPAN class="self"><xsl:apply-templates/></SPAN>
  </xsl:template>

  <xsl:template match="menu">
    <DIV class="menuhead">Menu selections from the <I><xsl:value-of select="/story/restaurant/name"/></I></DIV>
    <TABLE CELLSPACING="0">
      <TR><TD class="menuhead">Appetizers</TD></TR>
      <xsl:apply-templates select="appetizer"><xsl:sort select="description"/></xsl:apply-templates>
      <TR>
        <TD class="menuhead"><DIV class="dingbat">u u u</DIV>Entrees</TD>
      </TR>
      <xsl:apply-templates select="entree"><xsl:sort select=description" /></xsl:apply-templates>
    </TABLE>
  </xsl:template>

  <xsl:template match="appetizer | entree">
    <TR>
      <TD class="menutext"><xsl:value-of select="description"/></TD>
      <TD class="menutext" VALIGN="bottom"><xsl:value-of select="price"/></TD>
    </TR>
  </xsl:template>

  <xsl:template match="HTML:A">
    <A><xsl:apply-templates select="@*"/><xsl:apply-templates select="*"/></A>
  </xsl:template>
  
  <xsl:template match="HTML:IMG">
    <IMG ALIGN="right"><xsl:apply-templates select="@*"/><xsl:apply-templates select="*"/></IMG>
  </xsl:template>

  <xsl:template match="@*">
    <xsl:copy><xsl:value-of/></xsl:copy>
  </xsl:template>

</xsl:stylesheet>
