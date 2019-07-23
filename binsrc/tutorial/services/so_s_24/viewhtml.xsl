<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2019 OpenLink Software
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
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
<xsl:output method="html" indent="yes" />
<xsl:template match="/">
<!--Add XSL HERE-->

<xsl:for-each select="KeywordSearchRequestResponse/return/Details/Details">
<table border="1" class="tableresult" width="97%">
  <tbody>
    <tr>
      <td>
        <xsl:text disable-output-escaping="yes">&#60;img align="right" src="</xsl:text><xsl:value-of select="ImageUrlSmall" disable-output-escaping="yes"/><xsl:text disable-output-escaping="yes">"&#62;</xsl:text><xsl:text disable-output-escaping="yes">&#60;a href="</xsl:text><xsl:value-of select="Url" disable-output-escaping="yes" /><xsl:text disable-output-escaping="yes">" style="color: #000000"&#62;</xsl:text><xsl:value-of select="ProductName"/><xsl:text disable-output-escaping="yes">&#60;</xsl:text>/a<xsl:text disable-output-escaping="yes">&#62;</xsl:text>
        <br/><strong>ASIN:</strong> <xsl:value-of disable-output-escaping="yes" select="Asin"/><br/>
        <strong>Our Price: </strong> <xsl:value-of disable-output-escaping="yes" select="OurPrice"/><br/> <br/>
        <xsl:choose>
        <xsl:when test="count(Reviews/CustomerReviews/CustomerReview)!=0">
        <strong>Average Customer's Rating: </strong> <xsl:value-of disable-output-escaping="yes" select="Reviews/AvgCustomerRating"/><br/>
        <xsl:for-each select="Reviews/CustomerReviews/CustomerReview">
        <br/>
        <strong>Customer Rating: </strong> <xsl:value-of disable-output-escaping="yes" select="Rating"/><br/>
        <strong>Summary: </strong> <xsl:value-of disable-output-escaping="yes" select="Summary"/><br/>

        <strong>Comments: </strong> <xsl:value-of disable-output-escaping="yes" select="Comment"/><br /></xsl:for-each></xsl:when>
        <xsl:otherwise>
        <strong>No customer comments</strong><br />
        </xsl:otherwise></xsl:choose> <p/>

        <xsl:text disable-output-escaping="yes">&#60;form method="POST" action="http://www.amazon.com/o/dt/assoc/handle-buy-box=</xsl:text><xsl:value-of select="Asin" disable-output-escaping="yes" /><xsl:text disable-output-escaping="yes">"&#62;</xsl:text>
        <xsl:text disable-output-escaping="yes">&#60;input type="hidden" name="asin.</xsl:text><xsl:value-of select="Asin" disable-output-escaping="yes" /><xsl:text disable-output-escaping="yes">" value="1"&#62;</xsl:text>
        <input type="hidden" name="tag-value" value="webservices-20"/>
        <input type="hidden" name="tag_value" value="webservices-20"/>
        <input type="hidden" name="dev-tag-value" value="dev_tag"/>
        <input type="Submit" value="Buy From Amazon" name="submit.add-to-cart"/>
        <xsl:text disable-output-escaping="yes">&#60;/form&#62;</xsl:text>
      </td>
    </tr>
  </tbody>
</table>
</xsl:for-each>

<!--End of XSL-->
</xsl:template>
</xsl:stylesheet>

