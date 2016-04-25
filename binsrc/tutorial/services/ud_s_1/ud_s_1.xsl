<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2016 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="/">
   <save_business xmlns="urn:uddi-org:api" generic="1.0">
<xsl:text>
</xsl:text>
      <xsl:for-each select="Suppliers">
        <businessEntity operator="OpenLink Software">
 <xsl:text>
 </xsl:text>
          <xsl:attribute name="authorizedName"><xsl:value-of select="ContactName"/></xsl:attribute>
	  <name>
            <xsl:value-of select="CompanyName"/>
	  </name>
  <xsl:text>
  </xsl:text>
	  <contacts>
  <xsl:text>
  </xsl:text>
	    <contact useType="Demo">
    <xsl:text>
    </xsl:text>
	      <description xml:lang="en">
		<xsl:value-of select="ContactTitle"/>
	      </description>
     <xsl:text>
     </xsl:text>
	    <personName>
	      <xsl:value-of select="ContactName"/>
	    </personName>
     <xsl:text>
     </xsl:text>
	    <phone useType="phone">
	      <xsl:value-of select="Phone"/>
	    </phone> 
     <xsl:text>
     </xsl:text>
	    <phone useType="fax">
	      <xsl:value-of select="Fax"/>
	    </phone> 
     <xsl:text>
     </xsl:text>
	    <address useType="Office">
     <xsl:text>
     </xsl:text>
	      <addressLine>
		<xsl:value-of select="Address"/>
	      </addressLine>
     <xsl:text>
     </xsl:text>
	      <addressLine>
		<xsl:value-of select="City"/>
	      </addressLine>
     <xsl:text>
     </xsl:text>
	      <addressLine>
		<xsl:value-of select="Region"/>
		<xsl:value-of select="PostalCode"/>
	      </addressLine>
     <xsl:text>
     </xsl:text>
	      <addressLine>
		<xsl:value-of select="Country"/>
	      </addressLine>
     <xsl:text>
     </xsl:text>
	    </address>
     <xsl:text>
     </xsl:text>
            <xsl:for-each select="HomePage">
	      <address useType="HomePage">
	        <addressLine>
		  <xsl:value-of select="HomePage"/>
	        </addressLine>
	      </address>
            </xsl:for-each>
	    </contact>
   <xsl:text>
   </xsl:text>
	  </contacts>
 <xsl:text>
 </xsl:text>
        </businessEntity>
<xsl:text>
</xsl:text>
      </xsl:for-each>
    </save_business>
      <xsl:text>
      </xsl:text>
  </xsl:template>
</xsl:stylesheet>
