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
<!-- login control; two states in main page and on the other pages -->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
    <xsl:template match="vm:nntpf-rss-group">
    <table width="100%" id="content" cellspacing="0" cellpadding="0">
      <tr>
        <th colspan="2">RSS</th>
      </tr>
      <tr>
        <td align="left">Choose description for RSS:</td>
        <td>
          <v:text name="rss_desc"
                  xhtml_size="60"
                  value="--nntpf_get_group_name (get_keyword ('group', params))">
            <v:validator name="val_rss_desc_not_empty"
                         message="RSS description cannot be empty"
                         test="length"
                         min="1"
                         max="64"/>
          </v:text>
	  <input type="hidden" name="sel_group" value="<?= get_keyword ('group', self.vc_page.vc_event.ve_params) ?>"/>
        </td>
      </tr>
      <tr>
        <td align="left">&nbsp;</td>
        <td>
          <v:button action="submit" name="save" value="Save">
            <v:on-post>
              <![CDATA[
                declare _user, _group, _desc, _url, _id, _parameters any;

                select U_ID into _user from sys_users where U_NAME = connection_get ('vspx_user');
                _group := get_keyword ('sel_group', params, '');
                _desc  := get_keyword ('rss_desc', params, '');
                _id := uuid ();
--                _url := nntpf_generate_rss_url (_id, lines);
                _url := '/nntpf/rss.vsp?rss=' ||_id;
                _parameters := vector ('group', atoi (_group));

                if (not self.vc_is_valid) return;

                --dbg_printf ('_desc: |%s|', _desc);

                insert into NNTPFE_USERRSSFEEDS (FEURF_ID,
                                                 FEURF_USERID,
                                                 FEURF_DESCR,
                                                 FEURF_URL,
                                                 FEURF_PARAM)
                  values (_id, _user, _desc, _url, serialize (_parameters));

                  http_request_status ('HTTP/1.1 302 Found');
                  http_header (sprintf ('Location: nntpf_edit_rss.vspx?sid=%s&realm=%s\r\n',
                                        self.sid, self.realm));
               ]]>
		 </v:on-post>
		 <v:before-data-bind>
		     <![CDATA[
		 	if (get_keyword ('rss_desc', params, '') <> '') -- XXX fill right info.
		 	{
		 	     declare url, pars varchar;
		 	     pars := sprintf ('sid=%s&realm=%s', self.sid, self.realm);
		 	     url := vspx_uri_add_parameters (self.url, pars);

		 	     http_request_status ('HTTP/1.1 302 Found');
		 	     http_header (sprintf ('Location: %s\r\n', url));
		 	  }

		 	]]>
		 </v:before-data-bind>
	  </v:button>
          <input type="button" value="Cancel" onClick="javascript:history.back(1);"/>
        </td>
      </tr>
    </table>
  </xsl:template>
</xsl:stylesheet>
