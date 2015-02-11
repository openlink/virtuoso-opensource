<?xml version="1.0" ?> 
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
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/XSL/Transform/1.0" version="1.0"> 
  <xsl:output method="html" /> 
  <xsl:template match="/moreovernews"> 
      <table cellpadding="10" border="0" width="300"><tr><td class="heading"> 
        <xsl:value-of select="//article/cluster" /> 
      </td></tr></table> 
    <script LANGUAGE="JavaScript"> 
          topedge = 50;  // location of news box from top of page 
          leftedge = 10;  // location of news box from left edge 
          boxheight = 300;  // height of news box 
          boxwidth = 300;  // width of news box 
          flag = 1; 
          speed = 1; 
          if (isNav5)
          { 
            topedge -= 3; 
            speed = 2;
          }
          if (isNav4) topedge -= 5; 
    </script> 
    <form name="hlcntform"> 
      <input type="hidden" name="headcnt"> 
        <xsl:attribute name="value"> 
          <xsl:value-of select="count(//article)" /> 
        </xsl:attribute> 
      </input> 
    </form> 
    <div ID="news" style="position:absolute; visibility:hidden; clip:rect(10,100,100,10); backgroundcolor: #FFFFCC" onmouseover="flag = 0; return;" onmouseout="flag = 1; return;"> 
      <table border="0" cellpadding="10" cellspacing="0" width="300" bgcolor="#FFFFCC"> 
        <tr> 
          <td bgcolor="#FFFFCC" height="300">&nbsp;</td>
        </tr>
        <xsl:for-each select="article"> 
          <TR bgColor="#FFFFCC"> 
            <TD height="70" VALIGN="middle" width="295"> 
              <A CLASS="headline" TARGET="_blank"> 
                <xsl:attribute name="HREF"> 
                  <xsl:value-of select="url" /> 
                </xsl:attribute> 
                <xsl:value-of select="headline_text" /> 
              </A> 
              <br /> 
              <font class="harvest"> 
                <xsl:value-of select="harvest_time" /> 
              </font> 
            </TD> 
          </TR> 
        </xsl:for-each> 
        <xsl:text>&#13;</xsl:text> 
        <tr> 
          <td bgcolor="#FFFFCC" height="300">&nbsp;</td>
        </tr>
      </table> 
    </div> 
    <SCRIPT LANGUAGE="JavaScript1.2"> 
            var newsDiv = new CSSObject('news', document);
            newsDiv.css.onmouseover = function() { flag = 0; return;} 
            newsDiv.css.onmouseout = function() { flag = 1; return;} 
            scrollheight = document.hlcntform.headcnt.value * 70; 
            function scrollnews(cliptop) 
            { 
              newsDiv.clipRect(0, cliptop, boxwidth + leftedge, boxheight); 
              newsDiv.moveTo(leftedge, topedge - cliptop); 
              cliptop = (cliptop + flag * speed) % (scrollheight + boxheight); 
              newsDiv.css.visibility= visible; 
              setTimeout('scrollnews(' + cliptop + ')', 50); 
            } 
            scrollnews(boxheight / 10); 
    </SCRIPT> 
  </xsl:template> 
</xsl:stylesheet> 
