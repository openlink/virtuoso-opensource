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
<!-- news group list control; two states in main page and on the other pages -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vm="http://www.openlinksw.com/vspx/weblog/" version="1.0">
  <xsl:template match="vm:nntp-attach">
  <v:variable name="grp_list_enabled" type="integer" default="1"/>
    <v:before-data-bind>
	<![CDATA[
	     declare _id varchar;
	]]>
    </v:before-data-bind>
   <xsl:call-template name="vm:attach_files" />
  </xsl:template>

<xsl:template name="vm:attach_files">
  <vm:template enabled="--self.vc_attach">
    <tr>
      <td>
        <span class="header">Attachments</span>
      </td>
      <td>
  <p><span class="header">Select: </span>
                    <v:check-box name="is_dav1" value="on"/><label>WebDAV Source </label>
		    <v:text name="f_path1"/>
                      <v:button action="simple" name="browsepath1" value="Browse...">
			<v:after-data-bind>
     			  <![CDATA[
     control.vc_add_attribute ('onclick', sprintf ('javascript: doBrowse(''nntpf_browser.vspx?sid=%s&realm=%s'', \'f_path1\', ''%s'', 0, document.nntpf_post.is_dav1.checked); return false', self.sid, self.realm, replace(http_root(), '\\','/')));
			  ]]>
			</v:after-data-bind>
		      </v:button>
  </p>

  <p><span class="header">Select: </span>
                    <v:check-box name="is_dav2" value="on"/><label>WebDAV Source </label>
		    <v:text name="f_path2"/>
                      <v:button action="simple" name="browsepath2" value="Browse...">
			<v:after-data-bind>
     			  <![CDATA[
     control.vc_add_attribute ('onclick', sprintf ('javascript: doBrowse(''nntpf_browser.vspx?sid=%s&realm=%s'', \'f_path2\', ''%s'', 0, document.nntpf_post.is_dav2.checked); return false', self.sid, self.realm, replace(http_root(), '\\','/')));
			  ]]>
			</v:after-data-bind>
		      </v:button>
  </p>

  <p><span class="header">Select: </span>
                    <v:check-box name="is_dav3" value="on"/><label>WebDAV Source </label>
		    <v:text name="f_path3"/>
                      <v:button action="simple" name="browsepath3" value="Browse...">
			<v:after-data-bind>
     			  <![CDATA[
     control.vc_add_attribute ('onclick', sprintf ('javascript: doBrowse(''nntpf_browser.vspx?sid=%s&realm=%s'', \'f_path3\', ''%s'', 0, document.nntpf_post.is_dav3.checked); return false', self.sid, self.realm, replace(http_root(), '\\','/')));
			  ]]>
			</v:after-data-bind>
		      </v:button>
  </p>
  </td>
  </tr>
  </vm:template>
  <vm:template enabled="--abs (self.vc_attach - 1)">
    <tr>
      <td>
        <span class="header">Attachments: </span>
      </td>
      <td>
        <v:button name="make_attachments" value="[Attach files]" action="simple" style="url"/>
      </td>
    </tr>
  </vm:template>
 </xsl:template>
</xsl:stylesheet>
