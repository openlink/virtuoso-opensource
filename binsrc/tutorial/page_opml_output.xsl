<?xml version="1.0" encoding="utf-8"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <xsl:output method="xml" indent="yes"/>
	<xsl:include href="page_common.xsl"/>
	
  <xsl:template match="tutorial">
    <xsl:text disable-output-escaping="yes"><![CDATA[<?vsp
		  http_header ('Content-Type: text/xml\r\n');
      declare _path,_domain varchar;
      _domain := 'http://' || regexp_replace(HTTP_GET_HOST(),':80$','');
      _path := _domain || http_map_get('domain') || '/'; 
		  
		  declare _outlines any;
		  _outlines := vector();
		]]></xsl:text>
	  	<xsl:for-each select="//subsection[not(@ref)]">
	   		<xsl:text disable-output-escaping="yes">_outlines := vector_concat(_outlines,vector('</xsl:text>
	      <xsl:value-of select="parent::section/@Title" disable-output-escaping="yes"/>
	      <xsl:text> - </xsl:text>
	      <xsl:value-of select="@Title" disable-output-escaping="yes"/>
	   		<xsl:text disable-output-escaping="yes">','</xsl:text>
	      <xsl:value-of select="@wwwpath"/>
	      <xsl:text disable-output-escaping="yes">'));
	      </xsl:text>
		  </xsl:for-each>
    <xsl:text disable-output-escaping="yes"><![CDATA[?>]]></xsl:text>
    <opml version="1.0">
      <head>
        <title>OpenLink Virtuoso Features Demonstrations and Tutorials</title>
        </head>
			<body>
  <?vsp
    for(declare i integer,i := 0; i < length(_outlines); i := i + 2){
  ?>
  <xsl:text disable-output-escaping="yes"><![CDATA[
  <outline text="<?V _outlines[i] ?>" title="<?V _outlines[i] ?>" type="rss" htmlUrl="<?V _path ?><?V _outlines[i + 1] ?>/index.vsp" xmlUrl="<?V _path ?><?V _outlines[i + 1] ?>/rss.vsp"/>
  ]]></xsl:text><?vsp
    }
  ?>
			</body>
		</opml>
	</xsl:template>

</xsl:stylesheet>
