--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
--  
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--  
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--  
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--  
--  
vhost_remove (lpath=>'/SOAP_SO_S_27');

vhost_define (lpath=>'/SOAP_SO_S_27', ppath=>'/SOAP/', soap_user=>'SOAP_SO_S_27');

create user SOAP_SO_S_27;

create procedure WS.SOAP_SO_S_27.YAHOO_GEOCODE_PROXY (
                 in appid VARCHAR,
                 in street VARCHAR := '',
                 in city VARCHAR := '',
                 in state VARCHAR := '',
                 in zip  INT := 0,
                 in location VARCHAR := '')
{
  declare res,hdr,ret any;
  
   hdr := null;
   ret := string_output();
   res := http_get (sprintf ('http://api.local.yahoo.com/MapsService/V1/geocode?appid=%U&street=%U&city=%U&state=%U&zip=%d&location=%U',
     appid,street,city,state,zip,location), hdr);
     
   http_value(xslt (TUTORIAL_XSL_DIR () || '/tutorial/services/so_s_21/raw.xsl', xml_tree_doc (res)),null,ret);
     
   return string_output_string(ret);
};

grant execute on WS.SOAP_SO_S_27.YAHOO_GEOCODE_PROXY to SOAP_SO_S_27;
grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to SOAP_SO_S_27;
grant select on WS.WS.SYS_DAV_RES to SOAP_SO_S_27;
