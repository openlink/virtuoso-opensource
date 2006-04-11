<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
<xsl:output method="text" indent="yes" />
<xsl:param name="file_name" />
<xsl:variable name="pad" select="'        '"/>
<xsl:template match="/">
Lines: <xsl:value-of select="count (pl_stats/*[@file = $file_name]/line)"/>
TotalLines: <xsl:value-of  select="sum (pl_stats/*[@file = $file_name]/@lct)" />
Coverage: <xsl:value-of select="(100 * count (pl_stats/*[@file = $file_name]/line[number(@ctr) > 0])) div sum (pl_stats/*[@file = $file_name]/@lct)" /> %
<xsl:text>
</xsl:text>

<xsl:for-each select="pl_stats/*[@file = $file_name]">
<xsl:sort select="concat(@file,line[1]/@no)" order="ascending"/>
<xsl:text>
</xsl:text>
<xsl:variable name="pcalls" select="number(@calls)" />
<xsl:value-of select="substring ($pad, 1, 8 - string-length ($pcalls))"/>
<xsl:value-of select="$pcalls"/> : <xsl:value-of select="@name"/> <xsl:call-template name="cls_name"/>: (<xsl:value-of select="@time"/> msec)
<xsl:text>
        </xsl:text>
<xsl:for-each select="line">
<xsl:sort select="@no"/>
<xsl:variable name="lineno" select="number(@no)" />
<xsl:variable name="linectr" select="number(@ctr)" />
<xsl:value-of select="substring ($pad, 1, 6 - string-length ($lineno))"/>
<xsl:choose>
<xsl:when test="number(@ctr) > 0">
<xsl:value-of select="$lineno"/> : <xsl:value-of select="substring ($pad, 1, 6 - string-length ($linectr))"/><xsl:value-of select="$linectr"/> : <xsl:value-of select="."/>
<xsl:text>
        </xsl:text>
</xsl:when>
<xsl:otherwise>
<xsl:value-of select="$lineno"/> :     ## : <xsl:value-of select="."/><xsl:text>
        </xsl:text>
</xsl:otherwise>
</xsl:choose>
</xsl:for-each>
<xsl:text>
        </xsl:text>
<xsl:for-each select="caller">
<xsl:sort select="@ct"/>
<xsl:variable name="pct" select="number(@ct)" />
<xsl:value-of select="substring ($pad, 1, 6 - string-length ($pct))"/>
<xsl:value-of select="$pct"/> : <xsl:value-of select="@name"/>
<xsl:text>
        </xsl:text>
</xsl:for-each>
</xsl:for-each>
</xsl:template>
<xsl:template name="cls_name">
    <xsl:if test="@class">
	<xsl:text> of </xsl:text> <xsl:value-of select="@class"/><xsl:text> </xsl:text>
    </xsl:if>
</xsl:template>
</xsl:stylesheet>

