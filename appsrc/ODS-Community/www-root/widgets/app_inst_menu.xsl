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
                xmlns:vm="http://www.openlinksw.com/vspx/community/">
<xsl:template match="vm:applications_menu|vm:applications_fmenu">
    <?vsp
      {
      declare arr any;
      arr := vector (
                     vector ('WEBLOG2', 'blog2'),
                     vector ('eNews2', 'enews2'),
                     vector ('oWiki', 'wiki'),
                     vector ('oGallery', 'oGallery'),
                     vector ('Community', 'Community'),
                     vector ('Bookmark', 'bookmark'),
                     vector ('Polls','Polls'),
                     vector ('AddressBook','AddressBook')

                    );

      foreach (any app in arr) do
        {
          if (wa_check_package (app[1]))
          {
            declare issel_class varchar;
            issel_class:='navtab_non_sel';
            if(self.app_type = app[0])  issel_class:='navtab_sel';
      ?>
        <td nowrap="nowrap" class="<?=issel_class?>">
      <v:url name="slice1" url="--sprintf ('?page=app_inst&app=%s', app[0])"
          value="-- WA_GET_APP_NAME (app[0])"
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

</xsl:stylesheet>
