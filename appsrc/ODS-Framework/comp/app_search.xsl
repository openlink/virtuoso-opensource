<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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

  <xsl:template match="vm:app-search">
    <div>
      <v:form name="aps1" method="POST" type="simple">
        <div>
          <v:text name="apst1" value="" />
          <v:button name="apsb1" value="Search" action="simple">
            <v:on-post>
              <![CDATA[
                declare ss varchar;
                ss := trim(self.apst1.ufl_value);
                if (ss is null or ss = '')
                {
		  self.set_page_error ('Search criteria must not be empty');
                  return;
                }
                ss := FTI_MAKE_SEARCH_STRING (self.apst1.ufl_value);
                declare exit handler for sqlstate '*'
                {
		  self.set_page_error (__SQL_MESSAGE);
                  return;
                };
                self.dss.ds_sql := 'select WAI_ID, WAI_DESCRIPTION, WAI_INST, WAI_NAME, WAI_TYPE_NAME from WA_INSTANCE where WAI_IS_PUBLIC and contains (WAI_DESCRIPTION, ?) order by lower (WAI_DESCRIPTION)';
                self.dss.ds_parameters := vector ();
                self.dss.add_parameter (ss);
                self.dss.vc_data_bind (e);
                self.serv.vc_data_bind (e);
              ]]>
            </v:on-post>
          </v:button>
        </div>
      </v:form>
    </div>
  </xsl:template>

  <xsl:template match="vm:sec-app-search">
    <div>
      <v:form name="aps2" method="POST" type="simple">
        <div>
          <v:text name="apst2" value="" />
          <v:button name="apsb2" value="Search" action="simple">
            <v:on-post>
              <![CDATA[
                declare ss varchar;
                ss := trim(self.apst2.ufl_value);
                if (ss is null or ss = '')
                {
		  self.set_page_error ('Search criteria must not be empty');
                  return;
                }
                ss := FTI_MAKE_SEARCH_STRING (self.apst2.ufl_value);
                declare exit handler for sqlstate '*'
                {
		  self.set_page_error (__SQL_MESSAGE);
                  return;
                };
                self.dss1.ds_sql := 'select WAI_ID, WAI_DESCRIPTION, WAI_INST, WAI_NAME, WAI_TYPE_NAME
                  from WA_INSTANCE where contains(WAI_DESCRIPTION, ?) order by lower (WAI_DESCRIPTION)';
                self.dss1.ds_parameters := vector ();
                self.dss1.add_parameter (ss);
                self.dss1.vc_data_bind (e);
                self.serv2.vc_data_bind (e);
              ]]>
            </v:on-post>
          </v:button>
        </div>
      </v:form>
    </div>
  </xsl:template>

</xsl:stylesheet>
