<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2018 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/XSL/Transform/1.0" version="1.0">
  <xsl:output method="html" />
  <xsl:param name="xml_url" />
  <xsl:template match="/moreovernews">
    <table cellpadding="10" border="0" width="300"><tr><td class="heading"> 
        <a class="xml_url" target="_blank">
          <xsl:attribute name="HREF">
            <xsl:value-of select="$xml_url" />
          </xsl:attribute>
          <xsl:value-of select="//article/cluster" />
        </a> 
    </td></tr></table> 
    <FORM NAME="movement">
      <!-- Even though these hidden input fields are referenced
           by index, I give each of them the same name.  For
           some reason, Netscape 4.x refused to recognize them by
           index if they weren't given a name. -->
      <xsl:for-each select="article">
        <INPUT TYPE="hidden" NAME="x">
          <xsl:attribute name="VALUE">
             <xsl:value-of select="source" />
          </xsl:attribute>
        </INPUT>
        <INPUT TYPE="hidden" NAME="x">
          <xsl:attribute name="VALUE">
             <xsl:value-of select="url" />
          </xsl:attribute>
        </INPUT>
        <INPUT TYPE="hidden" NAME="x">
          <xsl:attribute name="VALUE">
             <xsl:value-of select="headline_text" />
          </xsl:attribute>
        </INPUT>
        <INPUT TYPE="hidden" NAME="x">
          <xsl:attribute name="VALUE">
             <xsl:value-of select="harvest_time" />
          </xsl:attribute>
        </INPUT>
      </xsl:for-each>
    </FORM>
    <div ID="first" style="position:absolute; visibility:hidden; width: 300px;" />
    <div ID="second" style="position:absolute; visibility:hidden; width: 300px;" />
    <script language="Javascript">
    var firstD, secondD;
    var arr = new Array();
    firstD = new CSSObject('first', document);
    secondD = new CSSObject('second', document);
    d = document.movement;
    l = d.length;
    i = 0;
    xcoord = 10;
    ycoord = 52 - ((isNav5) ? 3 : 0) - ((isNav4) ? 5 : 0) ;
    height = 300;
    width = 300;
    delay = 500;
    speed = 10 - ((isNav5) ? 10 : 0); 
    while (i &lt; l)
    {
      arr[i/4] = '&lt;table cellspacing="0" cellpadding="2"&gt;&lt;tr&gt;&lt;td width="'+ (width-10) +'" height="' + height + '" valign="middle"&gt;';
      arr[i/4] += '&lt;font class="source"&gt;' + d.elements[i].value + ':&lt;/font&gt;&lt;br /&gt;';
      arr[i/4] += '&lt;a class="headlines" href="' + d.elements[i+1].value + '"&gt;' + d.elements[i+2].value;
      arr[i/4] += '&lt;/a&gt;&lt;br /&gt;&lt;font class="harvest"&gt;' + d.elements[i+3].value + '&lt;/font&gt;&lt;/td&gt;&lt;/tr&gt;&lt;/table&gt;';
      i += 4;
    }

    function scroll(z, ixx, dr)
    {
      if (dr == 0)
      {
        firstD.clipRect(0, 0, width, height - z);
        secondD.clipRect(0, height - z, width, z);
        firstD.moveTo(xcoord, ycoord + z);
        secondD.moveTo(xcoord, ycoord - height + z);
      }
      else if (dr == 1)
      {
        firstD.clipRect(z, 0, width - z, height);
        secondD.clipRect(0, 0, z, height);
        firstD.moveTo(xcoord - z, ycoord);
        secondD.moveTo(xcoord + width - z, ycoord);
      }
      else if (dr == 2)
      {
        firstD.clipRect(0, z, width, height - z);
        secondD.clipRect(0, 0, width, z);
        firstD.moveTo(xcoord, ycoord - z);
        secondD.moveTo(xcoord, height + ycoord - z);
      }
      else if (dr == 3)
      {
        firstD.clipRect(0, 0, width - z, height);
        secondD.clipRect(width - z, 0, z, height);
        firstD.moveTo(xcoord + z, ycoord);
        secondD.moveTo(xcoord - width + z, ycoord);
      }       
      firstD.css.visibility = visible;
      secondD.css.visibility = visible;
      z = z + 1;
      if ((z &lt;= width &amp;&amp; (dr == 1 || dr == 3)) || (z &lt;= height &amp;&amp; (dr == 0 || dr == 2)))
        setTimeout("scroll(" + z + "," + ixx + "," + dr + ")", speed);
      else
      {
        firstD.css.visibility = hidden;
        setTimeout("scrollIt(" + ((ixx + 1) % (l/4)) + "," + ((dr + 1) %4) + ")", 0);
      }
    }
  
    function scrollIt(ix, dir)
    {
      firstD.write(arr[ix]);
      firstD.clipRect(0, 0, width, height);
      firstD.moveTo(xcoord, ycoord);
      firstD.css.visibility = visible;
      secondD.css.visibility = hidden;
      secondD.write(arr[(ix + 1)%(l/4)]);
      setTimeout("scroll(0," + ix + "," + dir + ")", delay);
    }

    function init()
    {
      scrollIt(0, 0);
    }

    window.onload = init;
    </script>
  </xsl:template>
</xsl:stylesheet>
