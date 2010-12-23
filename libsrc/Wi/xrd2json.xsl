<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="text" media-type="application/json"/>
  <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
  <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>
    <xsl:template match="XRD">
{
  <xsl:apply-templates select="Subject|Host|Alias"/>
  "link": 
    [
      <xsl:for-each select="Link">
      {
        <xsl:for-each select="@*">"<xsl:value-of select="local-name(.)"/>": "<xsl:value-of select="."/>"<xsl:if test="position () != last ()">,
        </xsl:if></xsl:for-each>
      }<xsl:if test="position () != last ()">,</xsl:if>
      </xsl:for-each>
    ]
}
    </xsl:template>
    <xsl:template match="Subject|Host|Alias">"<xsl:value-of select="translate (local-name(.), $uc, $lc)"/>": "<xsl:value-of select="."/>",</xsl:template>
</xsl:stylesheet>
