<?xml version='1.0' encoding="windows-1251"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="xml" encoding="utf-8"/>

<xsl:template match="/">
    <root>
    
    <xsl:if test="count(/document/obj542) > 0">
	<xsl:apply-templates select="document/obj542">
	  <xsl:sort select="fld1_" data-type="text"/>
	</xsl:apply-templates>
    </xsl:if>

    </root>
</xsl:template>

<xsl:template match="obj542">
    <out>
	    <fld2 ><xsl:value-of select="fld2_"/></fld2>
	    <fld1 ><xsl:value-of select="fld1_"/></fld1>
	    <fld4 ><xsl:value-of select="fld4_"/></fld4>
	    <fld3 ><xsl:value-of select="fld3_"/></fld3>
	    <fld6 ><xsl:value-of select="fld6_"/></fld6>
    </out>
</xsl:template>

</xsl:stylesheet>
