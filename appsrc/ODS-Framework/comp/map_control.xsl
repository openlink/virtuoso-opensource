<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/ods/">

  <!--
  Displays a map using the google maps
  Params:
     sql
       This is the SQL query to return the following columns for each point in the map:
         _LNG REAL : the longitude as a real value
         _LAT REAL : the lattitude as a real value
	 _KEY_VAL ANY : The column whose value is compared to the 'key-val' value to find the center of the map
	 EXCERPT : the text to go into the bubble window
     baloon-inx : the index (1 based) of the EXCERPT column in the result set
     lat-inx : the index (1 based) of the _LAT column in the result set
     lng-inx : the index (1 based) of the _LNG column in the result set
     key-name-inx : the index (1 based) of the _KEY_VAL column in the result set
     key-val : the value to compare to the _KEY_VAL column
     base_url : the base uri for the marker icon
     div-id : the HTTP id of the DIV section to put the map in.
  -->
  <xsl:template match="vm:map-control">
   <![CDATA[
  <script
       src="http://maps.google.com/maps?file=api&amp;v=1&amp;key=<?U WA_MAPS_GET_KEY () ?>"
       type="text/javascript" >
      </script>

  <script
      src="<?V WA_LINK (1, '/ods/comp/map_control.js') ?>"
       type="text/javascript" >
      </script>
      ]]>
  &lt;?vsp
    declare _inst_id integer;
    declare _sid, _realm varchar;
    _sid := self.sid;
    _realm := self.realm;

    WA_MAPS_AJAX_SET_VALS_GET_ID (
      _inst_id,
      <xsl:value-of select="@sql" />,
      <xsl:value-of select="@baloon-inx" />,
      <xsl:value-of select="@lat-inx" />,
      <xsl:value-of select="@lng-inx" />,
      <xsl:value-of select="@key-name-inx" />,
      <xsl:value-of select="@key-val" />,
      <xsl:value-of select="@base_url" />,
      _sid,
      _realm
      );
    commit work;
  ?&gt;
  <![CDATA[
  <script
       type="text/javascript" >
  function onLoad ()
  {
      zoom_level=]]><xsl:value-of select="@zoom" /><![CDATA[;
      initMap (
	"]]><xsl:value-of select="@div_id"/><![CDATA[",
	"<?V WA_LINK (0, '/ods/search_ajax.vsp') ?>",
	"<?V WA_LINK (1, '/ods/images/icons') ?>",
	"<?V _inst_id ?>", zoom_level );
  }
  window.onload=onLoad;
  </script>
  ]]>
 </xsl:template>
</xsl:stylesheet>
