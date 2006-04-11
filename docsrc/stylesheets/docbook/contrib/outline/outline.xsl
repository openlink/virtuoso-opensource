<!--
| Identity Transform Stylesheet
| ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
| $Author$
| $Date$
| $Source$
| $Revision$
+-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<xsl:template match="/">
  <html>
  <body>
  <xsl:apply-templates/>
  </body>
  </html>
</xsl:template>

<xsl:template match="set|book|part|reference|article|sect1|sect2|sect3|sect4|sect5|section|simplesect|preface|chapter|appendix|example|figure|table|informaltable">
  <xsl:param name="treeicon">n</xsl:param>
  <xsl:variable name="level" select="count(ancestor-or-self::*)"/>
  <xsl:variable name="title" select="title"/>
  <xsl:variable name="this"  select="local-name(.)"/>
  <img src="s.gif" border="0" height="1" width="{22*$level}"/>
  <img border="0" src="{concat($treeicon,'.gif')}"/>
  <img border="0" src="{concat($this,'.gif')}"/>
  <xsl:variable name="color">
    <xsl:choose>
      <xsl:when test="$level = 1">navy</xsl:when>
      <xsl:when test="$level = 2">red</xsl:when>
      <xsl:when test="$level = 3">blue</xsl:when>
      <xsl:when test="$level = 4">black</xsl:when>
    </xsl:choose>
  </xsl:variable>
  <span style="color:{$color}"><xsl:value-of select="$title"/></span>
  <xsl:if test="local-name(.)='example' and programlisting/@role">
   <small style="font-family:courier">(<xsl:value-of select="substring-after(programlisting/@role,'-')"/>)</small>
  </xsl:if>
  <br />
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="*|@*|comment()|processing-instruction()|text()"/>

</xsl:stylesheet>
