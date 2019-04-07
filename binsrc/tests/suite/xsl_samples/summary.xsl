<?xml version="1.0"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <DIV STYLE="padding:.3in .1in .3in .3in; font-family:Arial Black; background-color:chocolate; background-image=URL(swallows.jpg)">
      <xsl:for-each select="AUCTIONBLOCK/ITEM">
        <TABLE>
          <TR>
            <TD COLSPAN="2">
              <IMG STYLE="border:1px solid black">
                <xsl:attribute name="src"><xsl:value-of select="PREVIEW-SMALL/@src"/></xsl:attribute>
                <xsl:attribute name="width"><xsl:value-of select="PREVIEW-SMALL/@width"/></xsl:attribute>
                <xsl:attribute name="height"><xsl:value-of select="PREVIEW-SMALL/@height"/></xsl:attribute>
                <xsl:attribute name="alt"><xsl:value-of select="PREVIEW-SMALL/@alt"/></xsl:attribute>
              </IMG>
            </TD>
            <TD STYLE="padding-left:1em">
              <DIV STYLE="margin-left:2em; text-indent:-1.5em; line-height:80%;  font-size:18pt; color:yellow">
                <xsl:value-of select="TITLE"/>
              </DIV>
              <DIV STYLE="margin-left:2em; text-indent:-1.5em; line-height:80%;  margin-top:1em;  font-style:italic; font-size:18pt; color:yellow">
                <xsl:value-of select="ARTIST"/>
              </DIV>
            </TD>
          </TR>
          <TR>
            <TD>
              <DIV STYLE="color:white; font:10pt. Verdana; font-style:italic; font-weight:normal">
                Size: <xsl:value-of select="DIMENSIONS"/>
              </DIV>
            </TD>
            <TD>
              <DIV STYLE="text-align:right; color:white; font:10pt. Verdana; font-style:italic; font-weight:normal">
                <xsl:value-of select="MATERIALS"/>, <xsl:value-of select="YEAR"/>
              </DIV>
            </TD>
            <TD>
            </TD>
          </TR>
          <TR>
            <TD COLSPAN="2">
              <DIV STYLE="margin:2px; padding:0em .5em; background-color:orange; color:white">
                High bid:
                $<xsl:value-of select="BIDS/BID[0]/PRICE"/>
                <SPAN STYLE="color:yellow"> (<xsl:value-of select="BIDS/BID[0]/BIDDER"/>)</SPAN>
              </DIV>
              <DIV STYLE="margin:2px; padding:0em .5em; background-color:orange; color:white">
                Opening bid: $<xsl:value-of select="BIDS/BID[end()]/PRICE"/>
              </DIV>
            </TD>
            <TD STYLE="text-align:right; font:10pt Verdana;  font-style:italic; color:yellow">
              <DIV STYLE="margin-top:.5em">Copyright &#169; 1997 Linda Mann, all rights reserved.</DIV>
              <DIV STYLE="font-weight:bold">
                <A HREF="http://home.navisoft.com/lindamann/" target="_top">Linda Mann Art Gallery</A>
              </DIV>
            </TD>
          </TR>
        </TABLE>

      </xsl:for-each>
    </DIV>
  </xsl:template>
</xsl:stylesheet>
