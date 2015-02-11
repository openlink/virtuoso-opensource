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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/ods/">
<xsl:template match="vm:applications_menu|vm:applications_fmenu">
    <?vsp
      {
         declare arr any;
	 arr := vector (
			vector ('Community', 'Community'),
			vector ('WEBLOG2', 'blog2'),
			vector ('oGallery', 'oGallery'),
			vector ('eNews2', 'enews2'),
			vector ('oWiki', 'wiki'),
			vector ('eCRM', 'eCRM'),
			vector ('Bookmark', 'bookmark')

			);

			foreach (any app in arr) do
			  {
			    if (wa_check_package (app[1]))
			      {
			?>
	      <td>
      <xsl:if test="not @level">
 		  <v:url name="slice1" url="--sprintf ('app_inst.vspx?app=%s&ufname=%V', app[0], self.fname_or_empty)"
		      value="--WA_GET_APP_NAME (app[0])"
		      xhtml_class="--case when self.app_type = app[0] and self.topmenu_level='0' then 'sel' else '' end"
		      render-only="1"
		   />
      </xsl:if>
      <xsl:if test="@level=1">
 		  <v:url name="slice1" url="--sprintf ('app_inst.vspx?app=%s&ufname=%V&l=1', app[0], self.fname_or_empty)"
		      value="--self.tab_pref || WA_GET_APP_NAME (app[0])"
		      xhtml_class="--case when self.app_type = app[0] and self.topmenu_level='1' then 'sel' else '' end"
		      render-only="1"
		   />
      </xsl:if>
	      </td>
	      <?vsp
	                       }
	                    }
	      ?>
<?vsp
      }
?>

    <?vsp
      {
         declare arr_links any;
	 arr_links := vector (
	    -- package, url
			vector ('nntpf','/nntpf/')
			);

			foreach (any app in arr_links) do
			  {
			    if (wa_check_package (app[0]))
			      {
			?>
	      <td>
 		  <v:url name="slice1" url="--sprintf ('%s', app[1])"
		      value="--WA_GET_APP_NAME (app[0])"
		      render-only="1"
		   />
	      </td>
	      <?vsp
	                       }
	                    }
	      ?>
<?vsp
      }
?>
 </xsl:template>

<xsl:template match="vm:applications_my_menu|vm:applications_my_fmenu">
    <?vsp
      {
         declare arr any;
	 arr := vector (
			vector ('Community', 'Community'),
	 		vector ('oDrive', 'oDrive'),
			vector ('WEBLOG2', 'blog2'),
			vector ('oGallery', 'oGallery'),
			vector ('eNews2', 'enews2'),
			vector ('oWiki', 'wiki'),
			vector ('oMail', 'oMail'),
			vector ('eCRM', 'eCRM'),
			vector ('Bookmark', 'bookmark')
			);

			foreach (any app in arr) do
			  {
			    if (wa_check_package (app[1]))
			      {
			?>
	      <td>
      <xsl:if test="not @level">
 		  <v:url name="slice1" url="--sprintf ('app_my_inst.vspx?app=%s&ufname=%V', app[0], self.fname_or_empty)"
		      value="--WA_GET_APP_NAME (app[0])"
		      xhtml_class="--case when self.app_type = app[0] and self.topmenu_level='0' then 'sel' else '' end"
		      render-only="1"
		   />
      </xsl:if>
      <xsl:if test="@level=1">
 		  <v:url name="slice1" url="--sprintf ('app_my_inst.vspx?app=%s&ufname=%V&l=1', app[0], self.fname_or_empty)"
		      value="--self.tab_pref || WA_GET_APP_NAME (app[0])"
		      xhtml_class="--case when self.app_type = app[0] and self.topmenu_level='1' then 'sel' else '' end"
		      render-only="1"
		   />
      </xsl:if>
	      </td>
	      <?vsp
	                       }
	                    }
	      ?>
<?vsp
      }
?>
 </xsl:template>

</xsl:stylesheet>
