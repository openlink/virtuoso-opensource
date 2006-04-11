<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xt="http://www.jclark.com/xt"
		version="1.0"
                extension-element-prefixes="xt">

<xsl:import href="../html/xtchunk.xsl"/>
<xsl:output method="html"/>

<!-- ********************************************************************
     $Id$
     ********************************************************************

     This file is part of the XSL DocBook Stylesheet distribution.
     See ../README or http://nwalsh.com/docbook/xsl/ for copyright
     and other information.

     ******************************************************************** -->

<!-- ==================================================================== -->

<xsl:template match="/">
  <xsl:apply-templates/>
  <xsl:call-template name="helpset"/>
  <xsl:call-template name="helptoc"/>
  <xsl:call-template name="helpmap"/>
  <xsl:call-template name="helpidx"/>
</xsl:template>

<xsl:template name="header.navigation">
</xsl:template>

<xsl:template name="footer.navigation">
</xsl:template>

<!-- ==================================================================== -->

<xsl:template name="helpset">
  <xt:document href="jhelpset.hs"
    method="xml"
    doctype-public="-//Sun Microsystems Inc.//DTD JavaHelp HelpSet Version 1.0//EN"
    doctype-system="http://java.sun.com/products/javahelp/helpset_1_0.dtd"
    indent="yes">
    <helpset version="1.0">
      <title>
	<xsl:apply-templates select="." mode="title.ref">
	  <xsl:with-param name="text-only" select="true()"/>
	</xsl:apply-templates>
      </title>

      <!-- maps -->
      <maps>
	<homeID>top</homeID>
	<mapref location="jhelpmap.jhm"/>
      </maps>

      <!-- views -->
      <view>
	<name>TOC</name>
	<label>Table Of Contents</label>
	<type>javax.help.TOCView</type>
	<data>jhelptoc.xml</data>
      </view>

      <view>
	<name>Index</name>
	<label>Index</label>
	<type>javax.help.IndexView</type>
	<data>jhelpidx.xml</data>
      </view>

      <view>
	<name>Search</name>
	<label>Search</label>
	<type>javax.help.SearchView</type>
	<data engine="com.sun.java.help.search.DefaultSearchEngine">JavaHelpSearch</data>
      </view>
    </helpset>
  </xt:document>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template name="helptoc">
  <xt:document href="jhelptoc.xml"
    method="xml"
    doctype-public="-//Sun Microsystems Inc.//DTD JavaHelp TOC Version 1.0//EN"
    doctype-system="http://java.sun.com/products/javahelp/toc_1_0.dtd"
    indent="yes">
    <toc version="1.0">
      <xsl:apply-templates select="." mode="toc"/>
    </toc>
  </xt:document>
</xsl:template>

<xsl:template match="set" mode="toc">
  <xsl:variable name="id">
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select="$object"/>
    </xsl:call-template>
  </xsl:variable>

  <tocitem target="{$id}">
    <xsl:attribute name="text">
      <xsl:apply-templates select="." mode="title.ref">
	<xsl:with-param name="text-only" select="true()"/>
      </xsl:apply-templates>
    </xsl:attribute>
    <xsl:apply-templates select="book" mode="toc"/>
  </tocitem>
</xsl:template>

<xsl:template match="book" mode="toc">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <tocitem target="{$id}">
    <xsl:attribute name="text">
      <xsl:apply-templates select="." mode="title.ref">
	<xsl:with-param name="text-only" select="true()"/>
      </xsl:apply-templates>
    </xsl:attribute>
    <xsl:apply-templates select="part|reference|preface|chapter|appendix"
                         mode="toc"/>
  </tocitem>
</xsl:template>

<xsl:template match="part|reference|preface|chapter|appendix"
              mode="toc">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <tocitem target="{$id}">
    <xsl:attribute name="text">
      <xsl:apply-templates select="." mode="title.ref">
	<xsl:with-param name="text-only" select="true()"/>
      </xsl:apply-templates>
    </xsl:attribute>
    <xsl:apply-templates
      select="preface|chapter|appendix|refentry|section|sect1"
      mode="toc"/>
  </tocitem>
</xsl:template>

<xsl:template match="section" mode="toc">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <tocitem target="{$id}">
    <xsl:attribute name="text">
      <xsl:apply-templates select="." mode="title.ref">
	<xsl:with-param name="text-only" select="true()"/>
      </xsl:apply-templates>
    </xsl:attribute>
    <xsl:apply-templates select="section" mode="toc"/>
  </tocitem>
</xsl:template>

<xsl:template match="sect1" mode="toc">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <tocitem target="{$id}">
    <xsl:attribute name="text">
      <xsl:apply-templates select="." mode="title.ref">
	<xsl:with-param name="text-only" select="true()"/>
      </xsl:apply-templates>
    </xsl:attribute>
    <xsl:apply-templates select="sect2" mode="toc"/>
  </tocitem>
</xsl:template>

<xsl:template match="sect2" mode="toc">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <tocitem target="{$id}">
    <xsl:attribute name="text">
      <xsl:apply-templates select="." mode="title.ref">
	<xsl:with-param name="text-only" select="true()"/>
      </xsl:apply-templates>
    </xsl:attribute>
    <xsl:apply-templates select="sect3" mode="toc"/>
  </tocitem>
</xsl:template>

<xsl:template match="sect3" mode="toc">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <tocitem target="{$id}">
    <xsl:attribute name="text">
      <xsl:apply-templates select="." mode="title.ref">
	<xsl:with-param name="text-only" select="true()"/>
      </xsl:apply-templates>
    </xsl:attribute>
    <xsl:apply-templates select="sect4" mode="toc"/>
  </tocitem>
</xsl:template>

<xsl:template match="sect4" mode="toc">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <tocitem target="{$id}">
    <xsl:attribute name="text">
      <xsl:apply-templates select="." mode="title.ref">
	<xsl:with-param name="text-only" select="true()"/>
      </xsl:apply-templates>
    </xsl:attribute>
    <xsl:apply-templates select="sect5" mode="toc"/>
  </tocitem>
</xsl:template>

<xsl:template match="sect5" mode="toc">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <tocitem target="{$id}">
    <xsl:attribute name="text">
      <xsl:apply-templates select="." mode="title.ref">
	<xsl:with-param name="text-only" select="true()"/>
      </xsl:apply-templates>
    </xsl:attribute>
  </tocitem>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template name="helpmap">
  <xt:document href="jhelpmap.jhm"
    method="xml"
    doctype-public="-//Sun Microsystems Inc.//DTD JavaHelp Map Version 1.0//EN"
    doctype-system="http://java.sun.com/products/javahelp/map_1_0.dtd"
    indent="yes">
    <map version="1.0">
      <xsl:apply-templates select="//set
                                   | //book
                                   | //part
                                   | //reference
                                   | //preface
                                   | //chapter
                                   | //appendix
                                   | //refentry
                                   | //section
                                   | //sect1
                                   | //sect2
                                   | //sect3
                                   | //sect4
                                   | //sect5
                                   | //indexterm"
	mode="map"/>
    </map>
  </xt:document>
</xsl:template>

<xsl:template match="set" mode="map">
  <xsl:variable name="id">
    <xsl:call-template name="object.id">
      <xsl:with-param name="object" select="$object"/>
    </xsl:call-template>
  </xsl:variable>

  <mapID target="{$id}">
    <xsl:attribute name="url">
      <xsl:apply-templates mode="chunk-filename" select="."/>
    </xsl:attribute>
  </mapID>
</xsl:template>

<xsl:template match="book" mode="map">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <mapID target="{$id}">
    <xsl:attribute name="url">
      <xsl:apply-templates mode="chunk-filename" select="."/>
    </xsl:attribute>
  </mapID>
</xsl:template>

<xsl:template match="part|reference|preface|chapter|appendix"
              mode="map">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <mapID target="{$id}">
    <xsl:attribute name="url">
      <xsl:apply-templates mode="chunk-filename" select="."/>
    </xsl:attribute>
  </mapID>
</xsl:template>

<xsl:template match="secction|sect1|sect2|sect3|sect4|sect5" mode="map">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <mapID target="{$id}">
    <xsl:attribute name="url">
      <xsl:apply-templates mode="chunk-filename" select="."/>
    </xsl:attribute>
  </mapID>
</xsl:template>

<xsl:template match="indexterm" mode="map">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <mapID target="{$id}">
    <xsl:attribute name="url">
      <xsl:apply-templates mode="chunk-filename" select="."/>
    </xsl:attribute>
  </mapID>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template name="helpidx">
  <xt:document href="jhelpidx.xml"
    method="xml"
    doctype-public="-//Sun Microsystems Inc.//DTD JavaHelp Index Version 1.0//EN"
    doctype-system="http://java.sun.com/products/javahelp/index_1_0.dtd"
    indent="yes">
    <index version="1.0">
      <xsl:apply-templates select="//indexterm" mode="idx"/>
    </index>
  </xt:document>
</xsl:template>

<xsl:template match="indexterm" mode="idx">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <xsl:variable name="text">
    <xsl:value-of select="primary"/>
    <xsl:if test="secondary">
      <xsl:text>, </xsl:text>
      <xsl:value-of select="secondary"/>
    </xsl:if>
    <xsl:if test="tertiary">
      <xsl:text>, </xsl:text>
      <xsl:value-of select="tertiary"/>
    </xsl:if>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="see">
      <xsl:variable name="see"><xsl:value-of select="see"/></xsl:variable>
      <indexitem text="{$text} see '{$see}'"/>
    </xsl:when>
    <xsl:otherwise>
      <indexitem text="{$text}" target="{$id}"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>