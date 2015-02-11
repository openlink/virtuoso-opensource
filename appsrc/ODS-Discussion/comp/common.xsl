<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
-->
<!-- 
  Common utility macros.

  vm:ds-button-bar - dataset scrolling buttons.

-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
  <xsl:template match="vm:ds-button-bar">
    <tr class="ds_button_bar">
      <td align="center" colspan="3">
      
    <xsl:processing-instruction name="vsp">
        declare _ds_name varchar;
        _ds_name := '<xsl:value-of select="//data-set/@name"/>';
    </xsl:processing-instruction>
<!--        
        <v:button action="simple" value="&lt;&lt;&lt;">
          <xsl:attribute name="name">
            <xsl:value-of select="concat(//data-set/@name,'_first')"/>
          </xsl:attribute>
        </v:button>
-->        
        <v:button action="simple" value="&lt;&lt;" style="url">
          <xsl:attribute name="name">
            <xsl:value-of select="concat(//data-set/@name,'_prev')"/>
          </xsl:attribute>
        </v:button>

<!--
        <v:button
          style="url"
          action="simple"
        >
          <xsl:attribute name="name">
            <xsl:value-of select="concat(//data-set/@name,'_navigation')"/>
          </xsl:attribute>
          <xsl:attribute name="value">
            <xsl:value-of select="concat('--sprintf (\'%d\', self.',//data-set/@name,'.ds_data_source.ds_current_pager_idx)')"/>
          </xsl:attribute>
          xhtml_disabled="--case when self.ds_list_message.ds_data_source.ds_current_pager_idx = self.ds_list_message.ds_data_source.ds_current_page then 'true' else '@@hidden@@' end"
          xhtml_style="--case when self.ds_list_message.ds_data_source.ds_current_pager_idx = self.ds_list_message.ds_data_source.ds_current_page then 'width:24pt;color:red;font-weight:bolder;text-decoration:underline' else 'width:24pt' end"
        </v:button>
-->
        


        <v:button name="ds_group_list_next" action="simple" value="&gt;&gt;" style="url">
          <xsl:attribute name="name">
            <xsl:value-of select="concat(//data-set/@name,'_next')"/>
          </xsl:attribute>
        </v:button>
<!--
        <v:button name="ds_group_list_last" action="simple" value="&gt;&gt;&gt;">
          <xsl:attribute name="name">
            <xsl:value-of select="concat(//data-set/@name,'_last')"/>
          </xsl:attribute>
        </v:button>
 -->
      </td>
    </tr>
  </xsl:template>
  
<!-- 
  OpenLink copyright
  One attribute - from - determines beginning year.
-->

  <xsl:template match="vm:opl-copyright-str">
    Copyright &amp;copy; 
    <xsl:choose>
      <xsl:when test="@from">
        <xsl:value-of select="@from"/>-
      </xsl:when>
      <xsl:otherwise>
        1998-
      </xsl:otherwise>
    </xsl:choose>
    <?V "LEFT"(datestring (now()), 4) ?>&amp;nbsp;OpenLink Software.
  </xsl:template>

  <xsl:template match="vm:opl-copyright">
    <div class="copyright">
      <vm:opl-copyright-str/>
    </div>
  </xsl:template>

</xsl:stylesheet>

