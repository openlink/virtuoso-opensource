<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" indent="yes"/>
  <xsl:template match="root">
    <![CDATA[
<!doctype netscape-bookmark-file-1>
<!-- this is an automatically generated file.
     it will be read and overwritten.
     do not edit! -->
    ]]>
    <TITLE>My Bookmarks</TITLE>
    <H1>My Bookmarks</H1>
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="folder">
    <DL><![CDATA[<p>]]><![CDATA[<DT>]]><H3>
        <xsl:attribute name="ID"><xsl:value-of select="@id"/></xsl:attribute>
        <xsl:value-of select="@name"/>
      </H3>
      <xsl:apply-templates select="bookmark"/>
      <xsl:apply-templates select="folder"/>
    </DL>
  </xsl:template>
  <xsl:template match="bookmark">
    <![CDATA[<DT>]]><A>
      <xsl:attribute name="HREF"><xsl:value-of select="@uri"/></xsl:attribute>
      <xsl:attribute name="ID"><xsl:value-of select="@id"/></xsl:attribute>
      <xsl:value-of select="@name"/>
    </A>
    <xsl:apply-templates select="bookmark"/>
  </xsl:template>
</xsl:stylesheet>
