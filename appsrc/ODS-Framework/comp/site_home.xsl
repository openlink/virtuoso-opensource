<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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

<xsl:template match="vm:site_home">
   <vm:site_home_enews/>
</xsl:template>

<xsl:template match="vm:site_home_enews">
    <v:data-source name="home_news" expression-type="sql" nrows="10" initial-offset="0">
		       <v:expression>
		          <![CDATA[
			  select ENEWS.WA.wide2utf(coalesce(EFI_TITLE, \'~ no title ~\')) EFI_TITLE, EFI_LINK, EF_TITLE
			  from ENEWS.WA.FEED_ITEM join ENEWS.WA.FEED on EF_ID = EFI_FEED_ID
		          ]]>
		          <!--[CDATA[
			select top 10 EFI_ID,
			     ENEWS.WA.wide2utf(coalesce(EFI_TITLE, \'~ no title ~\')) EFI_TITLE,
			     coalesce(EFI_DESCRIPTION, \'~ no description ~\') description,
			     EFI_PUBLISH_DATE,
			     EFI_LAST_UPDATE,
			     EFI_LINK,
			     coalesce(EFI_AUTHOR, \'~ no author ~\') author,
			     EFI_COMMENT_API,
			     EFID_READ_FLAG,
			     EFID_KEEP_FLAG,
			     EF_URI,
			     EF_HOME_URI,
			     ENEWS.WA.wide2utf(EFD_TITLE) EFD_TITLE
			from ENEWS.WA.FEED_ITEM
			  join ENEWS.WA.FEED on EF_ID = EFI_FEED_ID
			    left join ENEWS.WA.FEED_ITEM_DATA on EFID_ITEM_ID = EFI_ID
			      left join ENEWS.WA.FEED_DOMAIN on EFD_FEED_ID = EF_ID
		          ]]-->
    </v:expression>
       <v:column name="EFI_TITLE" label="Name" />
       <v:column name="EFI_LINK" label="Link" />
       <v:column name="EF_TITLE" label="Source" />
       <!--v:column name="WAT_DESCRIPTION" label="Description" /-->
    </v:data-source>

    <table class="listing">
	<tr class="listing_header_row">
	  <th>Application Type</th>
	  <th>Action</th>
	 </tr>
	<v:data-set name="apps" scrollable="1" data-source="self.home_news">
      <vm:template type="repeat">
        <vm:template type="if-not-exists">No applications available</vm:template>
        <vm:template type="browse">
          <tr>
            <td>
              <vm:url value="--(control.vc_parent as vspx_row_template).te_rowset[2]" url="">
              </vm:url>
            </td>
            <td>
		<vm:url value="--(control.vc_parent as vspx_row_template).te_rowset[0]"
		          url="--(control.vc_parent as vspx_row_template).te_rowset[1]">
              </vm:url>
            </td>
          </tr>
        </vm:template>
      </vm:template>

    </v:data-set>
  </table>
</xsl:template>

<!--xsl:template match="vm:site_home_omail">
    <v:data-source nrows="10"
                   initial-offset="0"
                   name="d_omail"
                   data='--wa_dash_omail_v_data (self.grp_sel_no_thr, self.fordate, self.article_list_length)'
                   meta="--wa_dash_omail_v_meta (self.grp_sel_no_thr, self.fordate, self.article_list_length)"
                   expression-type="array" />
    <v:data-set name="d_omail_list"
                data-source="self.d_omail"
                scrollable="1"
                width="80"
                nrows="10">
    </v:data-set>
</xsl:template-->

</xsl:stylesheet>
