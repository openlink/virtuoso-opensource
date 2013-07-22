<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2013 OpenLink Software
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

  <xsl:output method="html"/>

  <!-- ==================================================================== -->
  <!-- Variables -->
  <xsl:variable name="imgP">../images</xsl:variable>
  <xsl:variable name="RFsrc">virtdocs_xt.html</xsl:variable>
  <!-- Variables -->
  <!-- ==================================================================== -->

  <!-- this xsl combines some JavaScript with the HTML output for use with the framed version.  This xsl produces
		an expandable menu like tree of the chapter with links and things. -->

  <xsl:pi name="DOCTYPE HTML PUBLIC">&quot;-//W3C//DTD HTML 4.0 Transitional//EN&quot;</xsl:pi>

  <xsl:template match="/">
    <HTML>
      <HEAD>
        <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
        <TITLE>
          <xsl:value-of select="/book/title"/>
        </TITLE>

        <Script Language="JavaScript1.2">
        <!-- Until NS, MOZ or whatever want to let me hide a DIV this script is purely MS friendly -->

          NS4 = (document.layers) ? 1 : 0;
          IE4 = (document.all) ? 1 : 0;
          ver4 = (NS4 || IE4) ? 1 : 0;

          function toggler(obj, pic)
            {
	      if (!ver4) return;

	      if (IE4) {
	      if (document.all[obj].style.display=='')
	        {  
		  document.all[obj].style.display='none';
       		  document.all[pic].src='<xsl:value-of select="$imgP"/>/tree/menu.gif';
		}
	      else
	        {
		  document.all[obj].style.display='';
		  document.all[pic].src='<xsl:value-of select="$imgP"/>/tree/menu2.gif';
       	        }
            } 
	  else 
	    {
              whichEl = eval("document." + obj);
              whichIm = eval("document.images." + pic);

              if (whichEl.visibility == "hide") 
	        {
                  whichEl.visibility = "show";
                  whichIm.src = '<xsl:value-of select="$imgP"/>/tree/menu.gif';
                }
              else 
	        {
                  whichEl.visibility = "hide";
                  whichIm.src = '<xsl:value-of select="$imgP"/>/tree/menu2.gif';
                }
            }
          }

        function hide(obj, pic)
          {
	    if (!ver4) return;
	    if (IE4) 
	      {
		document.all[obj].style.display='none';
		document.all[pic].src='<xsl:value-of select="$imgP"/>/tree/menu.gif';
    	      }
	    else 
	      {
                whichEl = eval('document.' + obj);
                whichIm = eval('document.images.' + pic);
                whichEl.visibility = 'hide';
                whichIm.src = '<xsl:value-of select="$imgP"/>/tree/menu2.gif';
              }
	  }

        function show(obj, pic)
          {
	    document.all[obj].style.display='';
    	    document.all[pic].src='<xsl:value-of select="$imgP"/>/tree/menu2.gif';
          }
<!--
    function hi_light_on(img, id, level)
    {
    	status='Click to expand and contract contents levels....';

    	// if (id.style.display=='' ) 
	//   {img.src='<xsl:value-of select="$imgP"/>/tree/virtbullet'+level+'_open_hl.gif';}
    	// if (id.style.display=='none' ) 
	//   {img.src='<xsl:value-of select="$imgP"/>/tree/virtbullet'+level+'_closed_hl.gif';} 
    }

    function hi_light_off(img, id, level)
    {
    	// if (id.style.display=='' ) 
	//   {img.src='<xsl:value-of select="$imgP"/>/tree/virtbullet'+level+'_open.gif';}
    	// if (id.style.display=='none' ) 
	//   {img.src='<xsl:value-of select="$imgP"/>/tree/virtbullet'+level+'_closed.gif';}

    	status='';
    }
-->
        </Script>
      </HEAD>

      <BODY CLASS="cf-vdocbody">
        <!-- Doc Contents Content -->

        <!-- Chapters ======================== -->
        <DIV CLASS="cfd-toc">
          <HR/>
   	  <TABLE WIDTH="100%" CLASS="cf-tabs"><TR>
	    <TD WIDTH="10">
	      <IMG>
	        <xsl:attribute name="SRC">
		  <xsl:value-of select="$imgP"/>/tree/menu.gif
		</xsl:attribute>
	      </IMG>
            </TD>
	    <TD ALIGN="left">
	      <A CLASS="cf-toc1" TARGET="viewfr">
		<xsl:attribute name="HREF">
		  <xsl:value-of select="$RFsrc"/>#contents
		</xsl:attribute>
		Contents
	      </A>
	    </TD>
	  </TR>
	</TABLE>
        <HR/>
        <xsl:for-each select="/book/chapter">
   	  <TABLE WIDTH="100%" CLASS="cf-tabs">
	    <TR>
	      <TD WIDTH="10">
		<IMG>
		  <xsl:attribute name="SRC">
		    <xsl:value-of select="$imgP"/>/tree/menu.gif
		  </xsl:attribute>
		  <xsl:attribute name="ID">
		    imgc1_<xsl:value-of select="./@label" />
		  </xsl:attribute>
<!--			  <xsl:attribute name="onMouseOver">
                            hi_light_on('imgc1_<xsl:value-of select="./@label" />', '
			    <xsl:value-of select="./@label" />', '2');
                          </xsl:attribute>
			  <xsl:attribute name="onMouseOut">
			    hi_light_off('imgc1_<xsl:value-of select="./@label" />', '
			    <xsl:value-of select="./@label" />', '2');
			  </xsl:attribute>
-->
                  <xsl:attribute name="onClick">
		    toggler('<xsl:value-of select="./@label" />', 'imgc1_<xsl:value-of select="./@label" />');
		  </xsl:attribute>
		</IMG>
	      </TD>
	      <TD ALIGN="left">
		<A CLASS="cf-toc1" TARGET="viewfr">
		  <xsl:attribute name="HREF">
		    <xsl:value-of select="$RFsrc"/>#<xsl:value-of select="./@label" />
		  </xsl:attribute>
                  <xsl:attribute name="onClick">
		    show('<xsl:value-of select="./@label" />', 'imgc1_<xsl:value-of select="./@label" />');
		  </xsl:attribute>
		  <xsl:attribute name="TITLE">
		    Chapter: <xsl:value-of select="./@label" /> - <xsl:value-of select="./title"/>
		    <xsl:text>
------------------------------------------
</xsl:text>
                    <xsl:apply-templates select="./abstract" />
		  </xsl:attribute>
	   	  <xsl:value-of select="./title"/>
		</A>
	      </TD>
	    </TR>
	  </TABLE>
<!-- Section 1s ======================== -->
	  <DIV CLASS="cfd-toc2">
	    <xsl:attribute name="ID">
	      <xsl:value-of select="./@label" />
	    </xsl:attribute>
	    <xsl:for-each select="./sect1">
	      <TABLE CLASS="cf-tabs">
	        <TR>
		  <TD>
		    <IMG>
		      <xsl:attribute name="SRC">
		        <xsl:value-of select="$imgP"/>/tree/menu.gif
		      </xsl:attribute>
		      <xsl:attribute name="ID">
		        imgc2_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_
		      </xsl:attribute>

<!--			  <xsl:attribute name="onMouseOver">
                            hi_light_on('imgc2_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />
			    _', '_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_', '2');
			  </xsl:attribute>
			  <xsl:attribute name="onMouseOut">
			    hi_light_off('imgc2_<xsl:value-of select="../@label" />
			    <xsl:value-of select="./@id" />_', '_<xsl:value-of select="../@label" />
			    <xsl:value-of select="./@id" />_', '2');
			  </xsl:attribute>
-->
                      <xsl:attribute name="onClick">
		        toggler('_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_' , 'imgc2_
			<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_');
		      </xsl:attribute>
		    </IMG>
		  </TD>
		  <TD>
		    <A CLASS="cf-toc2" TARGET="viewfr">
		      <xsl:attribute name="HREF">
		        <xsl:value-of select="$RFsrc"/>#<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />
		      </xsl:attribute>
		      <xsl:attribute name="onClick">
		        show('_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_' , 'imgc2_
			<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_');
		      </xsl:attribute>
		      <xsl:value-of select="./title"/>
		    </A>
		  </TD>
		</TR>
		<TR>
		  <TD/>
		  <TD>
                  <!-- Section 2s ======================== -->
         	    <DIV CLASS="cfd-toc3">
		      <xsl:attribute name="ID">
		        _<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_
		      </xsl:attribute>
		      <xsl:for-each select="./sect2">
		        <A CLASS="cf-toc3" TARGET="viewfr">
			  <xsl:attribute name="HREF">
			    <xsl:value-of select="$RFsrc"/>#<xsl:value-of select="../../@label" />
			    <xsl:value-of select="../@id" /><xsl:value-of select="./@id" />
			  </xsl:attribute>
<!-- <xsl:attribute name="TITLE">
       <xsl:for-each select="./sect3">
         <xsl:value-of select="./title"/>; 
       </xsl:for-each>
     </xsl:attribute> -->
         		  <xsl:value-of select="./title"/>
		        </A>
		        <BR/>
         	      </xsl:for-each>
		    </DIV>
		    <Script Language="JavaScript">
		      hide('_<xsl:value-of select="../@label" />
		      <xsl:value-of select="./@id" />_', 'imgc2_<xsl:value-of select="../@label" />
		      <xsl:value-of select="./@id" />_')
		    </Script>
		  </TD>
                </TR>
	      </TABLE>
	    </xsl:for-each>
	  </DIV>
	  <Script Language="JavaScript">
	    hide('<xsl:value-of select="./@label" />', 'imgc1_<xsl:value-of select="./@label" />')
	  </Script> 
        </xsl:for-each>
        <HR/>
        <TABLE WIDTH="100%" CLASS="cf-tabs">
          <TR>
	    <TD WIDTH="10">
	      <IMG>
	        <xsl:attribute name="SRC">
	          <xsl:value-of select="$imgP"/>/tree/menu.gif
	        </xsl:attribute>
	      </IMG>
	    </TD>
	    <TD>
	      <A CLASS="cf-toc1" TARGET="viewfr">
	        <xsl:attribute name="HREF">
	          <xsl:value-of select="$RFsrc"/>#_FunctionIndex
	        </xsl:attribute>
	        Appendix A - Function Index
	      </A>
	    </TD>
	  </TR>
        </TABLE>
        </DIV>
        <HR/>
      </BODY>
    </HTML>
  </xsl:template>

  <xsl:template match="abstract">
    <xsl:apply-templates />
  </xsl:template>

  <xsl:template match="para">
    <xsl:apply-templates />
  </xsl:template>

</xsl:stylesheet>
