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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
	        xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
  <xsl:template match="vm:nntpf-search">
    Search: <v:text name="searchkeywords" xhtml:width="30" value="" />
    <span class="error_summary">
      <v:error-summary match="searchkeywords" />
    </span>
    <v:button name="go_search" action="submit" value="Go">
      <v:on-post>
        <![CDATA[

  if (not self.vc_is_valid)
    return;

  if (trim (self.searchkeywords.ufl_value, ' ') = '')
    {
      self.searchkeywords.vc_error_message := 'Empty values for search are not allowed.';
      self.vc_is_valid := 0;
      return 0;
    };

  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf ('Location: nntpf_addtorss.vspx?sid=%s&realm=%s&search=%V\r\n',
               self.sid, 
               self.realm, 
               encode_base64 (serialize (vector (get_keyword ('searchkeywords', 
                                                              self.vc_page.vc_event.ve_params))))));
        ]]> 
      </v:on-post>
    </v:button>
    <v:button style="url" name="nntpf_search_adv" action="submit" value="Advanced..." enabled="--self.vc_authenticated">
      <v:on-post>
        <![CDATA[
  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf ('Location: nntpf_adv_search.vspx?sid=%s&realm=%s&search=%V\r\n',
			self.sid, 
                        self.realm, 
                        get_keyword ('searchkeywords', 
                                     self.vc_page.vc_event.ve_params)));
        ]]> 
      </v:on-post>
    </v:button>
  </xsl:template>
</xsl:stylesheet>
