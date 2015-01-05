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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:v="http://www.openlinksw.com/vspx/"
    xmlns:vm="http://www.openlinksw.com/vspx/ods/">
  <xsl:template match="vm:check-register">
    <xsl:if test="not parent::vm:page">
      <xsl:message terminate="yes">check-register is only allowed as a direct child of v:page</xsl:message>
    </xsl:if>
    <v:on-init>
      <![CDATA[
        declare sid, realm, uid varchar;
        sid := get_keyword ('sid', params, null);
        realm := get_keyword ('realm', params, null);
        uid := (select VS_UID from VSPX_SESSION where VS_REALM = realm and
          VS_SID = sid and VS_EXPIRY > now ());
        delete from VSPX_SESSION where VS_REALM = realm and VS_SID = sid;
        update SYS_USERS set U_ACCOUNT_DISABLED = 0 where U_NAME = uid;
        if (row_count ())
        {
          self.]]><xsl:value-of select="@message" /><![CDATA[ := 'Your account has been activated.';
          self.]]><xsl:value-of select="@on-success" /><![CDATA[ := 1;
        }
        else
          self.]]><xsl:value-of select="@message" /><![CDATA[ := 'The link you attempted is either incorrect or has expired.';
      ]]>
    </v:on-init>
  </xsl:template>
</xsl:stylesheet>
