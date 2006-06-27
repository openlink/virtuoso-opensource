<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  <xsl:template match="root">
    <xbel version="1.0">
      <title>My Bookmarks</title>
      <xsl:apply-templates/>
    </xbel>
  </xsl:template>
  <xsl:template match="folder">
    <folder folded="yes">
      <xsl:attribute name="ID"><xsl:value-of select="@id"/></xsl:attribute>
      <title>
        <xsl:value-of select="@name"/>
      </title>
      <xsl:apply-templates select="bookmark"/>
      <xsl:apply-templates select="folder"/>
    </folder>
  </xsl:template>
  <xsl:template match="bookmark">
    <bookmark>
      <xsl:attribute name="href"><xsl:value-of select="@uri"/></xsl:attribute>
      <xsl:attribute name="id"><xsl:value-of select="@id"/></xsl:attribute>
      <title><xsl:value-of select="@name"/></title>
      <xsl:if test="./desc != ''">
        <desc><xsl:value-of select="./desc"/></desc>
      </xsl:if>
    </bookmark>
    <xsl:apply-templates select="bookmark"/>
  </xsl:template>
</xsl:stylesheet>
